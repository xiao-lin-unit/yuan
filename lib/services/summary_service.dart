import '../models/account.dart';
import '../models/money.dart';
import 'account_service.dart';
import 'asset_service.dart';
import 'liability_service.dart';
import 'transaction_service.dart';

/// 汇总统计服务。
///
/// 将账户、资产、负债、收支四个维度汇总成"账本总览"，
/// 供账户模块首页和分析模块使用。
class SummaryService {
  final AccountService _accountService;
  final AssetService _assetService;
  final LiabilityService _liabilityService;
  final TransactionService _txService;

  SummaryService({
    required AccountService accountService,
    required AssetService assetService,
    required LiabilityService liabilityService,
    required TransactionService txService,
  })  : _accountService = accountService,
        _assetService = assetService,
        _liabilityService = liabilityService,
        _txService = txService;

  /// 账本总览数据。
  /// 口径：
  /// - 总资产 = 账户侧资产（流动资金+计入总资产的其他账户）+ 资产总额
  /// - 总负债 = 信用卡已用额度 + 负债剩余本金
  /// - 净资产 = 总资产 - 总负债
  Future<BookOverview> overview() async {
    final accountAssets = await _accountService.totalAssetsFromAccounts();
    final assetAssets = await _assetService.totalAssets();
    final totalAssets = Money.fromCents(accountAssets.cents + assetAssets.cents);

    final creditUsed = await _accountService.totalCreditUsed();
    final debt = await _liabilityService.totalDebt();
    final totalLiabilities = Money.fromCents(creditUsed.cents + debt.cents);

    final netWorth = Money.fromCents(totalAssets.cents - totalLiabilities.cents);

    final liquid = await _accountService.totalLiquid();

    final now = DateTime.now();
    final (expense, income) = await _txService.monthlySummary(now);
    final balance = Money.fromCents(income.cents - expense.cents);

    return BookOverview(
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: netWorth,
      liquid: liquid,
      monthlyIncome: income,
      monthlyExpense: expense,
      monthlyBalance: balance,
    );
  }

  /// 分类支出占比（用于分析页饼图数据）
  Future<List<(String name, String icon, Money amount, double ratio)>> expenseBreakdown(
    DateTime month,
  ) async {
    final list = await _txService.expenseByCategory(month);
    return [
      for (final item in list)
        (item.$1.name, item.$1.icon ?? '', item.$2, item.$3)
    ];
  }

  /// 月度结余（用于分析页结余卡片）
  Future<(Money income, Money expense, Money balance)> monthlyCashflow(
    DateTime month,
  ) =>
      _txService.monthlySummary(month);
}

/// 账本总览数据载体
class BookOverview {
  final Money totalAssets;
  final Money totalLiabilities;
  final Money netWorth;
  final Money liquid;
  final Money monthlyIncome;
  final Money monthlyExpense;
  final Money monthlyBalance;

  const BookOverview({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.liquid,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlyBalance,
  });
}
