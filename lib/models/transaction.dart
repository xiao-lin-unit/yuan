import 'money.dart';

/// 交易类型。转账不在收支内，归账户操作。
enum TxType { expense, income, transfer, adjustment }

/// 流水方向。用于账户出入记录展示。
enum FlowDirection { inflow, outflow }

/// 收支/转账记录。
class Transaction {
  final String id;
  final TxType type;

  /// 支出分类 id 或收入分类 id
  final String categoryId;

  /// 发生时间
  final DateTime occurredAt;

  final Money amount;

  /// 主账户 id（支出账户 / 收款账户 / 转账转出账户）
  final String accountId;

  /// 转账时转入账户
  final String? toAccountId;

  /// 收款方 / 付款方
  final String? counterparty;

  final String? remark;
  final List<String>? imagePaths;
  final bool isReimbursable;
  final bool isTaxable;
  final List<String>? tags;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  const Transaction({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.occurredAt,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.counterparty,
    this.remark,
    this.imagePaths,
    this.isReimbursable = false,
    this.isTaxable = false,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  /// 该交易对 accountId 来说是入账还是出账。
  /// 转账是纯资金移动，不产生收支，不计入收支统计。
  FlowDirection flowFor(String accountId) {
    if (type == TxType.expense) return FlowDirection.outflow;
    if (type == TxType.income) return FlowDirection.inflow;
    if (type == TxType.transfer) {
      if (this.accountId == accountId) return FlowDirection.outflow;
      if (toAccountId == accountId) return FlowDirection.inflow;
    }
    if (type == TxType.adjustment) {
      // 余额调整：金额 >0 视为入账补录，<0 视为出账核销
      return amount.isNegative ? FlowDirection.outflow : FlowDirection.inflow;
    }
    return FlowDirection.outflow;
  }

  /// 是否影响本月结余统计
  bool get affectsBalance => type == TxType.expense || type == TxType.income;

  /// 是否影响净资产（转账不影响）
  bool get affectsNetWorth => affectsBalance;
}
