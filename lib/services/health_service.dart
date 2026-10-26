import '../models/money.dart';
import 'account_service.dart';
import 'transaction_service.dart';
import 'liability_service.dart';

/// 财务健康分析服务。
///
/// 按文档中的核心指标与参考值，输出健康评分与建议。
/// 所有指标均可解释成"大白话"，不向用户暴露专业术语。
class HealthService {
  final AccountService _accountService;
  final TransactionService _txService;
  final LiabilityService _liabilityService;

  HealthService({
    required AccountService accountService,
    required TransactionService txService,
    required LiabilityService liabilityService,
  })  : _accountService = accountService,
        _txService = txService,
        _liabilityService = liabilityService;

  /// 完整健康报告
  Future<HealthReport> report(DateTime month) async {
    final (expense, income) = await _txService.monthlySummary(month);
    final liquid = await _accountService.totalLiquid();
    final debt = await _liabilityService.totalDebt();
    final creditUsed = await _accountService.totalCreditUsed();
    final totalLiabilities = Money.fromCents(debt.cents + creditUsed.cents);

    // 1. 资产负债率
    final accountAssets = await _accountService.totalAssetsFromAccounts();
    final assetTotal = await _assetTotal();
    final totalAssets = Money.fromCents(accountAssets.cents + assetTotal.cents);
    final debtRatio = totalAssets.cents == 0
        ? 0.0
        : totalLiabilities.cents / totalAssets.cents;

    // 2. 债务收入比（月还款/月收入）
    final monthlyPayment = await _liabilityService.monthlyPayment();
    final debtIncomeRatio = income.cents == 0
        ? 0.0
        : monthlyPayment.cents / income.cents;

    // 3. 紧急备用金倍数（流动资金/月必要支出）
    // 简化：用月支出作为必要支出代理
    final emergencyMonths = expense.cents == 0
        ? 0.0
        : liquid.cents / expense.cents;

    // 4. 月度结余率
    final balance = Money.fromCents(income.cents - expense.cents);
    final surplusRate = income.cents == 0 ? 0.0 : balance.cents / income.cents;

    // 5. 资产增长率（需要历史数据，此处简化为净资产趋势）
    // 占位：实际需接入月度快照
    const growthRate = 0.0;

    // 6. 被动收入占比
    // 简化：投资回报类 / 总收入
    const passiveRatio = 0.0;

    // 综合评分（权重）
    final score = _calcScore(
      debtRatio: debtRatio,
      debtIncomeRatio: debtIncomeRatio,
      emergencyMonths: emergencyMonths,
      surplusRate: surplusRate,
    );

    final grade = _gradeOf(score);
    final risks = _detectRisks(
      debtRatio: debtRatio,
      debtIncomeRatio: debtIncomeRatio,
      emergencyMonths: emergencyMonths,
      surplusRate: surplusRate,
    );
    final suggestions = _makeSuggestions(
      debtRatio: debtRatio,
      debtIncomeRatio: debtIncomeRatio,
      emergencyMonths: emergencyMonths,
      surplusRate: surplusRate,
      liquid: liquid,
      expense: expense,
    );

    return HealthReport(
      score: score,
      grade: grade,
      debtRatio: debtRatio,
      debtIncomeRatio: debtIncomeRatio,
      emergencyMonths: emergencyMonths,
      surplusRate: surplusRate,
      growthRate: growthRate,
      passiveRatio: passiveRatio,
      risks: risks,
      suggestions: suggestions,
    );
  }

  /// 资产负债率（暴露给分析页直接展示）
  Future<double> debtRatio() async {
    final accountAssets = await _accountService.totalAssetsFromAccounts();
    final assetTotal = await _assetTotal();
    final totalAssets = Money.fromCents(accountAssets.cents + assetTotal.cents);
    final creditUsed = await _accountService.totalCreditUsed();
    final debt = await _liabilityService.totalDebt();
    final totalLiabilities = Money.fromCents(creditUsed.cents + debt.cents);
    if (totalAssets.cents == 0) return 0.0;
    return totalLiabilities.cents / totalAssets.cents;
  }

  /// 月度结余率
  Future<double> surplusRate(DateTime month) async {
    final (expense, income) = await _txService.monthlySummary(month);
    if (income.cents == 0) return 0.0;
    return (income.cents - expense.cents) / income.cents;
  }

  /// 紧急备用金倍数
  Future<double> emergencyMonths(DateTime month) async {
    final liquid = await _accountService.totalLiquid();
    final (expense, _) = await _txService.monthlySummary(month);
    if (expense.cents == 0) return 0.0;
    return liquid.cents / expense.cents;
  }

  /// 债务收入比
  Future<double> debtIncomeRatio(DateTime month) async {
    final (_, income) = await _txService.monthlySummary(month);
    final monthlyPayment = await _liabilityService.monthlyPayment();
    if (income.cents == 0) return 0.0;
    return monthlyPayment.cents / income.cents;
  }

  // ---------- 内部计算 ----------

  Future<int> _assetTotal() async {
    // 由 SummaryService 统一管理，此处仅做占位
    return 0;
  }

  int _calcScore({
    required double debtRatio,
    required double debtIncomeRatio,
    required double emergencyMonths,
    required double surplusRate,
  }) {
    int score = 100;

    // 资产负债率：>60% 扣40，40-60% 扣25，30-40% 扣10
    if (debtRatio > 0.6) score -= 40;
    else if (debtRatio > 0.4) score -= 25;
    else if (debtRatio > 0.3) score -= 10;

    // 债务收入比：>50% 扣30，30-50% 扣18，>0 扣5
    if (debtIncomeRatio > 0.5) score -= 30;
    else if (debtIncomeRatio > 0.3) score -= 18;
    else if (debtIncomeRatio > 0) score -= 5;

    // 紧急备用金：<1个月 扣25，1-3个月 扣12
    if (emergencyMonths < 1) score -= 25;
    else if (emergencyMonths < 3) score -= 12;

    // 月度结余率：<0% 扣25，0-20% 扣12
    if (surplusRate < 0) score -= 25;
    else if (surplusRate < 0.2) score -= 12;

    return score.clamp(0, 100);
  }

  HealthGrade _gradeOf(int score) {
    if (score >= 85) return HealthGrade.excellent;
    if (score >= 70) return HealthGrade.good;
    if (score >= 55) return HealthGrade.fair;
    if (score >= 40) return HealthGrade.warning;
    return HealthGrade.danger;
  }

  List<String> _detectRisks({
    required double debtRatio,
    required double debtIncomeRatio,
    required double emergencyMonths,
    required double surplusRate,
  }) {
    final risks = <String>[];
    if (debtRatio > 0.6) risks.add('负债占身家的比例过高，已超过六成');
    else if (debtRatio > 0.4) risks.add('负债占比偏高，接近警戒线');
    if (debtIncomeRatio > 0.5) risks.add('每月还款负担过重，超过收入一半');
    if (emergencyMonths < 1) risks.add('手上能随时花的钱不到一个月的开销');
    if (surplusRate < 0) risks.add('本月是入不敷出的状态');
    return risks;
  }

  List<String> _makeSuggestions({
    required double debtRatio,
    required double debtIncomeRatio,
    required double emergencyMonths,
    required double surplusRate,
    required Money liquid,
    required Money expense,
  }) {
    final s = <String>[];
    if (emergencyMonths < 3) {
      final target = Money.fromCents(expense.cents * 3);
      final gap = Money.fromCents((target.cents - liquid.cents).clamp(0, target.cents));
      s.add('建议预留 ${target.format()} 作为应急金，目前还差 ${gap.format()}');
    }
    if (surplusRate < 0.2 && surplusRate >= 0) {
      s.add('本月结余偏紧，可审视弹性支出中可削减的部分');
    }
    if (debtIncomeRatio > 0.3) {
      s.add('考虑优先偿还利率较高的负债，减少利息支出');
    }
    if (surplusRate < 0) {
      s.add('建议梳理本月超支项，先止损再谈储蓄');
    }
    if (s.isEmpty) s.add('当前财务状况健康，继续保持即可');
    return s;
  }
}

/// 健康等级
enum HealthGrade { excellent, good, fair, warning, danger }

extension HealthGradeX on HealthGrade {
  String get label {
    switch (this) {
      case HealthGrade.excellent:
        return '优秀';
      case HealthGrade.good:
        return '良好';
      case HealthGrade.fair:
        return '一般';
      case HealthGrade.warning:
        return '警戒';
      case HealthGrade.danger:
        return '危险';
    }
  }
}

/// 健康报告数据载体
class HealthReport {
  final int score;
  final HealthGrade grade;
  final double debtRatio;
  final double debtIncomeRatio;
  final double emergencyMonths;
  final double surplusRate;
  final double growthRate;
  final double passiveRatio;
  final List<String> risks;
  final List<String> suggestions;

  const HealthReport({
    required this.score,
    required this.grade,
    required this.debtRatio,
    required this.debtIncomeRatio,
    required this.emergencyMonths,
    required this.surplusRate,
    required this.growthRate,
    required this.passiveRatio,
    required this.risks,
    required this.suggestions,
  });
}
