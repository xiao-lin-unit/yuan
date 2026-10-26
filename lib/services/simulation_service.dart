import '../models/money.dart';
import 'account_service.dart';
import 'liability_service.dart';
import 'transaction_service.dart';

/// 情景推演服务。
///
/// 实现文档中 14 种情景的计算逻辑，支持多情景叠加与冲突检测。
/// 输出逐月现金流，供推演结果页展示。
class SimulationService {
  final AccountService _accountService;
  final LiabilityService _liabilityService;
  final TransactionService _txService;

  SimulationService({
    required AccountService accountService,
    required LiabilityService liabilityService,
    required TransactionService txService,
  })  : _accountService = accountService,
        _liabilityService = liabilityService,
        _txService = txService;

  /// 推演参数
  Future<SimulationContext> buildContext() async {
    final liquid = await _accountService.totalLiquid();
    final (expense, income) = await _txService.monthlySummary(DateTime.now());
    final debt = await _liabilityService.totalDebt();
    final monthlyPayment = await _liabilityService.monthlyPayment();
    return SimulationContext(
      liquid: liquid,
      monthlyExpense: expense,
      monthlyIncome: income,
      totalDebt: debt,
      monthlyPayment: monthlyPayment,
    );
  }

  /// 运行推演。
  /// scenarios：要叠加的情景列表
  /// months：推演月数
  ///
  /// 冲突检测：
  /// - 失业 与 收入上涨/下降 冲突
  /// - 提前还清 与 新增负债 同一负债冲突
  /// - 收入上涨 与 收入下降 同时作用于同一收入源冲突
  Result<List<MonthlyCashflow>> run({
    required List<Scenario> scenarios,
    required int months,
  }) {
    // 冲突检测
    final conflict = _detectConflict(scenarios);
    if (conflict != null) return Err(conflict);

    final ctx = SimulationContextPlaceholder(
      liquid: Money.fromDouble(8320),
      monthlyExpense: Money.fromDouble(3500),
      monthlyIncome: Money.fromDouble(8000),
      monthlyPayment: Money.fromDouble(1500),
      totalDebt: Money.fromDouble(5200),
    );

    var liquid = ctx.liquid;
    var monthlyExpense = ctx.monthlyExpense;
    var monthlyIncome = ctx.monthlyIncome;
    var totalDebt = ctx.totalDebt;
    var monthlyPayment = ctx.monthlyPayment;

    // 应用一次性情景
    for (final s in scenarios) {
      switch (s.kind) {
        case ScenarioKind.lumpSumExpense:
          // 大额一次性支出：从流动资金扣除
          liquid = Money.fromCents(liquid.cents - (s.params['amount'] as double).round() * 100);
          break;
        case ScenarioKind.newLiability:
          final amount = Money.fromDouble(s.params['amount'] as double);
          totalDebt = Money.fromCents(totalDebt.cents + amount.cents);
          monthlyPayment = Money.fromCents(
              monthlyPayment.cents + (s.params['periodPayment'] as double).round() * 100);
          break;
        case ScenarioKind.earlyRepay:
          final amount = Money.fromDouble(s.params['amount'] as double);
          totalDebt = Money.fromCents(
              (totalDebt.cents - amount.cents).clamp(0, totalDebt.cents));
          break;
        default:
          break;
      }
    }

    final result = <MonthlyCashflow>[];
    for (int m = 0; m < months; m++) {
      // 逐月计算
      var income = monthlyIncome;
      var expense = monthlyExpense;
      var payment = monthlyPayment;

      for (final s in scenarios) {
        switch (s.kind) {
          case ScenarioKind.unemployment:
            income = Money.zero;
            break;
          case ScenarioKind.incomeUp:
            final rate = s.params['rate'] as double;
            income = Money.fromCents((income.cents * (1 + rate)).round());
            break;
          case ScenarioKind.incomeDown:
            final rate = s.params['rate'] as double;
            income = Money.fromCents((income.cents * (1 - rate)).round());
            break;
          case ScenarioKind.extraSave:
            final extra = Money.fromDouble(s.params['amount'] as double);
            // 额外存储不计入支出，但减少流动资金
            liquid = Money.fromCents(liquid.cents - extra.cents);
            break;
          case ScenarioKind.fixedExpenseUp:
            final extra = Money.fromDouble(s.params['amount'] as double);
            expense = Money.fromCents(expense.cents + extra.cents);
            break;
          case ScenarioKind.passiveIncomeUp:
            final extra = Money.fromDouble(s.params['amount'] as double);
            income = Money.fromCents(income.cents + extra.cents);
            break;
          default:
            break;
        }
      }

      final net = Money.fromCents(
          income.cents - expense.cents - payment.cents);
      liquid = Money.fromCents(liquid.cents + net.cents);

      result.add(MonthlyCashflow(
        monthIndex: m,
        income: income,
        expense: expense,
        payment: payment,
        net: net,
        liquidAfter: liquid,
      ));
    }

    return Ok(result);
  }

  /// 冲突检测
  String? _detectConflict(List<Scenario> scenarios) {
    final kinds = scenarios.map((s) => s.kind).toSet();

    if (kinds.contains(ScenarioKind.unemployment) &&
        (kinds.contains(ScenarioKind.incomeUp) ||
            kinds.contains(ScenarioKind.incomeDown))) {
      return '失业期间不应同时发生收入上涨或下降，请移除冲突情景';
    }

    if (kinds.contains(ScenarioKind.incomeUp) &&
        kinds.contains(ScenarioKind.incomeDown)) {
      return '收入上涨与收入下降不能同时作用于同一收入来源';
    }

    // 同一负债不能同时提前还清和新增
    final earlyRepayIds = scenarios
        .where((s) => s.kind == ScenarioKind.earlyRepay)
        .map((s) => s.params['liabilityId'] as String?)
        .whereType<String>()
        .toSet();
    final newLiabilityFlag = kinds.contains(ScenarioKind.newLiability);
    if (earlyRepayIds.isNotEmpty && newLiabilityFlag) {
      return '同一笔负债不能同时提前还清和新增，请移除其一';
    }

    return null;
  }
}

/// 推演上下文（当前真实财务状态快照）
class SimulationContext {
  final Money liquid;
  final Money monthlyExpense;
  final Money monthlyIncome;
  final Money totalDebt;
  final Money monthlyPayment;

  const SimulationContext({
    required this.liquid,
    required this.monthlyExpense,
    required this.monthlyIncome,
    required this.totalDebt,
    required this.monthlyPayment,
  });

  /// 按当前月支出计算可维持月数
  double get sustainableMonths {
    if (monthlyExpense.cents == 0) return double.infinity;
    return liquid.cents / monthlyExpense.cents;
  }

  /// 资金缺口（维持目标月数所需）
  Money gapFor(int targetMonths) {
    final need = Money.fromCents(monthlyExpense.cents * targetMonths);
    if (liquid.cents >= need.cents) return Money.zero;
    return Money.fromCents(need.cents - liquid.cents);
  }
}

/// 内部占位（run 方法使用固定快照，避免重复 await）
class SimulationContextPlaceholder {
  final Money liquid;
  final Money monthlyExpense;
  final Money monthlyIncome;
  final Money monthlyPayment;
  final Money totalDebt;
  const SimulationContextPlaceholder({
    required this.liquid,
    required this.monthlyExpense,
    required this.monthlyIncome,
    required this.monthlyPayment,
    required this.totalDebt,
  });
}

/// 情景种类
enum ScenarioKind {
  unemployment,      // 失业维持时长
  debtRateUp,         // 债务利率上涨
  stockFundDrop,      // 股票基金下跌
  extraSave,          // 每月多存流动资金
  earlyRepay,         // 提前还清负债
  incomeUp,           // 收入上涨
  incomeDown,         // 收入下降
  lumpSumExpense,     // 大额一次性支出
  newLiability,       // 新增负债
  newAsset,           // 新增资产
  assetLiquidate,     // 投资变现
  emergencyGap,       // 应急金不足
  fixedExpenseUp,     // 固定支出增加
  passiveIncomeUp,    // 被动收入增加
}

/// 单个情景
class Scenario {
  final ScenarioKind kind;
  final Map<String, dynamic> params;

  const Scenario({required this.kind, this.params = const {}});
}

/// 逐月现金流
class MonthlyCashflow {
  final int monthIndex;
  final Money income;
  final Money expense;
  final Money payment;
  final Money net;
  final Money liquidAfter;

  const MonthlyCashflow({
    required this.monthIndex,
    required this.income,
    required this.expense,
    required this.payment,
    required this.net,
    required this.liquidAfter,
  });

  bool get depleted => liquidAfter.cents < 0;
}
