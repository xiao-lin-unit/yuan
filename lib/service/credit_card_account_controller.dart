import 'package:sqflite/sqflite.dart';

import '../database/account/account_dao.dart';
import '../database/account/account_entry_dao.dart';
import '../database/account/account_record.dart';
import 'account_controller.dart';

/// 信用卡账户的业务处理器（含信用卡 / 花呗 / 借呗等信用形态）。
///
/// 【为什么单独一个 Controller】信用卡的 `balance` 记的是**已用额度**
/// （欠银行 / 平台的钱），不是「卡里有多少钱」。所以：
///   · 消费 = **出账**，已用额度 **增加**；
///   · 还款 = **入账**，已用额度 **减少**；
///   · 恒等式 `已用额度 = Σ出账 − Σ入账`，没有「期初已用额度」。
/// 规则是 [AccountBalanceRule.credit]，与储蓄类正好相反。把它和
/// SavingsAccountController 分开，是为了让每条业务规则都能在一个
/// 文件里读全，不出现「三类账户共用一条公式」的隐式假设。
///
/// 【还款 ≠ 转账，这是本类最重要的边界】转账是「钱从 A 到 B，两边都是
/// 自己的资产」；还款是「自己的钱去抵消一笔欠款」：
///   · 来源账户按 **savings** 规则扣余额；
///   · 信用卡按 **credit** 规则减已用额度；
///   · 两条流水用同一个 group 配对，但类型都是 `creditRepay`，
///     **不标** `transfer_out/in`，避免被当成普通转账计入统计；
///   · 还款金额不得超过当前已用额度（溢缴款属于另一类业务）。
///
/// 【动态逻辑说明，按项目约定写清】本类不是 ChangeNotifier：页面只 watch
/// 共享账本 [AccountController]。每个方法固定 4 步：校验 → 单事务写入
/// （append 显式传规则）→ 失败整体回滚 → `catalog.refresh` 通知页面。
class CreditCardAccountController {
  CreditCardAccountController(this.db, this.dao, this.entryDao, this.catalog);

  final Database db;
  final AccountDao dao;
  final AccountEntryDao entryDao;
  final AccountController catalog;

  static const AccountBalanceRule _rule = AccountBalanceRule.credit;

  /// 新增 / 编辑信用卡账户。
  ///
  /// 【本类别专属校验】
  ///   · [type] 必须出现在 `AccountType.allowedTypesFor(credit)` 清单里
  ///     （信用卡 / 花呗 / 借呗，不含「其他」）；
  ///   · 总额度、账单日、还款日必填且合法；
  ///   · 关联还款账户若填写，必须是流动资金账户（受限账户不能自由取钱）；
  ///   · 信用卡**不允许开户初始余额**，也不写 `opening` 流水；
  ///   · `is_liquid` / `include_in_net_worth` 恒 false（欠款不是资产）。
  /// 借呗是现金贷，放款应「流动资金账户入账 + 负债增加」两笔联动；
  /// 本轮只登记形态，不开放「借呗直接消费」，等负债模块一起做。
  Future<int> save({
    int? id,
    required AccountType type,
    required String name,
    required double creditLimit,
    required int statementDay,
    required int dueDay,
    int? repayAccountId,
    double minPaymentRate = 0.1,
    String note = '',
    String bookId = AccountDao.defaultBookId,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('账户名称不能为空');
    if (!type.supports(AccountKind.credit)) {
      throw ArgumentError('账户形态与信用卡账户不匹配');
    }
    if (creditLimit <= 0) throw ArgumentError('请填写信用卡总额度');
    if (statementDay < 1 || statementDay > 31 || dueDay < 1 || dueDay > 31) {
      throw ArgumentError('请填写账单日与还款日（1 ~ 31）');
    }
    if (minPaymentRate < 0 || minPaymentRate > 1) {
      throw ArgumentError('最低还款比例需在 0 ~ 1 之间');
    }
    if (repayAccountId != null) {
      final AccountRecord? repay = await dao.byId(db, repayAccountId);
      if (repay == null || repay.kind != AccountKind.liquid) {
        throw ArgumentError('还款账户需选择流动资金账户');
      }
    }

    final AccountRecord? old = id == null ? null : await dao.byId(db, id);
    if (old != null && old.kind != AccountKind.credit) {
      throw StateError('不能把储蓄类账户改成信用卡账户');
    }
    final DateTime now = DateTime.now();
    final AccountRecord record = AccountRecord(
      id: id,
      bookId: old?.bookId ?? bookId,
      kind: AccountKind.credit,
      type: type,
      name: name.trim(),
      // 已用额度恒由流水写；insert/update 都不覆写。
      balance: old?.balance ?? 0,
      initialBalance: 0,
      creditLimit: creditLimit,
      statementDay: statementDay,
      dueDay: dueDay,
      repayAccountId: repayAccountId,
      minPaymentRate: minPaymentRate,
      note: note,
      isLiquid: false,
      includeInNetWorth: false,
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
      } else {
        final int affected = await dao.update(txn, record);
        if (affected == 0) throw StateError('账户更新未生效');
        savedId = id;
      }
    });
    await catalog.refresh(touched: <int>{savedId});
    return savedId;
  }

  /// 消费出账：direction = `out`，信用卡规则下已用额度 **+amount**。
  /// 这是「信用卡已用金额是出账金额」的写入口，不复用储蓄类的支出逻辑。
  ///
  /// 边界：金额 > 0、账户必须是信用卡。额度不足不硬拦（4.7 的口径是
  /// 提示而不是拦住），界面会显示可用额度供用户核对。
  Future<void> spend({
    required int accountId,
    required double amount,
    String note = '',
    int? categoryId,
    String payee = '',
    DateTime? occurredAt,
  }) async {
    if (amount <= 0) throw ArgumentError('消费金额必须大于 0');
    final AccountRecord? account = await dao.byId(db, accountId);
    if (account == null || account.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持消费出账');
    }
    final DateTime at = occurredAt ?? DateTime.now();
    await db.transaction((txn) async {
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: accountId,
          direction: AccountDirection.outbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.creditSpend,
          occurredAt: at,
          categoryId: categoryId,
          payee: payee,
          note: note,
          createdAt: DateTime.now(),
        ),
        rule: _rule,
      );
    });
    await catalog.refresh(touched: <int>{accountId});
  }

  /// 立即还款：**独立实现，不调用 SavingsAccountController.transfer**。
  ///
  /// 【工作逻辑，5 步，全部在一个事务里】
  ///   1. 校验信用卡、来源账户是流动资金账户、金额 0 < amount ≤ 已用额度；
  ///   2. 来源账户写一条 `creditRepay` 流水：direction = out，
  ///      **savings** 规则 → 余额 −amount；
  ///   3. 信用卡写一条 `creditRepay` 流水：direction = in，
  ///      **credit** 规则 → 已用额度 −amount；
  ///   4. 两条用同一个 group / counterparty 配对，便于日后查账；
  ///   5. 成功后刷新两个账户的快照与当前明细页。
  /// 边界：两条流水方向不同但金额相同；任一步失败整体回滚，
  /// 不会出现「钱扣了、欠款没少」。
  Future<void> repay({
    required int creditCardId,
    required int fromAccountId,
    required double amount,
    String note = '',
    DateTime? occurredAt,
  }) async {
    if (amount <= 0) throw ArgumentError('还款金额必须大于 0');
    final AccountRecord? card = await dao.byId(db, creditCardId);
    final AccountRecord? from = await dao.byId(db, fromAccountId);
    if (card == null || card.kind != AccountKind.credit) {
      throw StateError('还款目标需为信用卡账户');
    }
    if (from == null || from.kind != AccountKind.liquid) {
      throw StateError('还款来源需为流动资金账户');
    }
    if (amount > card.balance + 0.000001) {
      throw ArgumentError('还款金额不能超过当前已用额度');
    }

    final DateTime at = occurredAt ?? DateTime.now();
    final String group =
        'repay_${at.microsecondsSinceEpoch}_${fromAccountId}_$creditCardId';
    await db.transaction((txn) async {
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: fromAccountId,
          direction: AccountDirection.outbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.creditRepay,
          occurredAt: at,
          counterpartyAccountId: creditCardId,
          transferGroupId: group,
          note: note,
          createdAt: DateTime.now(),
        ),
        rule: AccountBalanceRule.savings,
      );
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: creditCardId,
          direction: AccountDirection.inbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.creditRepay,
          occurredAt: at,
          counterpartyAccountId: fromAccountId,
          transferGroupId: group,
          note: note,
          createdAt: DateTime.now(),
        ),
        rule: _rule,
      );
    });
    await catalog.refresh(touched: <int>{fromAccountId, creditCardId});
  }

  /// 已用额度校准（信用卡专属，与储蓄类的「余额调整」分开）。
  ///
  /// 【方向判断相反】`delta > 0` 表示已用额度要增加，对应**出账**；
  /// `delta < 0` 表示要减少，对应**入账**。两条判断刻意不抽公共函数，
  /// 免得以后有人「顺手复用」把两套规则又合回去。
  /// 必须填原因（DDL 对 `adjustment` 有 CHECK），差额为 0 不写流水。
  Future<void> adjustUsedAmount({
    required int accountId,
    required double actualUsed,
    required String reason,
    DateTime? occurredAt,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError('请填写校准原因');
    final AccountRecord? account = await dao.byId(db, accountId);
    if (account == null || account.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持已用额度校准');
    }
    final double delta = actualUsed - account.balance;
    if (delta == 0) return;
    final DateTime at = occurredAt ?? DateTime.now();
    await db.transaction((txn) async {
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: accountId,
          direction: delta > 0
              ? AccountDirection.outbound
              : AccountDirection.inbound,
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

  /// 调整总额度：只改属性，不动累计值、不写流水（额度不是余额）。
  Future<void> setCreditLimit(int accountId, double limit) async {
    if (limit <= 0) throw ArgumentError('信用额度必须大于 0');
    final AccountRecord? old = await dao.byId(db, accountId);
    if (old == null || old.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持调整额度');
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
    await catalog.refresh(touched: <int>{accountId});
  }
}
