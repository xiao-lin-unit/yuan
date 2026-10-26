/// 账户分类
enum AccountCategory { liquid, credit, other }

/// 账户类型
enum AccountType {
  savings('savings', '储蓄卡'),
  cash('cash', '现金'),
  wechat('wechat', '微信'),
  alipay('alipay', '支付宝'),
  creditCard('credit_card', '信用卡'),
  socialSecurity('social_security', '社保'),
  housingFund('housing_fund', '公积金'),
  giftCard('gift_card', '礼品卡'),
  other('other', '其他');

  final String code;
  final String label;
  const AccountType(this.code, this.label);
}

/// 账户。支持三类账户 + 受限账户绑定支出分类。
class Account {
  final String id;
  final String name;
  final AccountType type;
  final AccountCategory category;

  /// 余额（信用卡指可用额度场景不适用，用 usedLimit）
  final double balance;

  /// 信用卡总额度
  final double totalLimit;

  /// 信用卡已用额度
  final double usedLimit;

  /// 账单日（每月几号）
  final int? billDay;

  /// 还款日
  final int? paymentDay;

  /// 是否流动资金。信用卡固定 true；社保公积金固定 false 且不可改
  final bool isLiquid;

  /// 是否计入总资产
  final bool countInTotal;

  /// 关联还款账户 id（信用卡用）
  final String? linkedAccountId;

  /// 受限账户可绑定的支出分类 id 集合。
  /// 如公积金可绑定 ["housing","utilities"] 等装修/租房相关分类。
  /// 为空且 isLiquid=false 时视为所有非必要消费受限。
  final Set<String> allowedExpenseCategoryIds;

  final String? remark;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    this.balance = 0,
    this.totalLimit = 0,
    this.usedLimit = 0,
    this.billDay,
    this.paymentDay,
    required this.isLiquid,
    this.countInTotal = true,
    this.linkedAccountId,
    this.allowedExpenseCategoryIds = const {},
    this.remark,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 信用卡可用额度
  double get availableLimit => (totalLimit - usedLimit).clamp(0, double.maxFinite);

  /// 是否为受限账户（非流动资金且不可手动改）
  bool get isRestricted => !isLiquid;

  Account copyWith({
    String? name,
    double? balance,
    double? usedLimit,
    bool? countInTotal,
    Set<String>? allowedExpenseCategoryIds,
    String? remark,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        type: type,
        category: category,
        balance: balance ?? this.balance,
        totalLimit: totalLimit,
        usedLimit: usedLimit ?? this.usedLimit,
        billDay: billDay,
        paymentDay: paymentDay,
        isLiquid: isLiquid,
        countInTotal: countInTotal ?? this.countInTotal,
        linkedAccountId: linkedAccountId,
        allowedExpenseCategoryIds:
            allowedExpenseCategoryIds ?? this.allowedExpenseCategoryIds,
        remark: remark ?? this.remark,
        deleted: deleted,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
