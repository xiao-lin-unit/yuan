import 'package:flutter/foundation.dart';

/// 账户三大类（《软件设计想法》3.2）。
///
/// 一张 `accounts` 表用 [AccountKind] 区分，不拆成「储蓄卡表 / 信用卡表」。
/// 理由见 account_db.dart 的类注释：三类共享 80% 字段，且「余额」与
/// 「信用卡已用额度」本质是同一个量纲——都是**由流水驱动、只增不手填**
/// 的累计值，只是统计口径相反。
enum AccountKind {
  liquid('liquid', '流动资金账户', '能自由花的钱'),
  credit('credit', '信用卡账户', '先用后还的钱'),
  restricted('restricted', '其他资金账户', '有特定用途的钱');

  const AccountKind(this.dbValue, this.label, this.hint);

  final String dbValue;
  final String label;
  final String hint;

  static AccountKind fromDb(String? value) => switch (value) {
        'credit' => credit,
        'restricted' => restricted,
        _ => liquid,
      };

  /// 首页的分区顺序，也是列表默认排序的分组依据。
  int get groupOrder => switch (this) {
        AccountKind.liquid => 0,
        AccountKind.credit => 1,
        AccountKind.restricted => 2,
      };
}

/// 账户形态（3.3 / 3.4 / 3.5 里出现过的全部具体类型）。
///
/// [socialSecurity] 与 [housingFund] 按 3.5「强制为否且不可改」，
/// 在 DDL 的 CHECK 与页面开关里都锁死 isLiquid = 0。
/// 新增形态只需在此加一个枚举值 + account_db.dart 的 CHECK，
/// 不需要 ALTER TABLE（CHECK 用 `type IN (...)` 列出全部取值）。
enum AccountType {
  bank('bank', '储蓄卡'),
  cash('cash', '现金'),
  wechat('wechat', '微信零钱'),
  alipay('alipay', '支付宝'),
  creditCard('credit_card', '信用卡'),
  socialSecurity('social_security', '社保'),
  housingFund('housing_fund', '公积金'),
  giftCard('gift_card', '礼品卡'),
  frozen('frozen', '已冻结存款'),
  other('other', '其他');

  const AccountType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AccountType fromDb(String? value) => switch (value) {
        'cash' => cash,
        'wechat' => wechat,
        'alipay' => alipay,
        'credit_card' => creditCard,
        'social_security' => socialSecurity,
        'housing_fund' => housingFund,
        'gift_card' => giftCard,
        'frozen' => frozen,
        'other' => other,
        _ => bank,
      };

  /// 3.5：社保 / 公积金「流动资金」强制为否且不可改。
  bool get liquidLocked => this == socialSecurity || this == housingFund;

  /// 该形态默认属于哪一类（新增账户时选定类型后自动带出，可改）。
  AccountKind get defaultKind => switch (this) {
        creditCard => AccountKind.credit,
        socialSecurity ||
        housingFund ||
        giftCard ||
        frozen =>
          AccountKind.restricted,
        _ => AccountKind.liquid,
      };
}

/// 流水方向。**一律指「本账户那个累计值的增减」，与业务是收入还是支出无关。**
///
/// 这是「一张流水表 + 一个标记字段」能成立的关键约定（10.6 金额只填正数、
/// 用类型区分，不用负数）：
///   · 流动资金 / 受限账户：in = 钱进来（余额 +），out = 钱出去（余额 −）；
///   · 信用卡：in = 消费（**已用额度 +**），out = 还款（已用额度 −）。
/// 于是 `balance_after = balance_before + (in ? amount : −amount)` 对三类
/// 账户是同一条公式，不需要在 DAO 里按 kind 分叉。原型信用卡明细里的
/// 「消费入账 +¥156」「还款出账 −¥1,000」正是这个口径。
enum AccountDirection {
  inbound('in', '入账'),
  outbound('out', '出账');

  const AccountDirection(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AccountDirection fromDb(String? value) =>
      value == 'in' ? inbound : outbound;

  /// 余额增量符号。金额恒正，符号只由方向决定。
  double get sign => this == inbound ? 1 : -1;
}

/// 资金变动的业务种类。一次变动只产生一条流水，转账产生两条（见
/// [AccountEntryRecord.transferGroupId]）。
enum AccountEntryType {
  opening('opening', '开户初始余额'),
  expense('expense', '支出'),
  income('income', '收入'),
  transferOut('transfer_out', '转出'),
  transferIn('transfer_in', '转入'),
  adjustment('adjustment', '余额调整'),
  creditSpend('credit_spend', '信用卡消费'),
  creditRepay('credit_repay', '信用卡还款');

  const AccountEntryType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AccountEntryType fromDb(String? value) => switch (value) {
        'expense' => expense,
        'income' => income,
        'transfer_out' => transferOut,
        'transfer_in' => transferIn,
        'adjustment' => adjustment,
        'credit_spend' => creditSpend,
        'credit_repay' => creditRepay,
        _ => opening,
      };
}

/// 账户主表的一行。
///
/// 字段全部能在《软件设计想法》里找到出处，不是随手预留；详见
/// account_db.dart 的「字段出处表」与《账户表结构与页面说明》。
@immutable
class AccountRecord {
  const AccountRecord({
    this.id,
    this.bookId = 'default',
    required this.kind,
    required this.type,
    required this.name,
    this.balance = 0,
    this.initialBalance = 0,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
    this.repayAccountId,
    this.minPaymentRate = 0.1,
    this.note = '',
    this.isLiquid = true,
    this.includeInNetWorth = true,
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
  final AccountKind kind;
  final AccountType type;
  final String name;

  /// 由流水事务推导并物化的当前值，**用户永远不能直接改**（3.8 / 10.9
  /// 「单写点原则」）。流动资金/受限 = 当前余额；信用卡 = 已用额度。
  /// 允许为负：4.7「账户余额不足时保存成功但给橙色提示」，用户可能在
  /// 补记昨天的账，硬拦会记不了账。
  final double balance;

  /// 开户时唯一允许手填的数字（3.8）。它本身也是一条 `opening` 流水。
  final double initialBalance;

  // ── 信用卡专属：仅 kind=credit 时非空 ──────────────────────────
  /// 总额度；可用额度 = creditLimit − balance，永远算出来而不是存一列。
  final double? creditLimit;

  /// 账单日 / 还款日：每月几号（1..31），跨月归属见附录 C。
  final int? statementDay;
  final int? dueDay;

  /// 关联还款的储蓄卡 id（3.4「软件知道提醒他从哪张卡扣」）。
  final int? repayAccountId;

  /// 最低还款比例，原型「最低还款 ¥680」由可用额度 × 此比例算出。
  final double minPaymentRate;

  final String note;

  /// 是否计入「现在能花的钱」。liquid 恒 true、credit 恒 false；
  /// restricted 里社保/公积金强制 false，其余由用户改（3.5）。
  final bool isLiquid;

  /// 是否计入「真正属于你的钱」（3.6 总资产口径）。信用卡恒 false。
  final bool includeInNetWorth;

  final int sortOrder;
  final bool archived;
  final DateTime? deletedAt;
  final String? deleteReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  bool get isDeleted => deletedAt != null;

  /// 可用额度：只有信用卡有，且 creditLimit 为空时返回 null（界面显示「—」，
  /// 不显示 0，避免用户误以为额度是 0；6.7 同款兜底）。
  double? get availableCredit => kind == AccountKind.credit && creditLimit != null
      ? creditLimit! - balance
      : null;

  /// 卡片副标题：原型三类各不相同，统一由模型算出，页面不拼字符串规则。
  String get subtitle => switch (kind) {
        AccountKind.credit =>
          '总额度 ${creditLimit?.toStringAsFixed(0) ?? "—"} · 已用 ${balance.toStringAsFixed(0)}',
        AccountKind.restricted =>
          note.isEmpty ? '仅限绑定的用途使用' : note,
        AccountKind.liquid => note.isEmpty ? type.label : note,
      };

  static DateTime _date(Object? v) => v == null
      ? DateTime.fromMillisecondsSinceEpoch(0)
      : DateTime.fromMillisecondsSinceEpoch((v as int));

  factory AccountRecord.fromMap(Map<String, dynamic> m) => AccountRecord(
        id: m['id'] as int?,
        bookId: (m['book_id'] as String?) ?? 'default',
        kind: AccountKind.fromDb(m['kind'] as String?),
        type: AccountType.fromDb(m['type'] as String?),
        name: (m['name'] as String?) ?? '',
        balance: (m['balance'] as num?)?.toDouble() ?? 0,
        initialBalance: (m['initial_balance'] as num?)?.toDouble() ?? 0,
        creditLimit: (m['credit_limit'] as num?)?.toDouble(),
        statementDay: m['statement_day'] as int?,
        dueDay: m['due_day'] as int?,
        repayAccountId: m['repay_account_id'] as int?,
        minPaymentRate: (m['min_payment_rate'] as num?)?.toDouble() ?? 0.1,
        note: (m['note'] as String?) ?? '',
        isLiquid: (m['is_liquid'] as int?) == 1,
        includeInNetWorth: (m['include_in_net_worth'] as int?) == 1,
        sortOrder: (m['sort_order'] as int?) ?? 0,
        archived: (m['archived'] as int?) == 1,
        deletedAt: m['deleted_at'] == null ? null : _date(m['deleted_at']),
        deleteReason: m['delete_reason'] as String?,
        createdAt: _date(m['created_at']),
        updatedAt: _date(m['updated_at']),
        revision: (m['revision'] as int?) ?? 1,
      );

  /// 不含 id：insert 时用；update 由 DAO 单独带 where。
  Map<String, dynamic> toMap() => <String, dynamic>{
        'book_id': bookId,
        'kind': kind.dbValue,
        'type': type.dbValue,
        'name': name,
        'balance': balance,
        'initial_balance': initialBalance,
        'credit_limit': creditLimit,
        'statement_day': statementDay,
        'due_day': dueDay,
        'repay_account_id': repayAccountId,
        'min_payment_rate': minPaymentRate,
        'note': note,
        'is_liquid': isLiquid ? 1 : 0,
        'include_in_net_worth': includeInNetWorth ? 1 : 0,
        'sort_order': sortOrder,
        'archived': archived ? 1 : 0,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'delete_reason': deleteReason,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'revision': revision,
      };

  /// 保留 id（前几轮修过 copyWith 漏 id 导致 `WHERE id = NULL` 更新 0 行）。
  /// 可空字段用 sentinel 区分「不改」与「显式置空」。
  AccountRecord copyWith({
    String? name,
    AccountType? type,
    double? balance,
    Object? creditLimit = _sentinel,
    Object? statementDay = _sentinel,
    Object? dueDay = _sentinel,
    Object? repayAccountId = _sentinel,
    double? minPaymentRate,
    String? note,
    bool? isLiquid,
    bool? includeInNetWorth,
    int? sortOrder,
    bool? archived,
    Object? deletedAt = _sentinel,
    Object? deleteReason = _sentinel,
    DateTime? updatedAt,
    int? revision,
  }) =>
      AccountRecord(
        id: id,
        bookId: bookId,
        kind: kind,
        type: type ?? this.type,
        name: name ?? this.name,
        balance: balance ?? this.balance,
        initialBalance: initialBalance,
        creditLimit: identical(creditLimit, _sentinel)
            ? this.creditLimit
            : creditLimit as double?,
        statementDay: identical(statementDay, _sentinel)
            ? this.statementDay
            : statementDay as int?,
        dueDay: identical(dueDay, _sentinel)
            ? this.dueDay
            : dueDay as int?,
        repayAccountId: identical(repayAccountId, _sentinel)
            ? this.repayAccountId
            : repayAccountId as int?,
        minPaymentRate: minPaymentRate ?? this.minPaymentRate,
        note: note ?? this.note,
        isLiquid: isLiquid ?? this.isLiquid,
        includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
        sortOrder: sortOrder ?? this.sortOrder,
        archived: archived ?? this.archived,
        deletedAt: identical(deletedAt, _sentinel)
            ? this.deletedAt
            : deletedAt as DateTime?,
        deleteReason: identical(deleteReason, _sentinel)
            ? this.deleteReason
            : deleteReason as String?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        revision: revision ?? this.revision,
      );

  static const Object _sentinel = Object();
}

/// 账户出入流水的一行（10.3「每张卡都要有一本流水账」）。
///
/// 【职责边界】本表只记「账户那个累计值怎么变的」：方向、正数金额、
/// 变动后余额、时间、对手账户。支出/收入的完整业务单据（商家、小票、
/// 报销、标签、报税、预算…）属于「记支出 / 记收入」模块，将来用
/// `ref_type + ref_id` 挂到各自的业务表，**不往本表加列**——这是
/// 「业务没变就不二次改表结构」的关键：新增业务 = 新增关联表。
@immutable
class AccountEntryRecord {
  const AccountEntryRecord({
    this.id,
    this.bookId = 'default',
    required this.accountId,
    required this.direction,
    required this.amount,
    required this.balanceAfter,
    required this.entryType,
    required this.occurredAt,
    this.counterpartyAccountId,
    this.transferGroupId,
    this.categoryId,
    this.payee = '',
    this.note = '',
    this.reason = '',
    this.nonBinding = false,
    this.imageRef,
    this.refType,
    this.refId,
    required this.createdAt,
    this.revision = 1,
  });

  final int? id;
  final String bookId;
  final int accountId;
  final AccountDirection direction;

  /// 恒为正（10.6 / 附录 D）。要表示减少，用 [direction]，不用负数。
  final double amount;

  /// 变动**之后**的账户累计值，直接显示在流水行右侧（10.3）。
  /// 也是 10.9 恒等式逐笔可审计的依据：逐行 rollback 能还原任一时点。
  final double balanceAfter;

  final AccountEntryType entryType;

  /// 交易发生时间（不是录入时间）：附录 C「所有月/周统计以交易时间归属，
  /// 用户可能月底补记月初的账」。
  final DateTime occurredAt;

  final int? counterpartyAccountId;

  /// 一笔转账生成两条流水，用同一个 group id 配对（3.7）。
  final String? transferGroupId;

  /// 支出/收入分类（分类表已存在，直接存 id）。
  final int? categoryId;
  final String payee;
  final String note;

  /// 余额调整必填原因（3.8「必须填原因，且会在流水里留下调整记录」）。
  final String reason;

  /// 3.5 软约束：用了受限账户但不在绑定用途里，标记后在统计里单独提示。
  final bool nonBinding;

  /// 小票 / 凭证图，走统一图片层 ImageRef 编码，不存 base64。
  final String? imageRef;

  /// 将来业务单据的反向引用（expense / income / liability …）。
  final String? refType;
  final int? refId;

  final DateTime createdAt;
  final int revision;

  static DateTime _date(Object? v) => v == null
      ? DateTime.fromMillisecondsSinceEpoch(0)
      : DateTime.fromMillisecondsSinceEpoch((v as int));

  factory AccountEntryRecord.fromMap(Map<String, dynamic> m) =>
      AccountEntryRecord(
        id: m['id'] as int?,
        bookId: (m['book_id'] as String?) ?? 'default',
        accountId: (m['account_id'] as int?) ?? 0,
        direction: AccountDirection.fromDb(m['direction'] as String?),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        balanceAfter: (m['balance_after'] as num?)?.toDouble() ?? 0,
        entryType: AccountEntryType.fromDb(m['entry_type'] as String?),
        occurredAt: _date(m['occurred_at']),
        counterpartyAccountId: m['counterparty_account_id'] as int?,
        transferGroupId: m['transfer_group_id'] as String?,
        categoryId: m['category_id'] as int?,
        payee: (m['payee'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        reason: (m['reason'] as String?) ?? '',
        nonBinding: (m['non_binding'] as int?) == 1,
        imageRef: m['image_ref'] as String?,
        refType: m['ref_type'] as String?,
        refId: m['ref_id'] as int?,
        createdAt: _date(m['created_at']),
        revision: (m['revision'] as int?) ?? 1,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'book_id': bookId,
        'account_id': accountId,
        'direction': direction.dbValue,
        'amount': amount,
        'balance_after': balanceAfter,
        'entry_type': entryType.dbValue,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'counterparty_account_id': counterpartyAccountId,
        'transfer_group_id': transferGroupId,
        'category_id': categoryId,
        'payee': payee,
        'note': note,
        'reason': reason,
        'non_binding': nonBinding ? 1 : 0,
        'image_ref': imageRef,
        'ref_type': refType,
        'ref_id': refId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'revision': revision,
      };
}

/// 受限账户 ↔ 支出分类的绑定（3.5 多对多）。单独一张关联表，
/// 主表不塞 JSON / 逗号串；一个支出类型可被多个账户绑定。
@immutable
class AccountCategoryBinding {
  const AccountCategoryBinding({
    required this.accountId,
    required this.categoryId,
  });

  final int accountId;
  final int categoryId;
}

/// 首页顶部看板（3.6）。业务层算好，页面只显示。
@immutable
class AccountStats {
  const AccountStats({
    required this.spendable,
    required this.owedToBank,
    required this.restrictedTotal,
    required this.accountCount,
    required this.creditCount,
  });

  /// 现在能花的钱 = 所有流动资金账户余额之和。
  final double spendable;

  /// 欠银行的钱 = 所有信用卡已用额度之和。
  final double owedToBank;

  /// 其他（受限）账户余额合计，只进「真正属于你的钱」，不进「能花的钱」。
  final double restrictedTotal;

  final int accountCount;
  final int creditCount;
}

/// 明细页流水汇总（原型「总入账 / 总出账 / 净变动」）。
@immutable
class AccountEntrySummary {
  const AccountEntrySummary({
    required this.inbound,
    required this.outbound,
    required this.balanceAfter,
  });

  final double inbound;
  final double outbound;
  double get net => inbound - outbound;
  final double balanceAfter;
}
