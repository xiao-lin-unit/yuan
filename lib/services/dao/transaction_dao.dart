import '../../models/transaction.dart';
import '../../models/money.dart';
import '../../services/result.dart';

/// 收支/转账记录数据访问对象。
///
/// 提供对 transactions 表的增删改查。
/// 与 UI 层完全解耦，只暴露领域模型 [Transaction]。
class TransactionDao {
  /// 最近 N 条记录（用于首页、账本摘要）
  Future<List<Transaction>> recent({int limit = 20}) async {
    await Future<void>.delayed(Duration.zero);
    final all = seedTransactions;
    all.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return all.take(limit).toList();
  }

  /// 查询指定账户相关的所有流水（用于账户明细页）
  Future<List<Transaction>> byAccount(String accountId) async {
    await Future<void>.delayed(Duration.zero);
    return seedTransactions
        .where((t) =>
            t.accountId == accountId || t.toAccountId == accountId)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  /// 按日期范围查询
  Future<List<Transaction>> byDateRange(DateTime start, DateTime end) async {
    await Future<void>.delayed(Duration.zero);
    return seedTransactions
        .where((t) =>
            t.occurredAt.isAfter(start.subtract(const Duration(days: 1))) &&
            t.occurredAt.isBefore(end.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  /// 本月收支汇总
  /// 返回 [支出总额, 收入总额]
  Future<(Money expense, Money income)> monthlySummary(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final list = await byDateRange(start, end);

    int exp = 0, inc = 0;
    for (final t in list) {
      if (t.type == TxType.expense) exp += t.amount.cents;
      if (t.type == TxType.income) inc += t.amount.cents;
    }
    return (Money.fromCents(exp), Money.fromCents(inc));
  }

  /// 插入一条记录
  Future<Result<Transaction>> insert(Transaction tx) async {
    await Future<void>.delayed(Duration.zero);
    // 业务校验：金额必须为正数
    if (tx.amount.isZero) {
      return const Err('金额不能为零');
    }
    if (tx.amount.isNegative) {
      return const Err('金额不能为负数');
    }
    // 转账必须指定转入账户
    if (tx.type == TxType.transfer && tx.toAccountId == null) {
      return const Err('转账必须指定转入账户');
    }
    // 转账两端不能是同一账户
    if (tx.type == TxType.transfer && tx.toAccountId == tx.accountId) {
      return const Err('转入账户不能与转出账户相同');
    }
    return Ok(tx);
  }

  /// 软删除
  Future<void> softDelete(String id) async {
    await Future<void>.delayed(Duration.zero);
  }
}

/// 种子数据：模拟数据库中的初始交易记录。
List<Transaction> seedTransactions = [
  Transaction(
    id: 'tx_001',
    type: TxType.expense,
    categoryId: 'food',
    occurredAt: DateTime(2026, 10, 26, 12, 30),
    amount: Money.fromDouble(28),
    accountId: 'acc_wechat_1',
    remark: '午餐',
    createdAt: DateTime(2026, 10, 26),
    updatedAt: DateTime(2026, 10, 26),
  ),
  Transaction(
    id: 'tx_002',
    type: TxType.income,
    categoryId: 'salary',
    occurredAt: DateTime(2026, 10, 25, 17, 0),
    amount: Money.fromDouble(8000),
    accountId: 'acc_savings_1',
    remark: '10月工资',
    createdAt: DateTime(2026, 10, 25),
    updatedAt: DateTime(2026, 10, 25),
  ),
  Transaction(
    id: 'tx_003',
    type: TxType.expense,
    categoryId: 'traffic',
    occurredAt: DateTime(2026, 10, 25, 18, 0),
    amount: Money.fromDouble(200),
    accountId: 'acc_credit_1',
    remark: '加油',
    createdAt: DateTime(2026, 10, 25),
    updatedAt: DateTime(2026, 10, 25),
  ),
  Transaction(
    id: 'tx_004',
    type: TxType.expense,
    categoryId: 'market',
    occurredAt: DateTime(2026, 10, 25, 19, 0),
    amount: Money.fromDouble(65),
    accountId: 'acc_wechat_1',
    remark: '超市买菜',
    createdAt: DateTime(2026, 10, 25),
    updatedAt: DateTime(2026, 10, 25),
  ),
  Transaction(
    id: 'tx_005',
    type: TxType.transfer,
    categoryId: 'other',
    occurredAt: DateTime(2026, 10, 24, 10, 0),
    amount: Money.fromDouble(2000),
    accountId: 'acc_savings_1',
    toAccountId: 'acc_wechat_1',
    remark: '储蓄卡转微信',
    createdAt: DateTime(2026, 10, 24),
    updatedAt: DateTime(2026, 10, 24),
  ),
  Transaction(
    id: 'tx_006',
    type: TxType.expense,
    categoryId: 'finance',
    occurredAt: DateTime(2026, 10, 20, 9, 0),
    amount: Money.fromDouble(1000),
    accountId: 'acc_savings_1',
    remark: '信用卡还款',
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  ),
  Transaction(
    id: 'tx_007',
    type: TxType.expense,
    categoryId: 'clothing',
    occurredAt: DateTime(2026, 10, 18, 15, 0),
    amount: Money.fromDouble(394),
    accountId: 'acc_wechat_1',
    remark: '买鞋',
    createdAt: DateTime(2026, 10, 18),
    updatedAt: DateTime(2026, 10, 18),
  ),
  Transaction(
    id: 'tx_008',
    type: TxType.expense,
    categoryId: 'entertain',
    occurredAt: DateTime(2026, 10, 15, 20, 0),
    amount: Money.fromDouble(120),
    accountId: 'acc_credit_1',
    remark: '电影票',
    createdAt: DateTime(2026, 10, 15),
    updatedAt: DateTime(2026, 10, 15),
  ),
  Transaction(
    id: 'tx_009',
    type: TxType.income,
    categoryId: 'investment',
    occurredAt: DateTime(2026, 10, 10, 10, 0),
    amount: Money.fromDouble(150),
    accountId: 'acc_savings_1',
    remark: '基金分红',
    createdAt: DateTime(2026, 10, 10),
    updatedAt: DateTime(2026, 10, 10),
  ),
  Transaction(
    id: 'tx_010',
    type: TxType.expense,
    categoryId: 'medical',
    occurredAt: DateTime(2026, 10, 8, 11, 0),
    amount: Money.fromDouble(86),
    accountId: 'acc_social_1',
    remark: '医保支付门诊',
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
  ),
];
