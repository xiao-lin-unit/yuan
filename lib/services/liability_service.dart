import '../models/liability.dart';
import '../models/money.dart';
import 'dao/liability_dao.dart';
import 'dao/repayment_record_dao.dart';
import 'result.dart';

/// 负债业务服务。
///
/// 封装负债模块的增删改查、还款计划生成、还款记录、提前还款等。
class LiabilityService {
  final LiabilityDao _dao;
  final RepaymentRecordDao _recordDao;

  LiabilityService({
    LiabilityDao? dao,
    RepaymentRecordDao? recordDao,
  })  : _dao = dao ?? LiabilityDao(),
        _recordDao = recordDao ?? RepaymentRecordDao();

  /// 全部负债
  Future<List<Liability>> all() => _dao.list();

  /// 负债总额
  Future<Money> totalDebt() async {
    final list = await _dao.list();
    int cents = 0;
    for (final l in list) {
      cents += l.remainingPrincipal.cents;
    }
    return Money.fromCents(cents);
  }

  /// 月还款总额（根据还款计划推算本月应还）
  Future<Money> monthlyPayment() async {
    final list = await _dao.list();
    int cents = 0;
    for (final l in list) {
      if (l.repaymentMethod == RepaymentMethod.flexible) {
        // 随借随还，无固定月供，用已记录的还款均值估算
        final records = await _recordDao.byLiability(l.id);
        if (records.isNotEmpty) {
          int total = 0;
          for (final r in records) total += r.amount.cents;
          cents += (total ~/ records.length);
        }
      } else {
        cents += l.periodPayment.cents;
      }
    }
    return Money.fromCents(cents);
  }

  /// 按 id 查询
  Future<Liability?> byId(String id) => _dao.getById(id);

  /// 新增负债
  Future<Result<Liability>> add(Liability liability) => _dao.insert(liability);

  /// 更新负债
  Future<Liability> update(Liability liability) => _dao.update(liability);

  /// 还款计划
  Future<List<RepaymentSchedule>> schedule(String liabilityId) =>
      _dao.getSchedule(liabilityId);

  /// 还款记录
  Future<List<RepaymentRecord>> records(String liabilityId) =>
      _recordDao.byLiability(liabilityId);

  /// 累计已还
  Future<Money> totalRepaid(String liabilityId) =>
      _recordDao.totalRepaid(liabilityId);

  /// 执行一次还款。
  /// 规则：
  /// 1. 金额须为正数
  /// 2. 不能超过剩余本金
  /// 3. 还款后同步减少剩余本金
  /// 4. 记录还款流水
  Future<Result<Liability>> repay({
    required String liabilityId,
    required Money amount,
    required String fromAccountId,
    String? remark,
  }) async {
    if (amount.isZero) return const Err('还款金额不能为零');
    if (amount.isNegative) return const Err('还款金额不能为负数');

    final l = await _dao.getById(liabilityId);
    if (l == null) return const Err('负债不存在');

    if (amount.cents > l.remainingPrincipal.cents) {
      return Err('还款金额超过剩余本金 ¥${l.remainingPrincipal.yuan.toStringAsFixed(2)}');
    }

    final record = RepaymentRecord(
      id: 'rep_${DateTime.now().microsecondsSinceEpoch}',
      liabilityId: liabilityId,
      repaidAt: DateTime.now(),
      amount: amount,
      fromAccountId: fromAccountId,
      remark: remark,
      createdAt: DateTime.now(),
    );

    final result = await _recordDao.insert(record);
    return result.andThen<Liability>((_) async {
      final newPrincipal = Money.fromCents(
          l.remainingPrincipal.cents - amount.cents);
      final updated = await _dao.updatePrincipal(liabilityId, newPrincipal);
      return Ok(updated);
    }.call);
  }

  /// 提前还款模拟。
  /// 返回可节省的利息（仅对分期类负债有意义）。
  /// 等额本息/等额本金：提前还款可省掉剩余期数的利息部分。
  /// 随借随还/先息后本：利息按日计，提前还款无节省。
  Future<Money> simulateEarlyRepay({
    required String liabilityId,
    required Money extraAmount,
  }) async {
    final l = await _dao.getById(liabilityId);
    if (l == null) return Money.zero;
    if (l.totalPeriods == null) return Money.zero;

    final schedule = await _dao.getSchedule(liabilityId);
    int remainingInterest = 0;
    for (int i = l.paidPeriods; i < schedule.length; i++) {
      remainingInterest += schedule[i].interest.cents;
    }

    // 提前还款金额可减少本金，从而减少后续利息
    // 简化模型：节省比例 = 提前还款金额 / 剩余本金 × 剩余利息
    if (l.remainingPrincipal.cents == 0) return Money.zero;
    final saved = (remainingInterest * extraAmount.cents / l.remainingPrincipal.cents).round();
    return Money.fromCents(saved);
  }

  /// 即将到期（未来30天内）的负债
  Future<List<Liability>> dueSoon() async {
    final list = await _dao.list();
    final now = DateTime.now();
    final future = now.add(const Duration(days: 30));
    return list.where((l) {
      if (l.dueDate == null) return false;
      return l.dueDate!.isAfter(now) && l.dueDate!.isBefore(future);
    }).toList();
  }
}
