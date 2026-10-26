import '../../models/liability.dart';
import '../../models/money.dart';
import '../../services/result.dart';

/// 还款记录数据访问对象。
///
/// 记录每次还款的实际发生情况，用于负债明细页的出入记录展示。
class RepaymentRecordDao {
  /// 查询指定负债的所有还款记录（倒序）
  Future<List<RepaymentRecord>> byLiability(String liabilityId) async {
    await Future<void>.delayed(Duration.zero);
    return seedRepaymentRecords
        .where((r) => r.liabilityId == liabilityId)
        .toList()
      ..sort((a, b) => b.repaidAt.compareTo(a.repaidAt));
  }

  /// 插入一条还款记录
  Future<Result<RepaymentRecord>> insert(RepaymentRecord record) async {
    await Future<void>.delayed(Duration.zero);
    if (record.amount.isZero) return const Err('还款金额不能为零');
    if (record.amount.isNegative) return const Err('还款金额不能为负数');
    return Ok(record);
  }

  /// 累计已还总额
  Future<Money> totalRepaid(String liabilityId) async {
    final list = await byLiability(liabilityId);
    int cents = 0;
    for (final r in list) {
      cents += r.amount.cents;
    }
    return Money.fromCents(cents);
  }
}

/// 种子数据：模拟数据库中的还款记录。
List<RepaymentRecord> seedRepaymentRecords = [
  RepaymentRecord(
    id: 'rep_001',
    liabilityId: 'liab_car_1',
    repaidAt: DateTime(2026, 10, 10, 9, 0),
    amount: Money.fromDouble(1200),
    fromAccountId: 'acc_savings_1',
    remark: '第11期月供',
    createdAt: DateTime(2026, 10, 10),
  ),
  RepaymentRecord(
    id: 'rep_002',
    liabilityId: 'liab_car_1',
    repaidAt: DateTime(2026, 9, 10, 9, 0),
    amount: Money.fromDouble(1200),
    fromAccountId: 'acc_savings_1',
    remark: '第10期月供',
    createdAt: DateTime(2026, 9, 10),
  ),
  RepaymentRecord(
    id: 'rep_003',
    liabilityId: 'liab_car_1',
    repaidAt: DateTime(2026, 8, 10, 9, 0),
    amount: Money.fromDouble(1200),
    fromAccountId: 'acc_savings_1',
    remark: '第9期月供',
    createdAt: DateTime(2026, 8, 10),
  ),
  RepaymentRecord(
    id: 'rep_004',
    liabilityId: 'liab_car_1',
    repaidAt: DateTime(2026, 7, 10, 9, 0),
    amount: Money.fromDouble(1200),
    fromAccountId: 'acc_savings_1',
    remark: '第8期月供',
    createdAt: DateTime(2026, 7, 10),
  ),
];
