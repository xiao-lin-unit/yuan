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
/// 【所属模块】service/core · 账户资金
/// 【实现功能】账户资金变动的唯一门面：debit / credit 两个根接口，所有涉及余额的功能（开户 / 消费 / 转账 / 还款 / 调整 / 账单息费）都组合它们；规则按账户 kind 统一推导。
/// 【使用限制】全库 AccountEntryDao.append 只在本类调用 1 次；本类不自建事务，第一参数收 DatabaseExecutor；不得在 Controller 或页面里直接拼流水；金额必须为正；rule 为空时按账户 kind 现查。
/// 【入参与结果】构造收 AccountEntryDao；根接口返回 Future<double>（追加后的余额），组合动作返回 Future<double> / Future<void>；调用方必须 await。
/// 【异常与调用方处理】amount<=0 抛 ArgumentError；账户不存在抛 StateError；DAO / SQL 异常原样上抛并回滚整个 uow.run 事务。调用方需自行 try/catch 提示用户、保持快照旧值，不得吞掉异常后继续刷新。
class AccountLedger {
  /// 【所属模块】service/core · 账户资金
  /// 【实现功能】用共享的 AccountEntryDao 创建资金门面。
  /// 【使用限制】必须由 components.dart 建且只建一份，注入储蓄 / 信用卡 / 跨模块编排；不要在页面里 new。
  /// 【入参与结果】entryDao 必填且非 null；无返回值（const 构造）。结果为可复用的 AccountLedger。
  /// 【异常与调用方处理】构造不抛异常；DAO 未就绪会在写流水时暴露，调用方需保证装配顺序。
  const AccountLedger(this.entryDao);

  final AccountEntryDao entryDao;

  /// 【所属模块】service/core · 账户资金（唯一出账接口）
  /// 【实现功能】记一条出账流水：所有账户的支出类动作都必须经此接口，由 append 在同事务内重算余额并联动次表列。
  /// 【使用限制】必须在 uow.run 事务内调用；amount 必须 > 0；rule 为空时按 accountId 现查 kind 推导（信用卡 / 储蓄方向不同）；不得用 credit(amount 取负) 代替出账。
  /// 【入参与结果】txn / accountId / amount / entryType 必填；rule / occurredAt / counterpartyAccountId / transferGroupId / categoryId / payee / note / reason / nonBinding / imageRef / refType / refId / recordSource 可选。返回 Future<double>（追加后 balanceAfter），调用方必须 await；结果只用于对账，刷新放 afterCommit。
  /// 【异常与调用方处理】amount<=0 抛 ArgumentError「流水金额必须大于 0」；账户不存在抛 StateError；DAO / CHECK 异常原样上抛并整体回滚。调用方需自行 try/catch 提示用户，不要吞掉异常后继续走后续接口。
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

  /// 【所属模块】service/core · 账户资金（唯一入账接口）
  /// 【实现功能】记一条入账流水：所有账户的收入 / 回款类动作都必须经此接口，与 debit 共用同一套规则推导与 append。
  /// 【使用限制】必须在 uow.run 事务内调用；amount 必须 > 0；不得用 debit 取负代替入账；还款卡腿、转账入腿都走它。
  /// 【入参与结果】入参与 debit 完全对称。返回 Future<double>（追加后 balanceAfter），调用方必须 await；结果只用于对账，刷新放 afterCommit。
  /// 【异常与调用方处理】amount<=0 抛 ArgumentError；账户不存在抛 StateError；DAO / CHECK 异常原样上抛并整体回滚。调用方需自行 try/catch。
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

  /// 【所属模块】service/core · 账户资金（组合动作）
  /// 【实现功能】开户期初：组合 credit 写一条 AccountEntryType.opening 入账流水。
  /// 【使用限制】仅新建账户首次录入期初时调用；编辑账户禁止改期初；K4 投资账户的「可用金额」属有意的期初事实录入，与历史持仓补录（契-14，不写流水）不同。
  /// 【入参与结果】txn / accountId / amount 必填；occurredAt 可选。返回 Future<double>（期初后余额），调用方必须 await。
  /// 【异常与调用方处理】amount<=0 抛 ArgumentError；账户不存在 / DAO 异常上抛并回滚。调用方需自行 try/catch，失败时账户插入也应一并回滚（同事务）。
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

  /// 【所属模块】service/core · 账户资金（组合动作）
  /// 【实现功能】消费：组合 debit 写一条 creditSpend 出账流水（契-17：消费与还款不各写一套出账）。
  /// 【使用限制】仅信用卡消费入口；储蓄类支出走同一 debit 根接口但由各自 Controller 组装；必须在事务内调用。
  /// 【入参与结果】txn / accountId / amount 必填；note / categoryId / payee / occurredAt 可选。返回 Future<double>，调用方必须 await。
  /// 【异常与调用方处理】amount<=0 抛 ArgumentError；账户不存在 / DAO 异常上抛并回滚。调用方需自行 try/catch 提示用户。
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

  /// 【所属模块】service/core · 账户资金（组合动作）
  /// 【实现功能】转账：同事务先 debit(transferOut) 再 credit(transferIn)，两条用同一个 transferGroupId 配对、金额相等。
  /// 【使用限制】两腿必须在同一 uow.run 里（本接口已保证）；禁止指向 kind=credit 的账户（C9-b）；不得用本接口实现还款（还款走 repay）。
  /// 【入参与结果】txn / fromId / toId / amount / note 必填；occurredAt 可选。返回 Future<void>，调用方必须 await；刷新放 afterCommit。
  /// 【异常与调用方处理】任一腿失败（含第二腿）整体回滚，不会留下"只扣了来源账户"的半写；amount<=0 / 账户不存在 / DAO 异常上抛。调用方需自行 try/catch 提示用户。
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
  /// 【所属模块】service/core · 账户资金（组合动作）
  /// 【实现功能】信用卡还款 C9-c：来源账户 debit + 信用卡 credit 两条等值 creditRepay 流水，用同一 group 配对。
  /// 【使用限制】绝不调用 transfer；本息费在账单出账时已记为 debt_cost，还款不重复记支出；interest=0 不退化成 1 条；必须在事务内调用。
  /// 【入参与结果】txn / creditCardId / fromAccountId / amount / note 必填；occurredAt 可选。返回 Future<void>，调用方必须 await；刷新放 afterCommit。
  /// 【异常与调用方处理】任一腿失败整体回滚；amount<=0 / 账户不存在 / DAO 异常上抛。调用方需自行 try/catch 提示用户。
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
  /// 【所属模块】service/core · 账户资金（组合动作）
  /// 【实现功能】余额调整（K4 为可用金额调整）：按 delta 正负组合 credit / debit 写一条 adjustment 流水，净转入额由 append 同事务联动。
  /// 【使用限制】delta 不得为 0 的语义由调用方保证（本接口取 abs）；必须填 reason（account_entries 有 CHECK）；必须在事务内调用。
  /// 【入参与结果】txn / accountId / delta / reason 必填；occurredAt 可选。返回 Future<double>（调整后余额），调用方必须 await。
  /// 【异常与调用方处理】amount<=0 抛 ArgumentError；reason 为空会触发 DB CHECK 异常；账户不存在 / DAO 异常上抛并回滚。调用方需自行 try/catch 提示用户。
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
  /// 【所属模块】service/core · 账户资金（组合动作）
  /// 【实现功能】账单出账息费（契-13）：组合 debit 写一条 interest 出账、refType=debt_cost、recordSource=auto，只增 K2 欠款。
  /// 【使用限制】只在跨账单日且 I+F>0 时由账单出账动作调用；该流水不进三个统计视图（硬-16），不得在还款时重复记；必须在事务内调用。
  /// 【入参与结果】txn / accountId / amount 必填；occurredAt 可选。返回 Future<double>，调用方必须 await。
  /// 【异常与调用方处理】amount<=0 抛 ArgumentError；账户不存在 / DAO 异常上抛并回滚。调用方需自行 try/catch；I+F=0 时应不调用本接口而不是传 0。
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
