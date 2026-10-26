import '../models/asset.dart';
import '../models/money.dart';
import 'dao/asset_dao.dart';
import 'result.dart';

/// 资产业务服务。
///
/// 封装资产模块的增删改查、价格刷新、出入记录（买卖/借出收回）。
class AssetService {
  final AssetDao _dao;

  AssetService({AssetDao? dao}) : _dao = dao ?? AssetDao();

  /// 全部普通资产
  Future<List<Asset>> normalAssets() => _dao.listNormal();

  /// 全部股票
  Future<List<StockAsset>> stocks() => _dao.listStocks();

  /// 全部基金
  Future<List<FundAsset>> funds() => _dao.listFunds();

  /// 全部资产（合并三类）
  Future<(List<Asset>, List<StockAsset>, List<FundAsset>)> all() async {
    final n = await _dao.listNormal();
    final s = await _dao.listStocks();
    final f = await _dao.listFunds();
    return (n, s, f);
  }

  /// 资产总额（计入总资产的）
  Future<Money> totalAssets() async {
    int cents = 0;
    for (final a in await _dao.listNormal()) {
      if (a.countInTotal) cents += a.amount.cents;
    }
    for (final s in await _dao.listStocks()) {
      cents += (s.marketValue * 100).round();
    }
    for (final f in await _dao.listFunds()) {
      cents += (f.marketValue * 100).round();
    }
    return Money.fromCents(cents);
  }

  /// 资产条数
  Future<int> count() async {
    final n = await _dao.listNormal();
    final s = await _dao.listStocks();
    final f = await _dao.listFunds();
    return n.length + s.length + f.length;
  }

  /// 新增普通资产
  Future<Result<Asset>> addNormal(Asset asset) => _dao.insertNormal(asset);

  /// 更新普通资产
  Future<Asset> updateNormal(Asset asset) => _dao.updateNormal(asset);

  /// 刷新股票价格
  Future<StockAsset> refreshStockPrice(String id, double newPrice) =>
      _dao.updateStockPrice(id, newPrice);

  /// 刷新基金净值
  Future<FundAsset> refreshFundNav(String id, double newNav) =>
      _dao.updateFundNav(id, newNav);

  /// 某资产的出入记录
  Future<List<AssetTradeRecord>> trades(String assetId) =>
      _dao.tradesByAsset(assetId);

  /// 记录股票买入
  Future<Result<AssetTradeRecord>> recordStockBuy({
    required String assetId,
    required double price,
    required double quantity,
    String? remark,
  }) {
    final trade = AssetTradeRecord(
      id: 'tr_${DateTime.now().microsecondsSinceEpoch}',
      assetId: assetId,
      kind: TradeKind.buy,
      tradedAt: DateTime.now(),
      price: price,
      quantity: quantity,
      amount: Money.fromCents((price * quantity * 100).round()),
      remark: remark,
      createdAt: DateTime.now(),
    );
    return _dao.insertTrade(trade);
  }

  /// 记录股票卖出
  Future<Result<AssetTradeRecord>> recordStockSell({
    required String assetId,
    required double price,
    required double quantity,
    String? remark,
  }) {
    final trade = AssetTradeRecord(
      id: 'tr_${DateTime.now().microsecondsSinceEpoch}',
      assetId: assetId,
      kind: TradeKind.sell,
      tradedAt: DateTime.now(),
      price: price,
      quantity: quantity,
      amount: Money.fromCents((price * quantity * 100).round()),
      remark: remark,
      createdAt: DateTime.now(),
    );
    return _dao.insertTrade(trade);
  }

  /// 记录基金买入
  Future<Result<AssetTradeRecord>> recordFundBuy({
    required String assetId,
    required double nav,
    required double shares,
    String? remark,
  }) {
    final trade = AssetTradeRecord(
      id: 'tr_${DateTime.now().microsecondsSinceEpoch}',
      assetId: assetId,
      kind: TradeKind.buy,
      tradedAt: DateTime.now(),
      price: nav,
      quantity: shares,
      amount: Money.fromCents((nav * shares * 100).round()),
      remark: remark,
      createdAt: DateTime.now(),
    );
    return _dao.insertTrade(trade);
  }

  /// 记录基金卖出
  Future<Result<AssetTradeRecord>> recordFundSell({
    required String assetId,
    required double nav,
    required double shares,
    String? remark,
  }) {
    final trade = AssetTradeRecord(
      id: 'tr_${DateTime.now().microsecondsSinceEpoch}',
      assetId: assetId,
      kind: TradeKind.sell,
      tradedAt: DateTime.now(),
      price: nav,
      quantity: shares,
      amount: Money.fromCents((nav * shares * 100).round()),
      remark: remark,
      createdAt: DateTime.now(),
    );
    return _dao.insertTrade(trade);
  }

  /// 记录亲友借款借出
  Future<Result<AssetTradeRecord>> recordLoanOut({
    required String assetId,
    required Money amount,
    String? remark,
  }) {
    final trade = AssetTradeRecord(
      id: 'tr_${DateTime.now().microsecondsSinceEpoch}',
      assetId: assetId,
      kind: TradeKind.buy,
      tradedAt: DateTime.now(),
      price: 1,
      quantity: amount.yuan,
      amount: amount,
      remark: remark,
      createdAt: DateTime.now(),
    );
    return _dao.insertTrade(trade);
  }

  /// 记录亲友借款收回
  Future<Result<AssetTradeRecord>> recordLoanIn({
    required String assetId,
    required Money amount,
    String? remark,
  }) {
    final trade = AssetTradeRecord(
      id: 'tr_${DateTime.now().microsecondsSinceEpoch}',
      assetId: assetId,
      kind: TradeKind.sell,
      tradedAt: DateTime.now(),
      price: 1,
      quantity: amount.yuan,
      amount: amount,
      remark: remark,
      createdAt: DateTime.now(),
    );
    return _dao.insertTrade(trade);
  }
}
