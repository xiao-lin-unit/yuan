import 'package:flutter/foundation.dart';

/// 账户三大类（《软件设计想法》3.2）。
///
/// 一张 `accounts` 表用 [AccountKind] 区分，不拆成「储蓄卡表 / 信用卡表」。
/// 理由见 account_db.dart 的类注释：三类共享 80% 字段，且「余额」与
/// 「信用卡已用额度」本质是同一个量纲——都是**由流水驱动、只增不手填**
/// 的累计值，只是统计口径相反。
enum AccountKind {
  liquid('liquid', '流动资金账户', '可自由支配'),
  credit('credit', '信用卡账户', '先消费后还款'),
  restricted('restricted', '其他资金账户', '限定用途');

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

/// 账户形态（3.3 / 3.4 / 3.5 里的全部具体类型，按三大类分组）。
///
/// ══════════════════════════════════════════════════════════════════
/// 【这些形态算不算「能自由花的钱」】——任务里的判断题，结论落在代码
/// ══════════════════════════════════════════════════════════════════
/// 问题其实混了两个口径，分开才说得清：
///   · 口径 A「能不能拿去花」：
///       储蓄卡 / 现金 / 微信零钱 / 支付宝   → 能；
///       信用卡 / 花呗 / 借呗              → 能，但花的是银行或平台的钱，要还；
///       公积金 / 社保 / 礼品卡 / 冻结存款   → 不能，或受法定、约定用途限制。
///   · 口径 B「算不算自己现在能用的钱」（3.6 看板、is_liquid 取这个）：
///       只有流动资金账户       → 计入「可用余额」；
///       信用类                 → 是欠款，单列为减项，绝不计入；
///       公积金 / 社保等受限账户 → 属于你的资产，只进「资产合计」，
///                                 不进「可用余额」。
/// 所以：公积金、社保、礼品卡、冻结存款**都不算**能自由花的钱。
/// 设计文档 3.4 那句「信用卡流动资金默认为是」讲的是口径 A（额度可以
/// 自由支配地去刷），与本表 is_liquid 取口径 B 不矛盾——不是同一件事。
///
/// 代码上的落点（DDL CHECK + 两个业务 Controller 的 save 双保险）：
///   · liquid      → is_liquid 恒 1；
///   · credit      → is_liquid 恒 0、include_in_net_worth 恒 0；
///   · restricted  → 由用户决定；社保 / 公积金 [liquidLocked] 强制为 0。
/// 冻结存款归 restricted，默认不计入可用余额，但允许手动改（3.5「其他
/// 类型用户可手动改」）；社保 / 公积金连开关都锁死。
///
/// 【借呗单独说明】花呗是场景化信用赊销（类似虚拟信用卡，在支付时动用
/// 额度）；借呗是现金贷，放款直接进银行卡，本质是「流动资金账户入账 +
/// 负债增加」两笔联动，不能只记一笔消费，否则 3.8 恒等式对不上。
/// 本轮只把借呗登记为信用类形态，不开放「借呗直接消费」入口，等负债
/// 模块（7.5）一起做。
///
/// 【为什么按类别写死清单】[allowedTypesFor] 是**唯一真源**：下拉候选、
/// 表单校验、历史脏数据兜底全部读它。原先靠 `ownerKind` 通配（null =
/// 任何类别都可选），结果「信用卡类别里出现『其他』」「其他资金账户
/// 编辑旧脏数据时冒出信用卡形态」两类错配都发生过。
///
/// 现在三条清单互不相交地表达业务事实：
///   · 流动资金账户：储蓄卡 / 现金 / 微信零钱 / 支付宝 / 其他；
///   · 信用卡账户：信用卡 / 花呗 / 借呗 —— **不含通用「其他」**；
///   · 其他资金账户：社保 / 公积金 / 礼品卡 / 冻结存款 / 其他 ——
///     **完全不含任何信用卡形态**。
/// 以后新增形态 = 加一个枚举值 + 往对应清单加一项，无需重建主表
/// （DDL 不锁 type 取值，合法性全在 Dart 侧）。
enum AccountType {
  bank('bank', '储蓄卡'),
  cash('cash', '现金'),
  wechat('wechat', '微信零钱'),
  alipay('alipay', '支付宝'),

  creditCard('credit_card', '信用卡'),
  huabei('huabei', '花呗'),
  jiebei('jiebei', '借呗'),

  socialSecurity('social_security', '社保'),
  housingFund('housing_fund', '公积金'),
  giftCard('gift_card', '礼品卡'),
  frozen('frozen', '冻结存款'),

  other('other', '其他');

  const AccountType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AccountType fromDb(String? value) => switch (value) {
        'cash' => cash,
        'wechat' => wechat,
        'alipay' => alipay,
        'credit_card' => creditCard,
        'huabei' => huabei,
        'jiebei' => jiebei,
        'social_security' => socialSecurity,
        'housing_fund' => housingFund,
        'gift_card' => giftCard,
        'frozen' => frozen,
        'other' => other,
        _ => bank,
      };

  /// 3.5：社保 / 公积金「流动资金」强制为否且不可改。
  bool get liquidLocked => this == socialSecurity || this == housingFund;

  /// 该形态能否用于指定类别。DDL 不锁 type 取值，合法性全部走这里。
  /// 工作逻辑：只在 [allowedTypesFor] 的清单里查找，清单是唯一真源。
  bool supports(AccountKind kind) => allowedTypesFor(kind).contains(this);

  /// 新增 / 编辑账户时该类别的下拉候选（唯一真源，表单与两个业务
  /// Controller 的 save 校验共用）。
  ///
  /// 【静态清单，不是运行时推导】三张清单写死在这里，读一眼就知道每类
  /// 有哪些形态。信用卡清单不含通用「其他」，其他资金账户清单不含任何
  /// 信用形态 —— 这正是本轮要求的「其他类型账户中将信用卡类型删除」。
  static List<AccountType> allowedTypesFor(AccountKind kind) => switch (kind) {
        AccountKind.liquid => const <AccountType>[
          bank, cash, wechat, alipay, other,
        ],
        AccountKind.credit => const <AccountType>[
          creditCard, huabei, jiebei,
        ],
        AccountKind.restricted => const <AccountType>[
          socialSecurity, housingFund, giftCard, frozen, other,
        ],
      };

  /// 该类别的默认形态（表单未改动类型时的兜底值）。显式 switch 而非
  /// 取列表首项：restricted 的首项是社保，作为新账户默认值并不合适。
  static AccountType defaultTypeFor(AccountKind kind) => switch (kind) {
        AccountKind.liquid => AccountType.bank,
        AccountKind.credit => AccountType.creditCard,
        AccountKind.restricted => AccountType.other,
      };
}

/// 流水方向。**方向描述资金往哪走，不描述累计值怎么变。**
///
/// 这是「一张流水表 + 一个标记字段」能成立的关键约定（10.6 金额只填正数、
/// 用类型区分，不用负数）：
///   · 流动资金 / 其他资金账户（储蓄类型卡）：
///       in = 钱进来（余额 +），out = 钱出去（余额 −）；
///   · 信用卡：
///       out = 消费**出账**（钱花出去了，已用额度 / 欠款 +），
///       in  = 还款**入账**（钱还回来了，已用额度 / 欠款 −）。
///
/// 【为什么信用卡反过来】信用卡的 `balance` 记的是「已用额度」，不是
/// 「卡里有多少钱」。消费时额度被占用，是账户对外付出，方向应为出账；
/// 还款时额度被释放，是资金回流，方向应为入账。累计值的增减由
/// [AccountBalanceRule] 按账户类别决定，**不再让三类账户共用一条公式**。
/// 原型明细里「超市购物 +¥156」「储蓄卡还款 −¥1,000」是「已用额度」
/// 的显示口径，与本表的 `in/out` 是两个概念，不要混为一谈。
enum AccountDirection {
  inbound('in', '入账'),
  outbound('out', '出账');

  const AccountDirection(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AccountDirection fromDb(String? value) =>
      value == 'in' ? inbound : outbound;

  /// 方向自身的符号：**只在储蓄规则下**等于累计值增量。
  /// 信用卡规则要取反，见 [AccountBalanceRule.delta]。
  double get sign => this == inbound ? 1 : -1;
}

/// 累计值的运算规则。本轮把原先「三类账户同一条公式」拆成两条。
///
/// 【为什么是编译期枚举，而不是 DAO 里读 kind 分叉】
/// 口径写错不会立刻崩，只会让余额悄悄算反。把规则做成 [AccountEntryDao.append]
/// 的**必传参数**（没有默认值），漏传就是编译错误，处理器没法悄悄退回
/// 旧公式；DAO 保持纯 SQL 执行层，不认识账户类别。
///
/// 工作逻辑（两条恒等式，金额恒正）：
///   · [savings]：余额     = 期初余额 + Σ入账 − Σ出账；
///   · [credit] ：已用额度 = Σ出账 − Σ入账（信用卡没有「期初已用额度」）。
/// [of] 是类别 → 规则的唯一映射，[delta] 是单笔流水对累计值的增量。
enum AccountBalanceRule {
  savings('储蓄类：余额 = 期初 + 入账 − 出账'),
  credit('信用卡：已用额度 = 出账 − 入账');

  const AccountBalanceRule(this.formula);

  final String formula;

  static AccountBalanceRule of(AccountKind kind) =>
      kind == AccountKind.credit ? credit : savings;

  double delta(AccountDirection direction, num amount) => switch (this) {
        AccountBalanceRule.savings => direction.sign * amount,
        AccountBalanceRule.credit => -direction.sign * amount,
      };
}

/// 资金变动的业务种类。一次变动只产生一条流水，转账产生两条（见
/// [AccountEntryRecord.transferGroupId]）。
enum AccountEntryType {
  opening('opening', '初始余额'),
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
  /// 「单写点原则」）。流动资金 / 其他资金账户 = 当前余额；信用卡 =
  /// 已用额度。两者共用一列，但增减规则相反（[AccountBalanceRule]）：
  /// 储蓄类入账加、出账减；信用卡出账加、入账减。
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
          note.isEmpty ? '仅限绑定用途使用' : note,
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
/// 【职责边界】本表记「账户那个累计值怎么变的」以及**逐笔时点快照**：
/// 方向、正数金额、变动后余额、变动后的总额度（信用卡）、时间、
/// 对手账户。支出/收入的完整业务单据（商家、小票、报销、标签、报税、
/// 预算…）属于「记支出 / 记收入」模块，用 `ref_type + ref_id` 挂到
/// 各自的业务表，不塞成流水表的几十个可空列。
/// 但时点快照类字段属于本表自身职责：功能需要时就直接加列（如
/// [AccountEntryRecord.creditLimitAfter]），不因「少一次 ALTER」而留下
/// 只能用当前值近似的历史展示。
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
    this.creditLimitAfter,
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

  /// 这笔发生**之后**该卡的总额度（信用卡才有，储蓄类为 null）。
  ///
  /// 【为什么要有它】`balanceAfter` 记的是已用额度，可用额度 =
  /// `creditLimitAfter - balanceAfter`。总额度会被「调整额度」改动，
  /// 若用当前额度去减历史余额，调额前的流水就会显示一个当时根本不存在
  /// 的可用金额。把额度作为**逐笔时点快照**存下，历史就永久可精确回放。
  ///
  /// 【写入位置】与 [balanceAfter] 一样，由 `AccountEntryDao.append` 在
  /// 同一个事务里读账户当前值后覆盖写入；构造时不用传（默认 null），
  /// 因此两个业务 Controller 的 8 处流水构造点都不必改动，也不会出现
  /// 「调用方传了过期额度」的并发问题。
  final double? creditLimitAfter;

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
        creditLimitAfter:
            (m['credit_limit_after'] as num?)?.toDouble(),
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
        'credit_limit_after': creditLimitAfter,
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

/// 账户使用频次聚合结果（按流水算，**不存表**）。
///
/// 【为什么是查询结果而不是 accounts 表的一列】4.6「最近用过的」与
/// 「记支出时预选上次使用账户」都可以由 account_entries 直接聚合，
/// 与 category 模块同一条原则（`last_used_at / use_count` 刻意不入表）：
/// 冗余一份计数就要处理「转账/还款算不算使用」「删了流水要不要回退」，
/// 永远可能和真实数据不一致。这里按需查询，结果天然准确。
///
/// [lastUsedAt] 取该账户最后一笔流水的 **occurred_at**（交易时间，
/// 附录 C），不是 createdAt：用户月底补记月初的账，归属应按交易时间。
/// 结果按 lastUsedAt 倒序，因此**第一项就是「上次使用账户」**。
@immutable
class AccountUsage {
  const AccountUsage({
    required this.accountId,
    required this.useCount,
    required this.lastUsedAt,
  });

  final int accountId;
  final int useCount;
  final DateTime lastUsedAt;
}

/// 明细页流水汇总。
///
/// [inbound] / [outbound] 是**按 direction 聚合的原始金额**，与账户类别
/// 无关；[net] 只对储蓄类有意义（余额净变动）。信用卡的「已用额度净增」
/// 是 `outbound - inbound`，由 CreditCardAccountController 与明细页按
/// 类别单独解释，不在这里复用 net（避免把两套口径混成一个字段）。
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
