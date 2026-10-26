import '../../models/liability.dart';
import '../../models/money.dart';
import '../../services/result.dart';

/// 负债数据访问对象。
///
/// 提供对 liabilities 表的增删改查，以及还款计划的查询。
/// 与 UI 层完全解耦，只暴露领域模型 [Liability]。
class LiabilityDao {
  /// 全部负债（未删除）
  Future<List<Liability>> list() async {
    await Future<void>.delayed(Duration.zero);
    return seedLiabilities;
  }

  /// 按 id 查询
  Future<Liability?> getById(String id) async {
    final list = await list();
    for (final l in list) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// 插入负债
  Future<Result<Liability>> insert(Liability liability) async {
    await Future<void>.delayed(Duration.zero);
    if (liability.name.isEmpty) return const Err('负债名称不能为空');
    if (liability.remainingPrincipal.isNegative) {
      return const Err('剩余本金不能为负数');
    }
    if (liability.isInterestBearing && liability.annualInterestRate < 0) {
      return const Err('利率不能为负数');
    }
    return Ok(liability);
  }

  /// 更新剩余本金（还款后调用）
  Future<Liability> updatePrincipal(String id, Money newPrincipal) async {
    await Future<void>.delayed(Duration.zero);
    final list = await list();
    for (final l in list) {
      if (l.id == id) {
        return Liability(
          id: l.id,
          name: l.name,
          type: l.type,
          remainingPrincipal: newPrincipal,
          isInterestBearing: l.isInterestBearing,
          annualInterestRate: l.annualInterestRate,
          borrowDate: l.borrowDate,
          dueDate: l.dueDate,
          repaymentMethod: l.repaymentMethod,
          periodPayment: l.periodPayment,
          paidPeriods: l.paidPeriods,
          totalPeriods: l.totalPeriods,
          linkedAccountId: l.linkedAccountId,
          remark: l.remark,
          createdAt: l.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    return list.first;
  }

  /// 更新负债（通用）
  Future<Liability> update(Liability liability) async {
    await Future<void>.delayed(Duration.zero);
    return liability;
  }

  /// 获取还款计划
  Future<List<RepaymentSchedule>> getSchedule(String liabilityId) async {
    final l = await getById(liabilityId);
    if (l == null) return [];
    return generateSchedule(l);
  }

  /// 标记某期为已还，并同步剩余本金
  /// 返回更新后的负债
  Future<Liability> markPeriodPaid(String liabilityId, int periodNumber) async {
    await Future<void>.delayed(Duration.zero);
    final l = await getById(liabilityId);
    if (l == null) return seedLiabilities.first;
    final schedule = generateSchedule(l);
    if (periodNumber < 1 || periodNumber > schedule.length) return l;

    final paid = schedule[periodNumber - 1];
    // 剩余本金扣除本期本金
    final newPrincipal = Money.fromCents(
        (l.remainingPrincipal.cents - paid.principal.cents).clamp(0, l.remainingPrincipal.cents));

    return Liability(
      id: l.id,
      name: l.name,
      type: l.type,
      remainingPrincipal: newPrincipal,
      isInterestBearing: l.isInterestBearing,
      annualInterestRate: l.annualInterestRate,
      borrowDate: l.borrowDate,
      dueDate: l.dueDate,
      repaymentMethod: l.repaymentMethod,
      periodPayment: l.periodPayment,
      paidPeriods: periodNumber,
      totalPeriods: l.totalPeriods,
      linkedAccountId: l.linkedAccountId,
      remark: l.remark,
      createdAt: l.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// 查询负债对应的信用卡账户 id（双向关联）
  Future<String?> getLinkedCreditAccountId(String liabilityId) async {
    final l = await getById(liabilityId);
    return l?.linkedAccountId;
  }
}

/// 种子数据：模拟数据库中的负债记录。
List<Liability> seedLiabilities = [
  Liability(
    id: 'liab_car_1',
    name: '车贷',
    type: LiabilityType.carLoan,
    remainingPrincipal: Money.fromDouble(3500),
    isInterestBearing: true,
    annualInterestRate: 0.045,
    borrowDate: DateTime(2025, 1, 10),
    dueDate: DateTime(2027, 1, 10),
    repaymentMethod: RepaymentMethod.equalInstallment,
    periodPayment: Money.fromDouble(1200),
    paidPeriods: 10,
    totalPeriods: 24,
    linkedAccountId: 'acc_savings_1',
    remark: '月供1200',
    createdAt: DateTime(2025, 1, 10),
    updatedAt: DateTime(2026, 10, 1),
  ),
  Liability(
    id: 'liab_friend_1',
    name: '借同事小王',
    type: LiabilityType.loanFromFriend,
    remainingPrincipal: Money.fromDouble(1700),
    isInterestBearing: false,
    borrowDate: DateTime(2026, 5, 20),
    repaymentMethod: RepaymentMethod.flexible,
    linkedAccountId: 'acc_wechat_1',
    remark: '无息，下月还',
    createdAt: DateTime(2026, 5, 20),
    updatedAt: DateTime(2026, 5, 20),
  ),
];
