import '../../models/asset.dart';
import '../../models/money.dart';
import '../../services/result.dart';

/// 资产数据访问对象。
///
/// 统一管理普通资产、股票、基金三类资产，以及它们的买卖/出入记录。
/// 与 UI 层完全解耦，只暴露领域模型。
class AssetDao {
  // ---------- 普通资产 ----------

  Future<List<Asset>> listNormal() async {
    await Future<void>.delayed(Duration.zero);
    return seedNormalAssets;
  }

  Future<Asset?> getNormalById(String id) async {
    final list = await listNormal();
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<Result<Asset>> insertNormal(Asset asset) async {
    await Future<void>.delayed(Duration.zero);
    if (asset.name.isEmpty) return const Err('资产名称不能为空');
    if (asset.amount.isNegative) return const Err('资产金额不能为负数');
    return Ok(asset);
  }

  Future<Asset> updateNormal(Asset asset) async {
    await Future<void>.delayed(Duration.zero);
    return asset;
  }

  // ---------- 股票 ----------

  Future<List<StockAsset>> listStocks() async {
    await Future<void>.delayed(Duration.zero);
    return seedStockAssets;
  }

  Future<StockAsset?> getStockById(String id) async {
    final list = await listStocks();
    for (final s in list) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 更新股票价格（手动刷新入口）
  Future<StockAsset> updateStockPrice(String id, double newPrice) async {
    await Future<void>.delayed(Duration.zero);
    final list = await listStocks();
    for (final s in list) {
      if (s.id == id) {
        return StockAsset(
          id: s.id,
          name: s.name,
          code: s.code,
          buyPrice: s.buyPrice,
          buyQuantity: s.buyQuantity,
          currentPrice: newPrice,
          linkedAccountId: s.linkedAccountId,
          createdAt: s.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    return list.first;
  }

  // ---------- 基金 ----------

  Future<List<FundAsset>> listFunds() async {
    await Future<void>.delayed(Duration.zero);
    return seedFundAssets;
  }

  Future<FundAsset?> getFundById(String id) async {
    final list = await listFunds();
    for (final f in list) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// 更新基金净值
  Future<FundAsset> updateFundNav(String id, double newNav) async {
    await Future<void>.delayed(Duration.zero);
    final list = await listFunds();
    for (final f in list) {
      if (f.id == id) {
        return FundAsset(
          id: f.id,
          name: f.name,
          code: f.code,
          confirmNav: f.confirmNav,
          shares: f.shares,
          currentNav: newNav,
          hasLockPeriod: f.hasLockPeriod,
          lockEndDate: f.lockEndDate,
          linkedAccountId: f.linkedAccountId,
          createdAt: f.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    return list.first;
  }

  // ---------- 资产出入记录（买卖/借出收回） ----------

  Future<List<AssetTradeRecord>> tradesByAsset(String assetId) async {
    await Future<void>.delayed(Duration.zero);
    return seedAssetTrades
        .where((t) => t.assetId == assetId)
        .toList()
      ..sort((a, b) => b.tradedAt.compareTo(a.tradedAt));
  }

  Future<Result<AssetTradeRecord>> insertTrade(AssetTradeRecord trade) async {
    await Future<void>.delayed(Duration.zero);
    if (trade.quantity <= 0) return const Err('数量必须大于零');
    if (trade.price < 0) return const Err('价格不能为负数');
    return Ok(trade);
  }
}

/// 种子数据：普通资产
List<Asset> seedNormalAssets = [
  Asset(
    id: 'ast_loan_1',
    name: '借给同事小李',
    subType: AssetSubType.loanToFriend,
    amount: Money.fromDouble(2000),
    linkedAccountId: 'acc_cash_1',
    calcType: AssetCalcType.none,
    countInTotal: true,
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  ),
  Asset(
    id: 'ast_deposit_1',
    name: '定期存款',
    subType: AssetSubType.deposit,
    amount: Money.fromDouble(30000),
    linkedAccountId: 'acc_savings_1',
    calcType: AssetCalcType.byYield,
    annualYieldRate: 0.025,
    countInTotal: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
];

/// 种子数据：股票资产
List<StockAsset> seedStockAssets = [
  StockAsset(
    id: 'ast_stock_1',
    name: '招商银行',
    code: '600036',
    buyPrice: 32.50,
    buyQuantity: 200,
    currentPrice: 35.20,
    linkedAccountId: 'acc_savings_1',
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 10, 20),
  ),
];

/// 种子数据：基金资产
List<FundAsset> seedFundAssets = [
  FundAsset(
    id: 'ast_fund_1',
    name: '沪深300指数基金',
    code: '000961',
    confirmNav: 1.8520,
    shares: 10000,
    currentNav: 1.9200,
    hasLockPeriod: false,
    linkedAccountId: 'acc_savings_1',
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 10, 20),
  ),
];

/// 种子数据：资产出入记录
List<AssetTradeRecord> seedAssetTrades = [
  // 股票买入
  AssetTradeRecord(
    id: 'tr_stock_1',
    assetId: 'ast_stock_1',
    kind: TradeKind.buy,
    tradedAt: DateTime(2026, 6, 1, 10, 30),
    price: 32.50,
    quantity: 200,
    amount: Money.fromDouble(6500),
    remark: '首次买入',
    createdAt: DateTime(2026, 6, 1),
  ),
  // 股票卖出（部分）
  AssetTradeRecord(
    id: 'tr_stock_2',
    assetId: 'ast_stock_1',
    kind: TradeKind.sell,
    tradedAt: DateTime(2026, 9, 15, 14, 0),
    price: 34.80,
    quantity: 100,
    amount: Money.fromDouble(3480),
    remark: '高位减仓',
    createdAt: DateTime(2026, 9, 15),
  ),
  // 基金买入
  AssetTradeRecord(
    id: 'tr_fund_1',
    assetId: 'ast_fund_1',
    kind: TradeKind.buy,
    tradedAt: DateTime(2026, 4, 1, 10, 0),
    price: 1.8520,
    quantity: 10000,
    amount: Money.fromDouble(18520),
    remark: '定投起投',
    createdAt: DateTime(2026, 4, 1),
  ),
  // 基金买入（追加）
  AssetTradeRecord(
    id: 'tr_fund_2',
    assetId: 'ast_fund_1',
    kind: TradeKind.buy,
    tradedAt: DateTime(2026, 7, 1, 10, 0),
    price: 1.7800,
    quantity: 5000,
    amount: Money.fromDouble(8900),
    remark: '低位补仓',
    createdAt: DateTime(2026, 7, 1),
  ),
  // 借出
  AssetTradeRecord(
    id: 'tr_loan_1',
    assetId: 'ast_loan_1',
    kind: TradeKind.buy,
    tradedAt: DateTime(2026, 3, 1, 15, 0),
    price: 1,
    quantity: 2000,
    amount: Money.fromDouble(2000),
    remark: '借给同事小李应急',
    createdAt: DateTime(2026, 3, 1),
  ),
];
