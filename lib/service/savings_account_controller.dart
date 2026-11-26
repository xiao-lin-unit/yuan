import 'package:sqflite/sqflite.dart';

import '../database/account/account_dao.dart';
import '../database/account/account_entry_dao.dart';
import '../database/account/account_record.dart';
import 'account_controller.dart';
import 'core/account_ledger.dart';
import 'core/entity_registry.dart';
import 'core/uniqueness_service.dart';
import 'core/unit_of_work.dart';

/// 储蓄类账户的业务处理器：**流动资金账户 + 其他资金账户**。
///
/// 【为什么这两类共用一个 Controller】它们都是「卡里有多少钱」的账户：
/// 入账钱变多、出账钱变少，累计值规则同为 [AccountBalanceRule.savings]
/// （余额 = 期初 + Σ入账 − Σ出账）。差别只是「其他资金账户」多一组
/// 绑定用途、且 `is_liquid` 默认否，属于同一套逻辑里的字段差异，不是
/// 两套逻辑。
///
/// 【与 CreditCardAccountController 的关系】两者的**校验与文案**各自
/// 留在各自文件里，读一个文件就能看全一种账户的全部行为；但**写库动作
/// 共用同一套功能接口**：都调 [AccountLedger] 的出账 / 入账接口，
/// 事务都由 [UnitOfWork] 统一编排，不再各自写一套出账逻辑。
///
/// 【动态逻辑说明，按项目约定写清】本类不是 ChangeNotifier：页面只 watch
/// 共享账本 [AccountController]。每个方法的工作逻辑固定 4 步：
///   ① 校验参数与账户类别（错配在事务开始前就抛，界面保持打开）；
///   ② 在 `uow.run` 的一个事务内调 [AccountLedger] 的组合接口完成写入
///      （规则由门面按账户类别统一推导，本类不再各自判断方向）；
///   ③ 失败由事务整体回滚，内存快照不动（10.8）；
///   ④ 成功后 `await catalog.refresh(touched: ...)` 重读并通知页面。
/// 没有隐藏状态、没有跨帧回调。
class SavingsAccountController {
  SavingsAccountController(
    this.db,
    this.dao,
    this.entryDao,
    this.catalog, {
     UnitOfWork? uow,
    AccountLedger? ledger,
    UniquenessService? uniqueness,
  })  : uow = uow ?? UnitOfWork(db),
        ledger = ledger ?? AccountLedger(entryDao),
        uniqueness = uniqueness ?? const UniquenessService();

  final Database db;
  final AccountDao dao;
  final AccountEntryDao entryDao;
  final AccountController catalog;

  /// 全库唯一的事务编排入口：跨接口组合时与其他模块共享同一个实例。
  final UnitOfWork uow;

  /// 全库唯一的账户记账功能接口（出账 / 入账 / 组合动作）。
  final AccountLedger ledger;

  /// 名称查重的写侧真源（与分类 / 资债共用）。
  final UniquenessService uniqueness;

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
    double? openingTransferIn,
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
    // 3.5「社保账户默认不绑定任何支出类型，且不可编辑绑定」——第一道锁。
    // 放在事务之前：错配在写库前就抛，表单保持打开、界面可提示。
    // 公积金**可以**绑定（3.5 的房租例子），只锁社保。
    if (kind == AccountKind.restricted &&
        type == AccountType.socialSecurity &&
        bindingIds.isNotEmpty) {
      throw ArgumentError('社保账户不能绑定支出类型');
    }

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
      // 【本轮】K4 期初：填了「转入金额」用填入值，没填则用期初可用金额。
      // K1/K3 不带这个次表列。
      netTransferIn: kind == AccountKind.investment
          ? (openingTransferIn ?? initialBalance)
          : null,
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
    await uow.run((txn) async {
      await uniqueness.assertUnique(
        txn,
        EntityKind.account,
        name: name,
        excludeId: id,
        bookId: record.bookId,
      );
      if (id == null) {
        savedId = await dao.insert(txn, record);
        if (savedId <= 0) throw StateError('账户写入未生效');
        // 【全局约定 7 / 本轮】K1/K3/K4 新建都写第一条 opening 流水：
        // 投资账户录的「可用金额」是用户已在使用的账户里真实存在的钱，
        // 属有意的期初事实录入，与「历史持仓补录」（契-14，不写流水）不同。
        final double opening = record.initialBalance;
        if (opening > 0) {
          await ledger.opening(
            txn,
            accountId: savedId,
            amount: opening,
            occurredAt: now,
          );
        }
      } else {
        final int affected = await dao.update(txn, record);
        if (affected == 0) throw StateError('账户更新未生效');
        savedId = id;
      }
      if (kind == AccountKind.restricted) {
        // 第二道锁：哪怕表单误传、或编辑旧脏数据，社保账户落库的绑定
        // 集合也恒为空。两层校验 + 详情页不显示入口，共三道，见
        // SavingsAccountController.setBindings 与 account_sheets.dart。
        final Set<int> effectiveBindings =
            type == AccountType.socialSecurity ? const <int>{} : bindingIds;
        await dao.replaceBindings(txn, savedId, effectiveBindings);
      }
    }, afterCommit: () => catalog.refresh(touched: <int>{savedId}));
    return savedId;
  }

  /// 账户间转账（3.7）。**只在储蓄类账户之间**，信用卡不参与：
  /// 给信用卡还钱是 [CreditCardAccountController.repay]，不是转账。
  ///
  /// 【工作逻辑】转出 / 转入两条流水由 [AccountLedger.transfer] 组合
  /// 同一个出账接口与入账接口生成，共用 group id、同处一个事务；
  /// 两端余额要么全变、要么全回滚（附录 A）。
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
    await uow.run(
      (txn) async {
        await ledger.transfer(
          txn,
          fromId: fromId,
          toId: toId,
          amount: amount,
          note: note,
          occurredAt: at,
        );
      },
      afterCommit: () => catalog.refresh(touched: <int>{fromId, toId}),
    );
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
    await uow.run(
      (txn) async {
        await ledger.adjust(
          txn,
          accountId: accountId,
          delta: delta,
          reason: reason.trim(),
          occurredAt: at,
        );
      },
      afterCommit: () => catalog.refresh(touched: <int>{accountId}),
    );
  }

  /// 修改其他资金账户的绑定用途（3.5）。空集合 = 不绑定 = 不限制。
  /// DAO 的 replaceBindings 不自建事务，这里独立调用所以自己包一层。
  /// 【社保不可编辑绑定，共三道锁】① 详情页不显示入口；② 新增/编辑
  /// 表单提交时按形态清空；③ 本方法与 save 的 Controller 硬校验。
  /// 三道都在，任何一条路径都不会写出对社保无效的绑定记录。
  Future<void> setBindings(int accountId, Set<int> categoryIds) async {
    final AccountRecord? old = await dao.byId(db, accountId);
    if (old == null || old.kind != AccountKind.restricted) {
      throw StateError('仅其他资金账户支持绑定用途');
    }
    // 3.5：社保账户不可编辑绑定。即使有人绕过详情页入口直接调本方法，
    // 也不会写一个永远不会生效的绑定（公积金不受此限制）。
    if (old.type == AccountType.socialSecurity) {
      throw StateError('社保账户不能绑定支出类型');
    }
    await uow.run(
      (txn) async {
        await dao.replaceBindings(txn, accountId, categoryIds);
      },
      afterCommit: () => catalog.refresh(touched: <int>{accountId}),
    );
  }
}
