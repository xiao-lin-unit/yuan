import 'package:flutter/foundation.dart';

/// 资债模块的数据契约：枚举 + 不可变记录类。
///
/// 【静态优先】本文件只有常量、枚举、纯数据转换，没有状态、没有通知、
/// 没有跨帧回调。所有「算」的逻辑在 az_math.dart，所有「存」的逻辑在
/// az_dao.dart，三者互不串职责。
///
/// 【界面文案】设计文档 2.1 / 附二要求界面永不出现专业词，所以枚举的
/// [label] 一律是白话：「借出去、还没收回来的钱」而不是「应收款」，
/// 「这笔钱实际一年要付多少」而不是「年化综合成本」。
/// 原型 tab 上的「资产 / 负债」是模块名，保留；解释句全部用白话。

int _int(Object? v, [int fallback = 0]) =>
    v == null ? fallback : (v as num).toInt();
double _dbl(Object? v, [double fallback = 0]) =>
    v == null ? fallback : (v as num).toDouble();
int? _intOrNull(Object? v) => v == null ? null : (v as num).toInt();
double? _dblOrNull(Object? v) => v == null ? null : (v as num).toDouble();
String _str(Object? v, [String fallback = '']) =>
    v == null ? fallback : v as String;
DateTime? _dateOrNull(Object? v) => v == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
DateTime _date(Object? v) => v == null
    ? DateTime.fromMillisecondsSinceEpoch(0)
    : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

/// 资产大类（6.2，A1/A2 是账户只读镜像，不在这里）。
/// 只列「资产模块登记」的 A3~A11；[iconKey] 由 UI 层查表解析成 IconData，
/// 数据库只存语义 key，不存字体码点 / emoji / 颜色。
enum AssetClass {
  loan('A3', '借出去、还没收回来的钱', 'finance'),
  stock('A4', '股票', 'investment'),
  fund('A5', '基金', 'investment'),
  otherInvest('A6', '别的投资', 'investment'),
  property('A7', '房子、车位、商铺', 'housing'),
  vehicle('A8', '车和交通工具', 'car'),
  valuable('A9', '值钱的物件', 'gift'),
  business('A10', '生意和股份', 'finance'),
  misc('A11', '其他', 'other');

  const AssetClass(this.code, this.label, this.iconKey);
  final String code;
  final String label;
  final String iconKey;

  static AssetClass fromDb(String? v) => switch (v) {
        'A4' => stock,
        'A5' => fund,
        'A6' => otherInvest,
        'A7' => property,
        'A8' => vehicle,
        'A9' => valuable,
        'A10' => business,
        'A11' => misc,
        _ => loan,
      };
}

/// 「多久能变成现金」（6.3 / 6.8 / 13.6）。0..4 与原型 az.js 一致。
enum Liquidity {
  now(0, '随时能拿出来'),
  days(1, '几天能凑出来'),
  months(2, '几个月才卖得掉'),
  hard(3, '很难变成现金'),
  stuck(4, '动不了');

  const Liquidity(this.dbValue, this.label);
  final int dbValue;
  final String label;

  static Liquidity fromDb(Object? v) => switch (_int(v, 2)) {
        0 => now,
        1 => days,
        3 => hard,
        4 => stuck,
        _ => months,
      };
}

/// 「这笔进账稳不稳」（6.3 / 13.2）。只有 fixed 进「不上班也能撑住」。
enum AzStability {
  unset('unset', '说不准'),
  fixed('fixed', '每月都有'),
  occasional('occasional', '偶尔才有');

  const AzStability(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static AzStability fromDb(Object? v) => switch (_str(v, 'unset')) {
        'fixed' => fixed,
        'occasional' => occasional,
        _ => unset,
      };
}

/// 估值口径（6.4）。cost = 保守按买入价；latest = 按用户填的最新价。
enum ValuationMode {
  cost('cost', '按买入价'),
  latest('latest', '按我填的最新价');

  const ValuationMode(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static ValuationMode fromDb(Object? v) =>
      v == 'latest' ? latest : cost;
}

/// 值怎么来的（6.4 切换留痕）。
enum ValuationSource {
  cost('cost', '按买入时算，没算涨跌'),
  trade('trade', '按上次买卖价'),
  manual('manual', '你自己填的价');

  const ValuationSource(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static ValuationSource fromDb(Object? v) => switch (_str(v, 'cost')) {
        'trade' => trade,
        'manual' => manual,
        _ => cost,
      };
}

/// 负债类型（7.2 保留，只选一次）。
enum LiabilityType {
  mortgage('mortgage', '房贷', 'housing'),
  carLoan('car_loan', '车贷', 'car'),
  creditCard('credit_card', '信用卡', 'accountCreditCard'),
  consumer('consumer', '消费贷', 'finance'),
  renovation('renovation', '装修贷', 'homeImprovement'),
  student('student', '助学贷', 'study'),
  online('online', '网贷', 'finance'),
  installment('installment', '电商分期', 'basket'),
  rentInstallment('rent_installment', '租金分期', 'rent'),
  personal('personal', '借的亲友钱', 'gift'),
  other('other', '其他', 'other');

  const LiabilityType(this.dbValue, this.label, this.iconKey);
  final String dbValue;
  final String label;
  final String iconKey;

  static LiabilityType fromDb(Object? v) => switch (_str(v, 'other')) {
        'mortgage' => mortgage,
        'car_loan' => carLoan,
        'credit_card' => creditCard,
        'consumer' => consumer,
        'renovation' => renovation,
        'student' => student,
        'online' => online,
        'installment' => installment,
        'rent_installment' => rentInstallment,
        'personal' => personal,
        _ => other,
      };
}

/// 「这钱借来干了什么」（7.2 T1~T7，按用途而不是产品名分类）。
enum DebtPurpose {
  t1('T1', '买房买地'),
  t2('T2', '买车'),
  t3('T3', '做生意 / 买了能生钱的东西'),
  t4('T4', '先花了再还'),
  t5('T5', '应急借的'),
  t6('T6', '替别人担的'),
  t7('T7', '亲友之间');

  const DebtPurpose(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static DebtPurpose fromDb(Object? v) => switch (_str(v, 'T4')) {
        'T1' => t1,
        'T2' => t2,
        'T3' => t3,
        'T5' => t5,
        'T6' => t6,
        'T7' => t7,
        _ => t4,
      };
}

/// 利率会不会变（7.6）。「利率涨了」只作用于 float。
enum RateType {
  fixed('fixed', '一直不变'),
  float('float', '会跟着变'),
  given('given', '以账单上写的为准');

  const RateType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static RateType fromDb(Object? v) => switch (_str(v, 'fixed')) {
        'float' => float,
        'given' => given,
        _ => fixed,
      };
}

/// 怎么还（7.3），各带一句白话解释。
enum RepayMethod {
  equalPayment('equal_payment', '等额本息', '每期还一样的钱'),
  equalPrincipal('equal_principal', '等额本金', '每期还的本金一样，越还越少'),
  revolving('revolving', '随借随还', '有钱就还，没还的按天算'),
  interestFirst('interest_first', '先息后本', '先只还利息，到期一次还本金');

  const RepayMethod(this.dbValue, this.label, this.hint);
  final String dbValue;
  final String label;
  final String hint;

  static RepayMethod fromDb(Object? v) => switch (_str(v, 'equal_payment')) {
        'equal_principal' => equalPrincipal,
        'revolving' => revolving,
        'interest_first' => interestFirst,
        _ => equalPayment,
      };
}

enum LiabilityStatus {
  normal('normal', '正常'),
  overdue('overdue', '逾期'),
  restructured('restructured', '已重组'),
  settled('settled', '已结清');

  const LiabilityStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static LiabilityStatus fromDb(Object? v) => switch (_str(v, 'normal')) {
        'overdue' => overdue,
        'restructured' => restructured,
        'settled' => settled,
        _ => normal,
      };
}

/// 偿债比例三档（7.9），用户可切，切了留痕。
enum DebtRatioLevel {
  loose('loose', '宽松', 0.50),
  std('std', '标准', 0.40),
  strict('strict', '保守', 0.30);

  const DebtRatioLevel(this.dbValue, this.label, this.limit);
  final String dbValue;
  final String label;
  final double limit;

  static DebtRatioLevel fromDb(Object? v) => switch (_str(v, 'std')) {
        'loose' => loose,
        'strict' => strict,
        _ => std,
      };
}

enum PlanStatus {
  pending('pending', '待还'),
  partial('partial', '部分已还'),
  paid('paid', '已还'),
  overdue('overdue', '逾期'),
  restructured('restructured', '已重组'),
  settled('settled', '已结清');

  const PlanStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PlanStatus fromDb(Object? v) => switch (_str(v, 'pending')) {
        'partial' => partial,
        'paid' => paid,
        'overdue' => overdue,
        'restructured' => restructured,
        'settled' => settled,
        _ => pending,
      };
}

enum ContingentKind {
  contingent('contingent', '万一要我还的钱'),
  insured('insured', '万一出事，有人替我付吗');

  const ContingentKind(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static ContingentKind fromDb(Object? v) =>
      v == 'insured' ? insured : contingent;
}

enum TradeDirection {
  buy('buy', '买入'),
  sell('sell', '卖出');

  const TradeDirection(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static TradeDirection fromDb(Object? v) => v == 'sell' ? sell : buy;
}

/// 一张自登记资产（6.3 全部共用字段都在这一行）。
@immutable
class AssetRecord {
  const AssetRecord({
    this.id,
    this.bookId = 'default',
    required this.assetClass,
    required this.name,
    this.code = '',
    this.iconKey = 'other',
    required this.cost,
    this.latestValue,
    this.valuedAt,
    this.valuationSource = ValuationSource.cost,
    this.liquidity = Liquidity.months,
    this.stability = AzStability.unset,
    this.monthlyIn = 0,
    this.monthlyOut = 0,
    this.exitCost = 0,
    this.counted = true,
    this.countedReason = '',
    this.intention = '',
    this.note = '',
    this.linkDebtId,
    this.linkAccountId,
    this.quantity,
    this.unitPrice,
    this.useMode = '',
    this.depreciationNote = '',
    this.sortOrder = 0,
    this.archived = false,
    this.deletedAt,
    this.deleteReason,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
  });

  final int? id;
  final String bookId;
  final AssetClass assetClass;
  final String name;
  final String code;
  final String iconKey;
  final double cost;
  final double? latestValue;
  final DateTime? valuedAt;
  final ValuationSource valuationSource;
  final Liquidity liquidity;
  final AzStability stability;
  final double monthlyIn;
  final double monthlyOut;
  final double exitCost;
  final bool counted;
  final String countedReason;
  final String intention;
  final String note;
  final int? linkDebtId;
  final int? linkAccountId;
  final double? quantity;
  final double? unitPrice;
  final String useMode;
  final String depreciationNote;
  final int sortOrder;
  final bool archived;
  final DateTime? deletedAt;
  final String? deleteReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  bool get isDeleted => deletedAt != null;

  factory AssetRecord.fromMap(Map<String, Object?> m) => AssetRecord(
        id: _intOrNull(m['id']),
        bookId: _str(m['book_id'], 'default'),
        assetClass: AssetClass.fromDb(_str(m['asset_class'], 'A3')),
        name: _str(m['name']),
        code: _str(m['code']),
        iconKey: _str(m['icon_key'], 'other'),
        cost: _dbl(m['cost']),
        latestValue: _dblOrNull(m['latest_value']),
        valuedAt: _dateOrNull(m['valued_at']),
        valuationSource: ValuationSource.fromDb(m['valuation_source']),
        liquidity: Liquidity.fromDb(m['liquidity']),
        stability: AzStability.fromDb(m['stability']),
        monthlyIn: _dbl(m['monthly_in']),
        monthlyOut: _dbl(m['monthly_out']),
        exitCost: _dbl(m['exit_cost']),
        counted: _int(m['counted'], 1) == 1,
        countedReason: _str(m['counted_reason']),
        intention: _str(m['intention']),
        note: _str(m['note']),
        linkDebtId: _intOrNull(m['link_debt_id']),
        linkAccountId: _intOrNull(m['link_account_id']),
        quantity: _dblOrNull(m['quantity']),
        unitPrice: _dblOrNull(m['unit_price']),
        useMode: _str(m['use_mode']),
        depreciationNote: _str(m['depreciation_note']),
        sortOrder: _int(m['sort_order']),
        archived: _int(m['archived']) == 1,
        deletedAt: _dateOrNull(m['deleted_at']),
        deleteReason: m['delete_reason'] as String?,
        createdAt: _date(m['created_at']),
        updatedAt: _date(m['updated_at']),
        revision: _int(m['revision'], 1),
      );

  /// 不含 id：insert 直接用；update 由 DAO 带 where。
  Map<String, Object?> toMap() => <String, Object?>{
        'book_id': bookId,
        'asset_class': assetClass.code,
        'name': name,
        'code': code,
        'icon_key': iconKey,
        'cost': cost,
        'latest_value': latestValue,
        'valued_at': valuedAt?.millisecondsSinceEpoch,
        'valuation_source': valuationSource.dbValue,
        'liquidity': liquidity.dbValue,
        'stability': stability.dbValue,
        'monthly_in': monthlyIn,
        'monthly_out': monthlyOut,
        'exit_cost': exitCost,
        'counted': counted ? 1 : 0,
        'counted_reason': countedReason,
        'intention': intention,
        'note': note,
        'link_debt_id': linkDebtId,
        'link_account_id': linkAccountId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'use_mode': useMode,
        'depreciation_note': depreciationNote,
        'sort_order': sortOrder,
        'archived': archived ? 1 : 0,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'delete_reason': deleteReason,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'revision': revision,
      };
}

/// 一笔欠款。
@immutable
class LiabilityRecord {
  const LiabilityRecord({
    this.id,
    this.bookId = 'default',
    required this.type,
    this.iconKey = 'other',
    required this.name,
    this.purpose = DebtPurpose.t4,
    this.originalPrincipal = 0,
    required this.principal,
    this.interestOn = true,
    this.rate = 0,
    this.rateType = RateType.fixed,
    this.nominalRate,
    this.monthlyFee = 0,
    this.feeNote = '',
    this.repayMethod = RepayMethod.equalPayment,
    this.payDay,
    this.startDate,
    this.endDate,
    this.paidTerms = 0,
    this.totalTerms = 0,
    this.monthlyPay = 0,
    this.monthlyPrincipal = 0,
    this.monthlyInterest = 0,
    this.linkAssetId,
    this.linkAccountId,
    this.accountId,
    this.status = LiabilityStatus.normal,
    this.prepayPenaltyRate = 0,
    this.rateResetDate,
    this.rateBasisPoints = 0,
    this.promoUntil,
    this.note = '',
    this.activePlanVersion = 1,
    this.sortOrder = 0,
    this.archived = false,
    this.deletedAt,
    this.deleteReason,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
  });

  final int? id;
  final String bookId;
  final LiabilityType type;
  final String iconKey;
  final String name;
  final DebtPurpose purpose;
  final double originalPrincipal;
  final double principal;
  final bool interestOn;
  final double rate;
  final RateType rateType;
  final double? nominalRate;
  final double monthlyFee;
  final String feeNote;
  final RepayMethod repayMethod;
  final int? payDay;
  final DateTime? startDate;
  final DateTime? endDate;
  final int paidTerms;
  final int totalTerms;
  final double monthlyPay;
  final double monthlyPrincipal;
  final double monthlyInterest;
  final int? linkAssetId;
  final int? linkAccountId;
  final int? accountId;
  final LiabilityStatus status;
  final double prepayPenaltyRate;
  final DateTime? rateResetDate;
  final double rateBasisPoints;
  final DateTime? promoUntil;
  final String note;
  final int activePlanVersion;
  final int sortOrder;
  final bool archived;
  final DateTime? deletedAt;
  final String? deleteReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  bool get isDeleted => deletedAt != null;

  /// 这一期里「真给银行的」= 利息 + 手续费，本金只是从左口袋换到右口袋。
  double get monthlyCost => monthlyInterest + monthlyFee;
  int get leftTerms => totalTerms - paidTerms < 0 ? 0 : totalTerms - paidTerms;

  factory LiabilityRecord.fromMap(Map<String, Object?> m) => LiabilityRecord(
        id: _intOrNull(m['id']),
        bookId: _str(m['book_id'], 'default'),
        type: LiabilityType.fromDb(m['liability_type']),
        iconKey: _str(m['icon_key'], 'other'),
        name: _str(m['name']),
        purpose: DebtPurpose.fromDb(m['purpose']),
        originalPrincipal: _dbl(m['original_principal']),
        principal: _dbl(m['principal']),
        interestOn: _int(m['interest_on'], 1) == 1,
        rate: _dbl(m['rate']),
        rateType: RateType.fromDb(m['rate_type']),
        nominalRate: _dblOrNull(m['nominal_rate']),
        monthlyFee: _dbl(m['monthly_fee']),
        feeNote: _str(m['fee_note']),
        repayMethod: RepayMethod.fromDb(m['repay_method']),
        payDay: _intOrNull(m['pay_day']),
        startDate: _dateOrNull(m['start_date']),
        endDate: _dateOrNull(m['end_date']),
        paidTerms: _int(m['paid_terms']),
        totalTerms: _int(m['total_terms']),
        monthlyPay: _dbl(m['monthly_pay']),
        monthlyPrincipal: _dbl(m['monthly_principal']),
        monthlyInterest: _dbl(m['monthly_interest']),
        linkAssetId: _intOrNull(m['link_asset_id']),
        linkAccountId: _intOrNull(m['link_account_id']),
        accountId: _intOrNull(m['account_id']),
        status: LiabilityStatus.fromDb(m['status']),
        prepayPenaltyRate: _dbl(m['prepay_penalty_rate']),
        rateResetDate: _dateOrNull(m['rate_reset_date']),
        rateBasisPoints: _dbl(m['rate_basis_points']),
        promoUntil: _dateOrNull(m['promo_until']),
        note: _str(m['note']),
        activePlanVersion: _int(m['active_plan_version'], 1),
        sortOrder: _int(m['sort_order']),
        archived: _int(m['archived']) == 1,
        deletedAt: _dateOrNull(m['deleted_at']),
        deleteReason: m['delete_reason'] as String?,
        createdAt: _date(m['created_at']),
        updatedAt: _date(m['updated_at']),
        revision: _int(m['revision'], 1),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'book_id': bookId,
        'liability_type': type.dbValue,
        'icon_key': iconKey,
        'name': name,
        'purpose': purpose.dbValue,
        'original_principal': originalPrincipal,
        'principal': principal,
        'interest_on': interestOn ? 1 : 0,
        'rate': rate,
        'rate_type': rateType.dbValue,
        'nominal_rate': nominalRate,
        'monthly_fee': monthlyFee,
        'fee_note': feeNote,
        'repay_method': repayMethod.dbValue,
        'pay_day': payDay,
        'start_date': startDate?.millisecondsSinceEpoch,
        'end_date': endDate?.millisecondsSinceEpoch,
        'paid_terms': paidTerms,
        'total_terms': totalTerms,
        'monthly_pay': monthlyPay,
        'monthly_principal': monthlyPrincipal,
        'monthly_interest': monthlyInterest,
        'link_asset_id': linkAssetId,
        'link_account_id': linkAccountId,
        'account_id': accountId,
        'status': status.dbValue,
        'prepay_penalty_rate': prepayPenaltyRate,
        'rate_reset_date': rateResetDate?.millisecondsSinceEpoch,
        'rate_basis_points': rateBasisPoints,
        'promo_until': promoUntil?.millisecondsSinceEpoch,
        'note': note,
        'active_plan_version': activePlanVersion,
        'sort_order': sortOrder,
        'archived': archived ? 1 : 0,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'delete_reason': deleteReason,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'revision': revision,
      };
}

/// 还款计划的一期（7.8）。
@immutable
class RepayPlanRecord {
  const RepayPlanRecord({
    this.id,
    required this.liabilityId,
    this.planVersion = 1,
    required this.termNo,
    required this.dueDate,
    this.principal = 0,
    this.interest = 0,
    this.fee = 0,
    this.remainingPrincipal = 0,
    this.status = PlanStatus.pending,
    this.paidAt,
    this.actualAmount,
    this.reason = '',
    required this.createdAt,
    this.revision = 1,
  });

  final int? id;
  final int liabilityId;
  final int planVersion;
  final int termNo;
  final DateTime dueDate;
  final double principal;
  final double interest;
  final double fee;
  final double remainingPrincipal;
  final PlanStatus status;
  final DateTime? paidAt;
  final double? actualAmount;
  final String reason;
  final DateTime createdAt;
  final int revision;

  double get total => principal + interest + fee;

  factory RepayPlanRecord.fromMap(Map<String, Object?> m) => RepayPlanRecord(
        id: _intOrNull(m['id']),
        liabilityId: _int(m['liability_id']),
        planVersion: _int(m['plan_version'], 1),
        termNo: _int(m['term_no']),
        dueDate: _date(m['due_date']),
        principal: _dbl(m['principal']),
        interest: _dbl(m['interest']),
        fee: _dbl(m['fee']),
        remainingPrincipal: _dbl(m['remaining_principal']),
        status: PlanStatus.fromDb(m['status']),
        paidAt: _dateOrNull(m['paid_at']),
        actualAmount: _dblOrNull(m['actual_amount']),
        reason: _str(m['reason']),
        createdAt: _date(m['created_at']),
        revision: _int(m['revision'], 1),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'liability_id': liabilityId,
        'plan_version': planVersion,
        'term_no': termNo,
        'due_date': dueDate.millisecondsSinceEpoch,
        'principal': principal,
        'interest': interest,
        'fee': fee,
        'remaining_principal': remainingPrincipal,
        'status': status.dbValue,
        'paid_at': paidAt?.millisecondsSinceEpoch,
        'actual_amount': actualAmount,
        'reason': reason,
        'created_at': createdAt.millisecondsSinceEpoch,
        'revision': revision,
      };
}

/// 一笔买入 / 卖出（6.5）。
@immutable
class AssetTradeRecord {
  const AssetTradeRecord({
    this.id,
    required this.assetId,
    required this.direction,
    required this.occurredAt,
    required this.unitPrice,
    required this.quantity,
    this.fee = 0,
    required this.amount,
    this.costBasis,
    this.realizedPnl,
    this.accountId,
    this.note = '',
    required this.createdAt,
    this.revision = 1,
  });

  final int? id;
  final int assetId;
  final TradeDirection direction;
  final DateTime occurredAt;
  final double unitPrice;
  final double quantity;
  final double fee;
  final double amount;
  final double? costBasis;
  final double? realizedPnl;
  final int? accountId;
  final String note;
  final DateTime createdAt;
  final int revision;

  factory AssetTradeRecord.fromMap(Map<String, Object?> m) => AssetTradeRecord(
        id: _intOrNull(m['id']),
        assetId: _int(m['asset_id']),
        direction: TradeDirection.fromDb(m['direction']),
        occurredAt: _date(m['occurred_at']),
        unitPrice: _dbl(m['unit_price']),
        quantity: _dbl(m['quantity']),
        fee: _dbl(m['fee']),
        amount: _dbl(m['amount']),
        costBasis: _dblOrNull(m['cost_basis']),
        realizedPnl: _dblOrNull(m['realized_pnl']),
        accountId: _intOrNull(m['account_id']),
        note: _str(m['note']),
        createdAt: _date(m['created_at']),
        revision: _int(m['revision'], 1),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'asset_id': assetId,
        'direction': direction.dbValue,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'unit_price': unitPrice,
        'quantity': quantity,
        'fee': fee,
        'amount': amount,
        'cost_basis': costBasis,
        'realized_pnl': realizedPnl,
        'account_id': accountId,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
        'revision': revision,
      };
}

/// 「万一要我还的钱」/「万一出事有人替我付吗」的一行。
@immutable
class ContingentRecord {
  const ContingentRecord({
    this.id,
    this.bookId = 'default',
    required this.kind,
    required this.title,
    required this.maxAmount,
    this.conditionText = '',
    this.eta = '',
    this.note = '',
    this.sortOrder = 0,
    this.archived = false,
    this.deletedAt,
    this.deleteReason,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
  });

  final int? id;
  final String bookId;
  final ContingentKind kind;
  final String title;
  final double maxAmount;
  final String conditionText;
  final String eta;
  final String note;
  final int sortOrder;
  final bool archived;
  final DateTime? deletedAt;
  final String? deleteReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  bool get isDeleted => deletedAt != null;

  factory ContingentRecord.fromMap(Map<String, Object?> m) => ContingentRecord(
        id: _intOrNull(m['id']),
        bookId: _str(m['book_id'], 'default'),
        kind: ContingentKind.fromDb(m['kind']),
        title: _str(m['title']),
        maxAmount: _dbl(m['max_amount']),
        conditionText: _str(m['condition_text']),
        eta: _str(m['eta']),
        note: _str(m['note']),
        sortOrder: _int(m['sort_order']),
        archived: _int(m['archived']) == 1,
        deletedAt: _dateOrNull(m['deleted_at']),
        deleteReason: m['delete_reason'] as String?,
        createdAt: _date(m['created_at']),
        updatedAt: _date(m['updated_at']),
        revision: _int(m['revision'], 1),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'book_id': bookId,
        'kind': kind.dbValue,
        'title': title,
        'max_amount': maxAmount,
        'condition_text': conditionText,
        'eta': eta,
        'note': note,
        'sort_order': sortOrder,
        'archived': archived ? 1 : 0,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'delete_reason': deleteReason,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'revision': revision,
      };
}

/// 口径开关的聚合视图（KV 表读出来后拼成一份不可变对象）。
/// 不替用户猜：monthlyIncome / mustCost 默认 0，界面显示「—」。
@immutable
class AzPreferences {
  const AzPreferences({
    this.valuationMode = ValuationMode.cost,
    this.staleDays = 90,
    this.debtRatioLevel = DebtRatioLevel.std,
    this.hideZero = true,
    this.monthlyIncome = 0,
    this.mustCost = 0,
    this.emergencyMonths = 3,
    this.inflationRate = 0,
    this.includeDebtCostInExpense = true,
  });

  final ValuationMode valuationMode;
  final int staleDays;
  final DebtRatioLevel debtRatioLevel;
  final bool hideZero;
  final double monthlyIncome;
  final double mustCost;
  final int emergencyMonths;
  final double inflationRate;
  final bool includeDebtCostInExpense;

  factory AzPreferences.fromRows(List<Map<String, Object?>> rows) {
    final Map<String, String> kv = <String, String>{
      for (final Map<String, Object?> r in rows)
        _str(r['key']): _str(r['value']),
    };
    return AzPreferences(
      valuationMode: ValuationMode.fromDb(kv['valuation_mode']),
      staleDays: int.tryParse(kv['stale_days'] ?? '') ?? 90,
      debtRatioLevel: DebtRatioLevel.fromDb(kv['debt_ratio_level']),
      hideZero: (kv['hide_zero'] ?? '1') == '1',
      monthlyIncome: double.tryParse(kv['monthly_income'] ?? '') ?? 0,
      mustCost: double.tryParse(kv['must_cost'] ?? '') ?? 0,
      emergencyMonths: int.tryParse(kv['emergency_months'] ?? '') ?? 3,
      inflationRate: double.tryParse(kv['inflation_rate'] ?? '') ?? 0,
      includeDebtCostInExpense:
          (kv['include_debt_cost_in_expense'] ?? '1') == '1',
    );
  }
}

/// 月末快照的一行（10.9 / 13.12，锁历史不重算）。
@immutable
class MonthlySnapshotRecord {
  const MonthlySnapshotRecord({
    required this.yearMonth,
    required this.accountTotal,
    required this.assetTotal,
    required this.debtTotal,
    required this.netWorth,
    required this.valuationMode,
    required this.snapshotAt,
    this.note = '',
    this.locked = true,
    this.revision = 1,
  });

  final String yearMonth;
  final double accountTotal;
  final double assetTotal;
  final double debtTotal;
  final double netWorth;
  final ValuationMode valuationMode;
  final DateTime snapshotAt;
  final String note;
  final bool locked;
  final int revision;

  factory MonthlySnapshotRecord.fromMap(Map<String, Object?> m) =>
      MonthlySnapshotRecord(
        yearMonth: _str(m['year_month']),
        accountTotal: _dbl(m['account_total']),
        assetTotal: _dbl(m['asset_total']),
        debtTotal: _dbl(m['debt_total']),
        netWorth: _dbl(m['net_worth']),
        valuationMode: ValuationMode.fromDb(m['valuation_mode']),
        snapshotAt: _date(m['snapshot_at']),
        note: _str(m['note']),
        locked: _int(m['locked'], 1) == 1,
        revision: _int(m['revision'], 1),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'year_month': yearMonth,
        'account_total': accountTotal,
        'asset_total': assetTotal,
        'debt_total': debtTotal,
        'net_worth': netWorth,
        'valuation_mode': valuationMode.dbValue,
        'snapshot_at': snapshotAt.millisecondsSinceEpoch,
        'note': note,
        'locked': locked ? 1 : 0,
        'revision': revision,
      };
}

/// 一次读出的全部资债数据（给 [AzMath] 当输入，页面不各读一遍）。
@immutable
class AzData {
  const AzData({
    this.assets = const <AssetRecord>[],
    this.liabilities = const <LiabilityRecord>[],
    this.plans = const <RepayPlanRecord>[],
    this.trades = const <AssetTradeRecord>[],
    this.contingents = const <ContingentRecord>[],
    this.preferences = const AzPreferences(),
    this.snapshots = const <MonthlySnapshotRecord>[],
  });

  final List<AssetRecord> assets;
  final List<LiabilityRecord> liabilities;
  final List<RepayPlanRecord> plans;
  final List<AssetTradeRecord> trades;
  final List<ContingentRecord> contingents;
  final AzPreferences preferences;
  final List<MonthlySnapshotRecord> snapshots;

  List<AssetRecord> get activeAssets =>
      assets.where((AssetRecord a) => !a.isDeleted && !a.archived).toList();
  List<LiabilityRecord> get activeLiabilities => liabilities
      .where((LiabilityRecord d) => !d.isDeleted && !d.archived)
      .toList();
  List<ContingentRecord> get activeContingents => contingents
      .where((ContingentRecord c) => !c.isDeleted && !c.archived)
      .toList();
}
