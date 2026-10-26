import '../../models/transaction.dart';
import '../../models/money.dart';
import '../../services/result.dart';

/// 账户流水（出入账）数据访问对象。
///
/// 记录每个账户的逐笔变动，用于账户明细页的出入记录展示，
/// 并支撑财务专家视角的恒等式校验。
class AccountFlowDao {
  /// 查询指定账户的流水（按时间正序，便于校验）
  Future<List<AccountFlow>> byAccount(String accountId) async {
    await Future<void>.delayed(Duration.zero);
    return seedFlows
        .where((f) => f.accountId == accountId)
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  }

  /// 按时间倒序（用于展示，最新在前）
  Future<List<AccountFlow>> byAccountDesc(String accountId) async {
    final list = await byAccount(accountId);
    return list.reversed.toList();
  }

  /// 汇总指定账户在指定日期范围内的入/出/净额
  Future<(Money inflow, Money outflow, Money net)> summary(
    String accountId,
    DateTime start,
    DateTime end,
  ) async {
    final flows = await byAccount(accountId);
    int inCents = 0, outCents = 0;
    for (final f in flows) {
      if (f.occurredAt.isBefore(start) || f.occurredAt.isAfter(end)) continue;
      final direction = f.flowType;
      if (direction == FlowType.inflow || direction == FlowType.adjustmentUp) {
        inCents += f.amountCents;
      } else {
        outCents += f.amountCents;
      }
    }
    return (
      Money.fromCents(inCents),
      Money.fromCents(outCents),
      Money.fromCents(inCents - outCents),
    );
  }

  /// 本月汇总（快捷方法）
  Future<(Money inflow, Money outflow, Money net)> monthlySummary(
    String accountId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return summary(accountId, start, end);
  }

  /// 插入一条流水
  Future<Result<AccountFlow>> insert(AccountFlow flow) async {
    await Future<void>.delayed(Duration.zero);
    if (flow.amountCents <= 0) {
      return const Err('流水金额必须大于零');
    }
    return Ok(flow);
  }
}

/// 种子数据：模拟数据库中的账户流水记录。
/// 与 seedTransactions 对应，体现资金的实际移动路径。
List<AccountFlow> seedFlows = [
  // 微信零钱
  AccountFlow(
    id: 'fl_001',
    accountId: 'acc_wechat_1',
    flowType: FlowType.inflow,
    relatedRecordId: 'tx_005',
    relatedRecordType: 'transfer',
    amountCents: 200000, // 转入 +2000
    balanceAfterCents: 415000, // 余额 4150
    occurredAt: DateTime(2026, 10, 24, 10, 0),
    remark: '储蓄卡转入',
    createdAt: DateTime(2026, 10, 24),
  ),
  AccountFlow(
    id: 'fl_002',
    accountId: 'acc_wechat_1',
    flowType: FlowType.outflow,
    relatedRecordId: 'tx_004',
    relatedRecordType: 'expense',
    amountCents: 6500, // 支出 -65
    balanceAfterCents: 408500, // 余额 4085
    occurredAt: DateTime(2026, 10, 25, 19, 0),
    remark: '超市买菜',
    createdAt: DateTime(2026, 10, 25),
  ),
  AccountFlow(
    id: 'fl_003',
    accountId: 'acc_wechat_1',
    flowType: FlowType.outflow,
    relatedRecordId: 'tx_007',
    relatedRecordType: 'expense',
    amountCents: 39400,
    balanceAfterCents: 369100,
    occurredAt: DateTime(2026, 10, 18, 15, 0),
    remark: '买鞋',
    createdAt: DateTime(2026, 10, 18),
  ),
  // 储蓄卡
  AccountFlow(
    id: 'fl_004',
    accountId: 'acc_savings_1',
    flowType: FlowType.inflow,
    relatedRecordId: 'tx_002',
    relatedRecordType: 'income',
    amountCents: 800000, // 工资入账 +8000
    balanceAfterCents: 980000, // 余额 9800
    occurredAt: DateTime(2026, 10, 25, 17, 0),
    remark: '10月工资',
    createdAt: DateTime(2026, 10, 25),
  ),
  AccountFlow(
    id: 'fl_005',
    accountId: 'acc_savings_1',
    flowType: FlowType.outflow,
    relatedRecordId: 'tx_005',
    relatedRecordType: 'transfer',
    amountCents: 200000, // 转出 -2000
    balanceAfterCents: 780000, // 余额 7800
    occurredAt: DateTime(2026, 10, 24, 10, 0),
    remark: '转微信零钱',
    createdAt: DateTime(2026, 10, 24),
  ),
  AccountFlow(
    id: 'fl_006',
    accountId: 'acc_savings_1',
    flowType: FlowType.outflow,
    relatedRecordId: 'tx_006',
    relatedRecordType: 'expense',
    amountCents: 100000, // 信用卡还款 -1000
    balanceAfterCents: 680000, // 余额 6800
    occurredAt: DateTime(2026, 10, 20, 9, 0),
    remark: '信用卡还款',
    createdAt: DateTime(2026, 10, 20),
  ),
  // 医保账户
  AccountFlow(
    id: 'fl_007',
    accountId: 'acc_social_1',
    flowType: FlowType.outflow,
    relatedRecordId: 'tx_010',
    relatedRecordType: 'expense',
    amountCents: 8600,
    balanceAfterCents: 111400, // 余额 1114
    occurredAt: DateTime(2026, 10, 8, 11, 0),
    remark: '门诊支付',
    createdAt: DateTime(2026, 10, 8),
  ),
];
