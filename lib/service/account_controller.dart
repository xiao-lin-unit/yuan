import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/account/account_dao.dart';
import '../database/account/account_entry_dao.dart';
import '../database/account/account_record.dart';

/// 账户模块的唯一状态入口（ChangeNotifier，由 Services.initServices 装配）。
///
/// 【动态逻辑说明，按项目约定写清】
/// 为什么动态：账户列表、余额、流水会随用户「新增 / 编辑 / 转账 /
/// 余额调整 / 归档 / 排序」实时变化，构造期定不死。这里用最朴素的
/// ChangeNotifier，与 CategoryController 同一套：
///   1. `_all` 是数据库里未删账户在内存里的一份只读快照；
///   2. 任何写操作 **先 await 落库（事务）→ 再 load() 重读 →
///      notifyListeners()**（10.8 即时保存；失败时内存保持旧值，
///      界面绝不悄悄改数字）；
///   3. 页面用 `context.watch<AccountController>()` 读，不另存一份列表。
/// 没有 Notifier 嵌套、没有跨帧注册、没有隐藏双模式。
///
/// 【准确性铁律 10.9】账户累计值只允许 [AccountEntryDao.append] 写，
/// 本 Controller 只负责「编排事务 + 决定方向 / 类型」，不自己 UPDATE balance。
/// 每次动作都在**一个 db.transaction** 里完成，转账两条流水与两个账户
/// 的余额要么全成、要么全回滚（附录 A「两边状态原子同步」）。
class AccountController extends ChangeNotifier {
  AccountController(this.db, this.dao, this.entryDao);

  final Database db;
  final AccountDao dao;
  final AccountEntryDao entryDao;

  List<AccountRecord> _all = <AccountRecord>[];
  final Map<int, Set<int>> _bindings = <int, Set<int>>{};

  // 明细页的一次性快照（由 loadDetail 填，随 load() 一起清空重建）。
  List<AccountEntryRecord> _detailEntries = <AccountEntryRecord>[];
  AccountEntrySummary? _detailSummary;
  int? _detailAccountId;
  bool _detailLoading = false;

  /// 内存快照（只读）。页面不要修改它。
  List<AccountRecord> get all => List<AccountRecord>.unmodifiable(_all);

  bool get detailLoading => _detailLoading;
  int? get detailAccountId => _detailAccountId;
  List<AccountEntryRecord> get detailEntries =>
      List<AccountEntryRecord>.unmodifiable(_detailEntries);
  AccountEntrySummary? get detailSummary => _detailSummary;

  Future<void> load() async {
    // 必须把归档账户也读进来：3.7「想恢复随时恢复」、10.7「所有操作
    // 可逆」。若这里过滤掉 archived，归档后账户会从内存里彻底消失，
    // 页面上没有任何入口能恢复，等于把数据藏丢了。
    // 首页/统计各自再过滤 archived，见 byKind / stats。
    _all = await dao.listAll(db, includeArchived: true);
    _bindings.clear();
    for (final AccountRecord r in _all) {
      final int? id = r.id;
      if (id == null) continue;
      _bindings[id] = (await dao.bindingsFor(db, id))
          .map((AccountCategoryBinding b) => b.categoryId)
          .toSet();
    }
    notifyListeners();
  }

  /// 明细页快照：一次读齐流水 + 汇总。页面 initState 调用，
  /// build 用 `context.watch` 按 [detailLoading] 显示三态骨架。
  Future<void> loadDetail(int accountId) async {
    _detailLoading = true;
    _detailAccountId = accountId;
    notifyListeners();
    try {
      _detailEntries = await entryDao.listForAccount(db, accountId);
      _detailSummary = await entryDao.summaryFor(db, accountId);
    } finally {
      _detailLoading = false;
      notifyListeners();
    }
  }

  /// 首页三组分区：按 kind 分组，组内保持 sort_order。
  List<AccountRecord> byKind(AccountKind kind) => _all
      .where((AccountRecord r) => r.kind == kind && !r.isDeleted && !r.archived)
      .toList(growable: false);

  List<AccountRecord> get archived => _all
      .where((AccountRecord r) => r.archived && !r.isDeleted)
      .toList(growable: false);

  Set<int> bindingsOf(int accountId) =>
      Set<int>.unmodifiable(_bindings[accountId] ?? const <int>{});

  /// 首页看板（3.6 大白话数字）。信用卡余额是欠款，只进「欠银行的钱」，
  /// 绝不混进「能花的钱」——DDL 的 CHECK 也从数据层锁死了这条口径。
  AccountStats get stats {
    double spendable = 0;
    double owed = 0;
    double restricted = 0;
    int creditCount = 0;
    for (final AccountRecord r in _all) {
      if (r.isDeleted || r.archived) continue;
      switch (r.kind) {
        case AccountKind.liquid:
          if (r.isLiquid) spendable += r.balance;
        case AccountKind.credit:
          owed += r.balance;
          creditCount += 1;
        case AccountKind.restricted:
          if (r.includeInNetWorth) restricted += r.balance;
      }
    }
    return AccountStats(
      spendable: spendable,
      owedToBank: owed,
      restrictedTotal: restricted,
      accountCount: _all
          .where((AccountRecord r) => !r.isDeleted && !r.archived)
          .length,
      creditCount: creditCount,
    );
  }

  /// 「真正属于你的钱」当前只算账户口径（3.6 完整公式还要加资产估值、
  /// 借出/借入，那些模块在第二阶段）。页面显示时附带一句说明，
  /// 不把一个不完整的数字伪装成最终答案——设计原则第一条。
  double get netWorthSoFar => stats.spendable + stats.restrictedTotal - stats.owedToBank;

  AccountRecord? byId(int id) {
    for (final AccountRecord r in _all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 同步重名校验（给新增/编辑表单的 validator 用）。
  bool nameExists(String name, {int? excludeId}) => _all.any(
        (AccountRecord r) =>
            !r.isDeleted && r.name == name && r.id != excludeId,
      );

  /// 新增 / 编辑账户。
  ///
  /// 【开户初始余额为什么特殊】3.8 允许「开户时的初始余额」，但 10.9
  /// 要求余额只由流水驱动。做法是：insert 时 balance 恒为 0，
  /// 紧接着在同一个事务里 append 一条 `opening` 流水；于是
  /// `balance = 0 + initialBalance`，恒等式从第一笔就成立。
  /// 编辑时**禁止改初始余额**（保留旧值、不写新流水），否则恒等式会破。
  ///
  /// 两阶段之外还有一处保护：任何一步抛异常 → 整个事务回滚 →
  /// 内存快照保持旧值（10.8「失败不悄悄改界面」）。
  Future<int> save({
    int? id,
    required AccountKind kind,
    required AccountType type,
    required String name,
    double initialBalance = 0,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
    int? repayAccountId,
    double minPaymentRate = 0.1,
    String note = '',
    bool? isLiquid,
    bool? includeInNetWorth,
    Set<int> bindingIds = const <int>{},
    String bookId = AccountDao.defaultBookId,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('账户名不能为空');
    if (initialBalance < 0) throw ArgumentError('金额只能填正数（10.6）');
    if (kind == AccountKind.credit) {
      if (creditLimit == null || creditLimit <= 0) {
        throw ArgumentError('信用卡要填总额度');
      }
      if (statementDay == null || statementDay < 1 || statementDay > 31 ||
          dueDay == null || dueDay < 1 || dueDay > 31) {
        throw ArgumentError('信用卡要填账单日和还款日（1~31）');
      }
    }
    final AccountRecord? old = id == null ? null : await dao.byId(db, id);
    final DateTime now = DateTime.now();
    final bool liquid = isLiquid ??
        (kind == AccountKind.liquid
            ? true
            : (type.liquidLocked ? false : old?.isLiquid ?? false));
    final bool inNetWorth = includeInNetWorth ??
        (kind == AccountKind.credit ? false : old?.includeInNetWorth ?? true);

    final AccountRecord record = AccountRecord(
      id: id,
      bookId: old?.bookId ?? bookId,
      kind: kind,
      type: type,
      name: name.trim(),
      // 累计值恒由流水写，insert/update 都传 0 或原值；
      // update 分支会在下面覆盖成旧 balance（禁止在这里覆写）。
      balance: old?.balance ?? 0,
      initialBalance: old?.initialBalance ?? initialBalance,
      creditLimit: kind == AccountKind.credit ? creditLimit : null,
      statementDay: kind == AccountKind.credit ? statementDay : null,
      dueDay: kind == AccountKind.credit ? dueDay : null,
      repayAccountId: kind == AccountKind.credit ? repayAccountId : null,
      minPaymentRate: minPaymentRate,
      note: note,
      isLiquid: liquid,
      includeInNetWorth: inNetWorth,
      sortOrder: old?.sortOrder ?? _all.length,
      archived: old?.archived ?? false,
      deletedAt: old?.deletedAt,
      deleteReason: old?.deleteReason,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      revision: (old?.revision ?? 0) + 1,
    );

    int savedId = 0;
    await db.transaction((txn) async {
      if (id == null) {
        savedId = await dao.insert(txn, record);
        if (savedId <= 0) throw StateError('账户写入未生效');
        // 开户流水：让恒等式从 0 开始成立。金额 0 时不插（DDL 要求 >0）。
        final double opening = old?.initialBalance ?? initialBalance;
        if (opening > 0) {
          await entryDao.append(
            txn,
            AccountEntryRecord(
              accountId: savedId,
              direction: AccountDirection.inbound,
              amount: opening,
              balanceAfter: 0, // append 会在事务内重算并覆盖
              entryType: AccountEntryType.opening,
              occurredAt: now,
              createdAt: now,
            ),
          );
        }
      } else {
        final int affected = await dao.update(txn, record);
        if (affected == 0) throw StateError('账户更新未生效');
        savedId = id;
      }
      if (kind == AccountKind.restricted) {
        await dao.replaceBindings(txn, savedId, bindingIds);
      }
    });
    await load();
    if (_detailAccountId == savedId) await loadDetail(savedId);
    return savedId;
  }

  /// 账户间转账（3.7）。
  ///
  /// 【方向的工作逻辑】`direction` 表示「本账户累计值的增减」，所以：
  ///   · 转出方永远 out（钱少了）；
  ///   · 转入方是普通账户 → in（钱多了）；
  ///   · 转入方是**信用卡** → out（这是「还款」，已用额度要**减少**），
  ///     entryType 用 creditRepay，负债镜像由第二阶段联动。
  /// 两条流水共用同一个 transferGroupId，DDL 的 CHECK 保证成对可查。
  /// 边界：不允许从信用卡转出（取现是另一种业务，先明确拦住，
  /// 避免把「已用额度增加」误当成普通转出）；两账户相同、金额 ≤0 都拦。
  Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    required String note,
    DateTime? occurredAt,
  }) async {
    if (fromId == toId) throw ArgumentError('转出和转入不能是同一个账户');
    if (amount <= 0) throw ArgumentError('金额只能填正数（10.6）');
    final AccountRecord? from = await dao.byId(db, fromId);
    final AccountRecord? to = await dao.byId(db, toId);
    if (from == null || to == null) throw StateError('账户不存在或已删除');
    if (from.kind == AccountKind.credit) {
      throw StateError('信用卡不能转出；要还信用卡请选「还款」');
    }

    final DateTime at = occurredAt ?? DateTime.now();
    final String group =
        'tx_${at.microsecondsSinceEpoch}_${fromId}_$toId';
    await db.transaction((txn) async {
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: fromId,
          direction: AccountDirection.outbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.transferOut,
          occurredAt: at,
          counterpartyAccountId: toId,
          transferGroupId: group,
          note: note,
          createdAt: DateTime.now(),
        ),
      );
      final bool repaying = to.kind == AccountKind.credit;
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: toId,
          // 还款让「已用额度」减少，所以仍是 out。
          direction: repaying
              ? AccountDirection.outbound
              : AccountDirection.inbound,
          amount: amount,
          balanceAfter: 0,
          entryType: repaying
              ? AccountEntryType.creditRepay
              : AccountEntryType.transferIn,
          occurredAt: at,
          counterpartyAccountId: fromId,
          transferGroupId: group,
          note: note,
          createdAt: DateTime.now(),
        ),
      );
    });
    await load();
    await _reloadVisibleDetail(fromId, toId);
  }

  /// 余额调整（3.8）：必须填原因，差额记为一条 `adjustment` 流水，
  /// 不产生收支、不手填余额。差额为 0 时什么都不写。
  Future<void> adjustBalance({
    required int accountId,
    required double actualBalance,
    required String reason,
    DateTime? occurredAt,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError('余额调整必须填原因（3.8）');
    final AccountRecord? account = await dao.byId(db, accountId);
    if (account == null) throw StateError('账户不存在或已删除');
    final double delta = actualBalance - account.balance;
    if (delta == 0) return;
    final DateTime at = occurredAt ?? DateTime.now();
    await db.transaction((txn) async {
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: accountId,
          direction: delta > 0
              ? AccountDirection.inbound
              : AccountDirection.outbound,
          amount: delta.abs(),
          balanceAfter: 0,
          entryType: AccountEntryType.adjustment,
          occurredAt: at,
          reason: reason.trim(),
          createdAt: DateTime.now(),
        ),
      );
    });
    await load();
    if (_detailAccountId == accountId) await loadDetail(accountId);
  }

  /// 修改信用卡额度：只改属性，不动累计值，不写流水（额度不是余额）。
  Future<void> setCreditLimit(int accountId, double limit) async {
    if (limit <= 0) throw ArgumentError('额度只能填正数（10.6）');
    final AccountRecord? old = await dao.byId(db, accountId);
    if (old == null || old.kind != AccountKind.credit) {
      throw StateError('只有信用卡能调整额度');
    }
    final int affected = await dao.update(
      db,
      old.copyWith(
        creditLimit: limit,
        updatedAt: DateTime.now(),
        revision: old.revision + 1,
      ),
    );
    if (affected == 0) throw StateError('额度写入未生效');
    await load();
  }

  /// 修改受限账户的绑定用途（3.5）。空集合 = 不绑定 = 不限制。
  Future<void> setBindings(int accountId, Set<int> categoryIds) async {
    final AccountRecord? old = await dao.byId(db, accountId);
    if (old == null || old.kind != AccountKind.restricted) {
      throw StateError('只有其他资金账户需要绑定用途');
    }
    // DAO 的 replaceBindings 不自建事务（事务内调用时不能嵌套）。
    // 这里是独立调用，所以自己包一层 db.transaction，保证「先删后插」
    // 要么全成、要么全回滚（10.8 / 附录 E 事务边界）。
    await db.transaction((txn) async {
      await dao.replaceBindings(txn, accountId, categoryIds);
    });
    await load();
  }

  /// 归档 / 恢复（3.7）：只改标记，历史流水全部保留。
  Future<void> setArchived(int id, bool archived) async {
    final AccountRecord? old = await dao.byId(db, id);
    if (old == null) return;
    final int affected = await dao.update(
      db,
      old.copyWith(
        archived: archived,
        updatedAt: DateTime.now(),
        revision: old.revision + 1,
      ),
    );
    if (affected == 0) throw StateError('归档状态写入未生效');
    await load();
  }

  /// 拖拽排序（3.7）。传**当前显示的那批** id，其余留在原槽位。
  Future<void> reorder(List<int> orderedVisibleIds) async {
    final Set<int> visible = orderedVisibleIds.toSet();
    final List<int> result = <int>[];
    int cursor = 0;
    for (final AccountRecord r in _all) {
      final int id = r.id ?? -1;
      if (visible.contains(id)) {
        if (cursor < orderedVisibleIds.length) {
          result.add(orderedVisibleIds[cursor++]);
        }
      } else {
        result.add(id);
      }
    }
    for (final int id in orderedVisibleIds) {
      if (!result.contains(id)) result.add(id);
    }
    await dao.reorder(db, result);
    await load();
  }

  /// 删除 = 进回收站（10.7）。先数流水给页面提示（3.8），
  /// 记录本身永不物理删除。
  Future<int> countEntries(int id) => dao.countEntries(db, id);

  Future<void> delete(int id, {String reason = '用户在账户页删除'}) async {
    final int affected = await dao.softDelete(
      db,
      id,
      at: DateTime.now(),
      reason: reason,
    );
    if (affected == 0) throw StateError('账户删除未生效');
    await load();
  }

  Future<void> restore(int id) async {
    final int affected = await dao.restore(db, id, DateTime.now());
    if (affected == 0) throw StateError('账户恢复未生效');
    await load();
  }

  Future<int> purgeExpired() async {
    final int n = await dao.purgeExpired(db, DateTime.now());
    if (n > 0) await load();
    return n;
  }

  /// 恒等式审计（10.9），给「账对不上」时排查用。
  Future<double> auditBalance(int id) => entryDao.auditBalance(db, id);

  /// 转账同时刷新两个明细页中当前打开的那一个。
  Future<void> _reloadVisibleDetail(int a, int b) async {
    if (_detailAccountId == a || _detailAccountId == b) {
      await loadDetail(_detailAccountId!);
    }
  }
}
