import 'account_service.dart';
import 'asset_service.dart';
import 'liability_service.dart';
import 'transaction_service.dart';
import 'summary_service.dart';
import 'health_service.dart';
import 'simulation_service.dart';

/// 领域服务门面。
///
/// 全局唯一入口，统一持有并暴露所有业务服务实例，
/// 避免 UI 层各自 new 服务导致状态分散。
///
/// 使用方式：
/// ```dart
/// final services = Services.instance;
/// final overview = await services.summary.overview();
/// ```
class Services {
  Services._()
      : account = AccountService(),
        asset = AssetService(),
        liability = LiabilityService(),
        transaction = TransactionService(),
        summary = SummaryService(
          accountService: AccountService(),
          assetService: AssetService(),
          liabilityService: LiabilityService(),
          txService: TransactionService(),
        ),
        health = HealthService(
          accountService: AccountService(),
          txService: TransactionService(),
          liabilityService: LiabilityService(),
        ),
        simulation = SimulationService(
          accountService: AccountService(),
          liabilityService: LiabilityService(),
          txService: TransactionService(),
        );

  /// 单例
  static final Services instance = Services._();

  /// 账户服务
  final AccountService account;

  /// 资产服务
  final AssetService asset;

  /// 负债服务
  final LiabilityService liability;

  /// 收支服务
  final TransactionService transaction;

  /// 汇总统计服务
  final SummaryService summary;

  /// 健康分析服务
  final HealthService health;

  /// 情景推演服务
  final SimulationService simulation;
}
