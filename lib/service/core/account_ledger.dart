import 'package:sqflite/sqflite.dart';

import '../../database/account/account_db.dart';
import '../../database/account/account_entry_dao.dart';
import '../../database/account/account_record.dart';

/// 账户资金变动的**唯一功能门面**。
///
/// 【接口拆分】整改前 9 处 `entryDao.append` 散在 2 个 Controller：
/// 消费、还款、转账、余额调整、开户、账单息费各自拼流水、各自选
/// `AccountBalanceRule`、各自开事务。现在：
/// ```
/// debit (唯一出账接口) ─┐
/// credit(唯一入账接口) ─┴─ append（全库只在这里调用 1 次）
///   ↑ 组合：opening / spend / transfer / repay / adjust / accrueInterest
/// ```
/// **所有**涉及账户余额的功能都调这两个根接口；规则由门面按账户
/// `kind` 统一推导，上层不再判断「信用卡方向取反」。
///
/// 【事务契约】本类不自建事务、第一参数收 [DatabaseExecutor]，可与其他
/// 模块（债务处理、图片提交）在同一个 [UnitOfWork.run] 里组合。
///
/// 【页面无关】不 import 任何 screens、不持有 BuildContext。
class AccountLedger {
  const AccountLedger(this.entryDao);

  final AccountEntryDao entryDao;

  Future<double> debit(
    DatabaseExecutor txn, {
    required int accountId,
    required double amount,
    required AccountEntryType entryType,
    AccountBalanceRule? rule,
    DateTime? occurredAt,
    int? counterpartyAccountId,
    String? transferGroupId,
    int? categoryId,
    String payee = '',
    String note = '',
    String reason = '',
    bool nonBinding = false,
    String? imageRef,
    String? refType,
    int? refId,
    String recordSource = 'user',
  }) =>
      _write(
        txn,
        accountId: accountId,
        direction: AccountDirection.outbound,
        amount: amount,
        entryType: entryType,
        rule: rule,
        occurredAt: occurredAt,
        counterpartyAccountId: counterpartyAccountId,
        transferGroupId: transferGroupId,
        categoryId: categoryId,
        payee: payee,
        note: note,
        reason: reason,
        nonBinding: nonBinding,
        imageRef: imageRef,
        refType: refType,
        refId: refId,
        recordSource: recordSource,
      );

  Future<double> credit(
    DatabaseExecutor txn, {
    required int accountId,
    required double amount,
    required AccountEntryType entryType,
    AccountBalanceRule? rule,
    DateTime? occurredAt,
    int? counterpartyAccountId,
    String? transferGroupId,
    int? categoryId,
    String payee = '',
    String note = '',
    String reason = '',
    bool nonBinding = false,
    String? imageRef,
    String? refType,
    int? refId,
    String recordSource = 'user',
  }) =>
      _write(
        txn,
        accountId: accountId,
        direction: AccountDirection.inbound,
        amount: amount,
        entryType: entryType,
        rule: rule,
        occurredAt: occurredAt,
        counterpartyAccountId: counterpartyAccountId,
        transferGroupId: transferGroupId,
        categoryId: categoryId,
        payee: payee,
        note: note,
        reason: reason,
        nonBinding: nonBinding,
        imageRef: imageRef,
        refType: refType,
        refId: refId,
        recordSource: recordSource,
      );

  Future<double> _write(
    DatabaseExecutor txn, {
    required int accountId,
    required AccountDirection direction,
    required double amount,
    required AccountEntryType entryType,
    required AccountBalanceRule? rule,
    required DateTime? occurredAt,
    required int? counterpartyAccountId,
    required String? transferGroupId,
    required int? categoryId,
    required String payee,
    required String note,
    required String reason,
    required bool nonBinding,
    required String? imageRef,
    required String? refType,
    required int? refId,
    required String recordSource,
  }) async {
    if (amount <= 0) throw ArgumentError('流水金额必须大于 0');
    final DateTime at = occurredAt ?? DateTime.now();
    final AccountBalanceRule effective =
        rule ?? await _ruleFor(txn, accountId);
    return entryDao.append(
      txn,
      AccountEntryRecord(
        accountId: accountId,
        direction: direction,
        amount: amount,
        balanceAfter: 0, // append 在事务内重算并覆盖
        entryType: entryType,
        occurredAt: at,
        counterpartyAccountId: counterpartyAccountId,
        transferGroupId: transferGroupId,
        categoryId: categoryId,
        payee: payee,
        note: note,
        reason: reason,
        nonBinding: nonBinding,
        imageRef: imageRef,
        refType: refType,
        refId: refId,
        createdAt: DateTime.now(),
      ),
      rule: effective,
      recordSource: recordSource,
    );
  }

  Future<AccountBalanceRule> _ruleFor(
    DatabaseExecutor txn,
    int accountId,
  ) async {
    final List<Map<String, Object?>> rows = await txn.query(
      AccountDb.accountsTable,
      columns: <String>['kind'],
      where: 'id = ?',
      whereArgs: <Object?>[accountId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('账户不存在，不能记流水');
    return AccountBalanceRule.of(
      AccountKind.fromDb(rows.first['kind'] as String?),
    );
  }

  // ── 组合动作：全部落在上面两个根接口上 ──────────────────────────

  Future<double> opening(
    DatabaseExecutor txn, {
    required int accountId,
    required double amount,
    DateTime? occurredAt,
  }) =>
      credit(
        txn,
        accountId: accountId,
        amount: amount,
        entryType: AccountEntryType.opening,
        occurredAt: occurredAt,
      );

  Future<double> spend(
    DatabaseExecutor txn, {
    required int accountId,
    required double amount,
    String note = '',
    int? categoryId,
    String payee = '',
    DateTime? occurredAt,
  }) =>
      debit(
        txn,
        accountId: accountId,
        amount: amount,
        entryType: AccountEntryType.creditSpend,
        occurredAt: occurredAt,
        categoryId: categoryId,
        payee: payee,
        note: note,
      );

  Future<void> transfer(
    DatabaseExecutor txn, {
    required int fromId,
    required int toId,
    required double amount,
    required String note,
    DateTime? occurredAt,
  }) async {
    final DateTime at = occurredAt ?? DateTime.now();
    final String group = 'tx_${at.microsecondsSinceEpoch}_${fromId}_$toId';
    await debit(
      txn,
      accountId: fromId,
      amount: amount,
      entryType: AccountEntryType.transferOut,
      occurredAt: at,
      counterpartyAccountId: toId,
      transferGroupId: group,
      note: note,
      refType: 'transfer',
    );
    await credit(
      txn,
      accountId: toId,
      amount: amount,
      entryType: AccountEntryType.transferIn,
      occurredAt: at,
      counterpartyAccountId: fromId,
      transferGroupId: group,
      note: note,
      refType: 'transfer',
    );
  }

  /// 信用卡还款 2 条等值（C9-c）：来源腿走 [debit]、卡腿走 [credit]。
  Future<void> repay(
    DatabaseExecutor txn, {
    required int creditCardId,
    required int fromAccountId,
    required double amount,
    String note = '',
    DateTime? occurredAt,
  }) async {
    final DateTime at = occurredAt ?? DateTime.now();
    final String group =
        'repay_${at.microsecondsSinceEpoch}_${fromAccountId}_$creditCardId';
    await debit(
      txn,
      accountId: fromAccountId,
      amount: amount,
      entryType: AccountEntryType.creditRepay,
      occurredAt: at,
      counterpartyAccountId: creditCardId,
      transferGroupId: group,
      note: note,
      refType: 'liability_repay',
    );
    await credit(
      txn,
      accountId: creditCardId,
      amount: amount,
      entryType: AccountEntryType.creditRepay,
      occurredAt: at,
      counterpartyAccountId: fromAccountId,
      transferGroupId: group,
      note: note,
      refType: 'liability_repay',
    );
  }

  /// 余额调整（K4 为可用金额调整）：净转入额由 append 同事务联动。
  Future<double> adjust(
    DatabaseExecutor txn, {
    required int accountId,
    required double delta,
    required String reason,
    DateTime? occurredAt,
  }) async {
    final double value = delta.abs();
    if (delta > 0) {
      return credit(
        txn,
        accountId: accountId,
        amount: value,
        entryType: AccountEntryType.adjustment,
        occurredAt: occurredAt,
        reason: reason,
        refType: 'adjustment',
      );
    }
    return debit(
      txn,
      accountId: accountId,
      amount: value,
      entryType: AccountEntryType.adjustment,
      occurredAt: occurredAt,
      reason: reason,
      refType: 'adjustment',
    );
  }

  /// 账单出账息费：一条 `interest` 出账、`recordSource='auto'`（契-13）。
  Future<double> accrueInterest(
    DatabaseExecutor txn, {
    required int accountId,
    required double amount,
    DateTime? occurredAt,
  }) =>
      debit(
        txn,
        accountId: accountId,
        amount: amount,
        entryType: AccountEntryType.interest,
        occurredAt: occurredAt,
        note: '账单息费',
        refType: 'debt_cost',
        recordSource: 'auto',
      );
}
