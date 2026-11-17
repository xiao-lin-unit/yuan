import 'package:sqflite/sqflite.dart';

import '../database/account/account_dao.dart';
import '../database/account/account_entry_dao.dart';
import '../database/account/account_record.dart';
import 'account_controller.dart';

/// 储蓄类账户的业务处理器：**流动资金账户 + 其他资金账户**。
///
/// 【为什么这两类共用一个 Controller】它们都是「卡里有多少钱」的账户：
/// 入账钱变多、出账钱变少，累计值规则同为 [AccountBalanceRule.savings]
/// （余额 = 期初 + Σ入账 − Σ出账）。差别只是「其他资金账户」多一组
/// 绑定用途、且 `is_liquid` 默认否，属于同一套逻辑里的字段差异，不是
/// 两套逻辑。
///
/// 【与 CreditCardAccountController 的关系】两者**不互相调用、不复用
/// 实现**：信用卡的 balance 是已用额度，方向规则相反，还款也不是
/// 「把钱转进信用卡」。各自的事务、校验、文案都留在各自文件里，
/// 读一个文件就能看全一种账户的全部行为。
///
/// 【动态逻辑说明，按项目约定写清】本类不是 ChangeNotifier：页面只 watch
/// 共享账本 [AccountController]。每个方法的工作逻辑固定 4 步：
///   ① 校验参数与账户类别（错配在事务开始前就抛，界面保持打开）；
///   ② 在一个 `db.transaction` 内完成全部写入，流水 append 显式传
///      [AccountBalanceRule.savings]；
///   ③ 失败由事务整体回滚，内存快照不动（10.8）；
///   ④ 成功后 `await catalog.refresh(touched: ...)` 重读并通知页面。
/// 没有隐藏状态、没有跨帧回调。
class SavingsAccountController {
  SavingsAccountController(this.db, this.dao, this.entryDao, this.catalog);

  final Database db;
  final AccountDao dao;
  final AccountEntryDao entryDao;
  final AccountController catalog;

  /// 本处理器唯一的累计值规则。写成常量而不是每次推导，避免误传。
  static const AccountBalanceRule _rule = AccountBalanceRule.savings;

  /// 新增 / 编辑储蓄类账户。
  ///
  /// 【开户初始余额为什么特殊】3.8 允许填期初，但 10.9 要求余额只由
  /// 流水驱动：insert 时 balance 恒 0，紧接着同一事务 append 一条
  /// `opening`（入账）流水；编辑时**禁止改期初**，否则恒等式会破。
  ///
  /// 【本类别专属校验】
  ///   · 拒绝 `kind == credit`（信用卡交给 CreditCardAccountController）；
  ///   · [type] 必须出现在 [AccountType.allowedTypesFor] 的储蓄类清单里；
  ///   · 流动资金账户 `is_liquid` 恒 true（DDL 也有 CHECK）；
  ///   · 社保 / 公积金强制不计入可用余额；
  ///   · 绑定用途只对「其他资金账户」写。
  Future<int> save({
    int? id,
    required AccountKind kind,
    required AccountType type,
    required String name,
    double initialBalance = 0,
    String note = '',
    bool? isLiquid,
    bool? includeInNetWorth,
    Set<int> bindingIds = const <int>{},
    String bookId = AccountDao.defaultBookId,
  }) async {
    if (kind == AccountKind.credit) {
      throw ArgumentError('信用卡账户请使用信用卡处理器');
    }
    if (name.trim().isEmpty) throw ArgumentError('账户名称不能为空');
    if (!type.supports(kind)) {
      throw ArgumentError('账户形态与账户类别不匹配');
    }
    if (initialBalance < 0) throw ArgumentError('余额不得为负数');

    final AccountRecord? old = id == null ? null : await dao.byId(db, id);
    if (old != null && old.kind == AccountKind.credit) {
      throw StateError('不能把信用卡账户改成储蓄类账户');
    }
    final DateTime now = DateTime.now();
    final bool liquid = type.liquidLocked
        ? false
        : (isLiquid ??
            (kind == AccountKind.liquid ? true : old?.isLiquid ?? false));
    final bool inNetWorth =
        includeInNetWorth ?? old?.includeInNetWorth ?? true;

    final AccountRecord record = AccountRecord(
      id: id,
      bookId: old?.bookId ?? bookId,
      kind: kind,
      type: type,
      name: name.trim(),
      // 累计值恒由流水写，insert/update 都不覆写。
      balance: old?.balance ?? 0,
      initialBalance: old?.initialBalance ?? initialBalance,
      // 信用卡专属列在本处理器一律置空（DDL CHECK 也只允许 credit 行非空）。
      creditLimit: null,
      statementDay: null,
      dueDay: null,
      repayAccountId: null,
      minPaymentRate: 0.1,
      note: note,
      isLiquid: liquid,
      includeInNetWorth: inNetWorth,
      sortOrder: old?.sortOrder ?? catalog.all.length,
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
        final double opening = record.initialBalance;
        if (opening > 0) {
          await entryDao.append(
            txn,
            AccountEntryRecord(
              accountId: savedId,
              direction: AccountDirection.inbound,
              amount: opening,
              balanceAfter: 0, // append 在事务内重算并覆盖
              entryType: AccountEntryType.opening,
              occurredAt: now,
              createdAt: now,
            ),
            rule: _rule,
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
    await catalog.refresh(touched: <int>{savedId});
    return savedId;
  }

  /// 账户间转账（3.7）。**只在储蓄类账户之间**，信用卡不参与：
  /// 给信用卡还钱是 [CreditCardAccountController.repay]，不是转账。
  ///
  /// 【工作逻辑】转出方 `out`、转入方 `in`，两条流水共用 group id，
  /// 同一个事务、同一条 [AccountBalanceRule.savings] 规则；两端余额
  /// 要么全变、要么全回滚（附录 A）。
  /// 边界：两端相同、金额 ≤ 0、任一端不存在或属于信用卡都拦。
  Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    required String note,
    DateTime? occurredAt,
  }) async {
    if (fromId == toId) throw ArgumentError('转出账户与转入账户不能相同');
    if (amount <= 0) throw ArgumentError('转账金额必须大于 0');
    final AccountRecord? from = await dao.byId(db, fromId);
    final AccountRecord? to = await dao.byId(db, toId);
    if (from == null || to == null) throw StateError('账户不存在或已删除');
    if (from.kind == AccountKind.credit || to.kind == AccountKind.credit) {
      throw StateError('信用卡账户不参与账户转账，还款请使用还款功能');
    }

    final DateTime at = occurredAt ?? DateTime.now();
    final String group = 'tx_${at.microsecondsSinceEpoch}_${fromId}_$toId';
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
        rule: _rule,
      );
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: toId,
          direction: AccountDirection.inbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.transferIn,
          occurredAt: at,
          counterpartyAccountId: fromId,
          transferGroupId: group,
          note: note,
          createdAt: DateTime.now(),
        ),
        rule: _rule,
      );
    });
    await catalog.refresh(touched: <int>{fromId, toId});
  }

  /// 余额调整（3.8）：必须填原因，差额记为一条 `adjustment` 流水，
  /// 不产生收支、不手填余额。差额为 0 时什么都不写。
  ///
  /// 【与信用卡「已用额度校准」分开】储蓄类 `delta > 0 → 入账`，
  /// 信用卡则相反；两套判断不抽公共函数，避免又回到「一条公式管三类」。
  Future<void> adjustBalance({
    required int accountId,
    required double actualBalance,
    required String reason,
    DateTime? occurredAt,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError('请填写余额调整原因');
    final AccountRecord? account = await dao.byId(db, accountId);
    if (account == null) throw StateError('账户不存在或已删除');
    if (account.kind == AccountKind.credit) {
      throw StateError('信用卡请使用「已用额度校准」功能');
    }
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
        rule: _rule,
      );
    });
    await catalog.refresh(touched: <int>{accountId});
  }

  /// 修改其他资金账户的绑定用途（3.5）。空集合 = 不绑定 = 不限制。
  /// DAO 的 replaceBindings 不自建事务，这里独立调用所以自己包一层。
  Future<void> setBindings(int accountId, Set<int> categoryIds) async {
    final AccountRecord? old = await dao.byId(db, accountId);
    if (old == null || old.kind != AccountKind.restricted) {
      throw StateError('仅其他资金账户支持绑定用途');
    }
    await db.transaction((txn) async {
      await dao.replaceBindings(txn, accountId, categoryIds);
    });
    await catalog.refresh(touched: <int>{accountId});
  }
}
