import 'money.dart';

/// 资产细分类型
enum AssetSubType {
  deposit('deposit', '储蓄'),
  interest('interest', '利息'),
  rent('rent', '租金'),
  copyright('copyright', '版权'),
  socialSecurity('social_security', '社保'),
  housingFund('housing_fund', '公积金'),
  loanToFriend('loan_to_friend', '亲友借出'),
  other('other', '其他'),
}

/// 资产计算类型
enum AssetCalcType { none, byAmount, byYield }

/// 资产（普通）
class Asset {
  final String id;
  final String name;
  final AssetSubType subType;
  final Money amount;
  final String? linkedAccountId;
  final AssetCalcType calcType;
  final double annualYieldRate; // 0~1
  final bool countInTotal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const Asset({
    required this.id,
    required this.name,
    required this.subType,
    required this.amount,
    this.linkedAccountId,
    this.calcType = AssetCalcType.none,
    this.annualYieldRate = 0,
    this.countInTotal = true,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  /// 预期年收益
  Money get expectedAnnualIncome {
    if (calcType != AssetCalcType.byYield) return Money.zero;
    return Money.fromCents((amount.cents * annualYieldRate).round());
  }
}

/// 股票资产
class StockAsset {
  final String id;
  final String name;
  final String code;
  final double buyPrice;   // 每股成本
  final int buyQuantity;    // 股数
  final double currentPrice;
  final String? linkedAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const StockAsset({
    required this.id,
    required this.name,
    required this.code,
    required this.buyPrice,
    required this.buyQuantity,
    this.currentPrice = 0,
    this.linkedAccountId,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  /// 持仓市值
  double get marketValue => currentPrice * buyQuantity;

  /// 买入总价
  double get cost => buyPrice * buyQuantity;

  /// 盈亏金额
  double get profitLoss => marketValue - cost;

  /// 盈亏比例
  double get profitLossRatio => cost == 0 ? 0 : profitLoss / cost;
}

/// 基金资产
class FundAsset {
  final String id;
  final String name;
  final String code;
  final double confirmNav;   // 买入确认净值
  final double shares;       // 持有份额
  final double currentNav;
  final bool hasLockPeriod;
  final DateTime? lockEndDate;
  final String? linkedAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const FundAsset({
    required this.id,
    required this.name,
    required this.code,
    required this.confirmNav,
    required this.shares,
    this.currentNav = 0,
    this.hasLockPeriod = false,
    this.lockEndDate,
    this.linkedAccountId,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  double get marketValue => currentNav * shares;
}

/// 股票/基金的买卖记录（资产出入记录）
class AssetTradeRecord {
  final String id;
  final String assetId;
  final TradeKind kind; // 买入/卖出
  final DateTime tradedAt;
  final double price;
  final double quantity; // 份额
  final Money amount;
  final String? remark;
  final DateTime createdAt;

  const AssetTradeRecord({
    required this.id,
    required this.assetId,
    required this.kind,
    required this.tradedAt,
    required this.price,
    required this.quantity,
    required this.amount,
    this.remark,
    required this.createdAt,
  });
}

enum TradeKind { buy, sell }
