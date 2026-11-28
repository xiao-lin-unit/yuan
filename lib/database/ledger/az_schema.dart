
/// 字段输入种类：金额一律按 TEXT 十进制字符串存，界面按文本录入。
/// 【所属模块】database/ledger · 资债元数据
/// 【实现功能】标记一个列在动态表单里用哪种输入控件（文本 / 整数 / 金额 / 枚举）。
/// 【使用限制】只描述录入方式，不参与 SQL 拼接；枚举值由 options 提供，不写 CHECK。
/// 【入参与结果】无入参；枚举常量供 AzColumn.kind 使用。
/// 【异常与调用方处理】不抛异常；未知取值由调用方按 text 兜底，不得据此写库。
enum AzInputKind { text, integer, money, choice }

/// 一列的录入元数据。
/// 【所属模块】database/ledger · 资债元数据
/// 【实现功能】描述一张表里一列的列名、中文标签、SQLite 类型、是否必填与录入方式，供动态表单与详情只读展示共用。
/// 【使用限制】不可变；name 必须来自 AzDb 的真实 DDL；options 只在 kind=enum 时有值。
/// 【入参与结果】构造收 name / label / sqliteType / required / kind / options；消费方只读字段。
/// 【异常与调用方处理】不抛异常；调用方需自行保证 name 已在 DDL 中登记，否则写库会报 no such column。
class AzColumn {
  const AzColumn(this.name, this.label, this.sqliteType,
      {required this.required, required this.kind, this.options = const <String>[]});

  final String name;
  final String label;
  final String sqliteType;
  final bool required;
  final AzInputKind kind;
  final List<String> options;
}

/// 一个具体类型（A3~A11 / 贷款 / 分期）。
/// 【所属模块】database/ledger · 资债元数据
/// 【实现功能】把「类型编码 → 中文名 → 次表名 → 所属类型组」收成一条，home 页与新增表单据此分派。
/// 【使用限制】不可变；side 只能是 asset / liability；subTable 必须在 AzDb 中登记。
/// 【入参与结果】构造收 code / label / subTable / groupKey / side；消费方只读字段。
/// 【异常与调用方处理】不抛异常；未登记类型由调用方先查 AzSchema.byCode 判空。
class AzTypeSpec {
  const AzTypeSpec({
    required this.code,
    required this.label,
    required this.subTable,
    required this.groupKey,
    required this.side,
  });

  final String code;
  final String label;
  final String subTable;
  final String groupKey;
  final String side;

  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】返回该类型在新增表单里要录入的主表名（资产 / 负债二选一）。
  /// 【使用限制】只读派生；side 非 asset 即 liability。
  /// 【入参与结果】无入参；返回 'az_assets' 或 'az_liabilities'。
  /// 【异常与调用方处理】不抛异常；调用方不得拿返回值拼 SQL 表名以外的用途。
  String get mainTable => side == 'asset' ? 'az_assets' : 'az_liabilities';

  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】返回主表里写死本类型的那一列（asset_class / liability_type）。
  /// 【使用限制】只读派生；写入时由 AzWriteController 统一填，不允许表单覆盖。
  /// 【入参与结果】无入参；返回列名字符串。
  /// 【异常与调用方处理】不抛异常；调用方不得把该列暴露给用户输入。
  String get discriminatorColumn => side == 'asset' ? 'asset_class' : 'liability_type';
}

/// 一个「类型组」：home 页按它分类整理，组内再按具体类型分块。
/// 【所属模块】database/ledger · 资债元数据
/// 【实现功能】定义分组的键、中文名、属于资产还是负债、以及组内成员类型编码；home 页按此顺序渲染。
/// 【使用限制】不可变；members 里的编码必须都在 AzSchema.types 中登记；顺序即展示顺序。
/// 【入参与结果】构造收 key / label / side / members；消费方只读字段。
/// 【异常与调用方处理】不抛异常；成员未登记时调用方应跳过而非渲染空块。
class AzTypeGroup {
  const AzTypeGroup({
    required this.key,
    required this.label,
    required this.side,
    required this.members,
  });

  final String key;
  final String label;
  final String side;
  final List<String> members;
}

/// 资债模块的唯一元数据入口：类型组、类型、以及 32 张表的列清单。
/// 【所属模块】database/ledger · 资债元数据
/// 【实现功能】登记 home 页的 4 个资产类型组 / 2 个负债类型组、11 个具体类型、以及从草案 DDL 逐列解析出的表字段清单；提供按类型取列的查询方法。
/// 【使用限制】全部为编译期常量，不读库、不缓存；表名只能取自 allTables；枚举值不写 CHECK，由本类列全后交业务层校验。
/// 【入参与结果】静态常量 groups / types / tableColumns / allTables；方法 byCode / bySubTable / columnsFor / editableColumns 收字符串或 AzTypeSpec，返回不可变列表。
/// 【异常与调用方处理】byCode 未登记返回 null、columnsFor 未登记返回空表，均不抛异常；调用方必须判空 / 判空列表后再渲染或写库，不得把 null 当有效类型使用。
class AzSchema {
  const AzSchema._();

  /// home 页分组顺序：资产 4 组 + 负债 2 组。
  static const List<AzTypeGroup> groups = <AzTypeGroup>[
    AzTypeGroup(key: 'lend', label: '钱借出去', side: 'asset', members: <String>['A3']),
    AzTypeGroup(key: 'invest', label: '投资类', side: 'asset', members: <String>['A4', 'A5', 'A6']),
    AzTypeGroup(key: 'real', label: '实物类', side: 'asset', members: <String>['A7', 'A8', 'A9']),
    AzTypeGroup(key: 'business', label: '经营与其他', side: 'asset', members: <String>['A10', 'A11']),
    AzTypeGroup(key: 'loan', label: '贷款', side: 'liability', members: <String>['贷款']),
    AzTypeGroup(key: 'installment', label: '分期', side: 'liability', members: <String>['分期']),
  ];

  /// 11 个具体类型（A1 / A2 是历史空号，不登记）。
  static const List<AzTypeSpec> types = <AzTypeSpec>[
    AzTypeSpec(code: 'A3', label: '借出的钱', subTable: 'az_asset_loan', groupKey: 'lend', side: 'asset'),
    AzTypeSpec(code: 'A4', label: '股票', subTable: 'az_asset_stock', groupKey: 'invest', side: 'asset'),
    AzTypeSpec(code: 'A5', label: '基金', subTable: 'az_asset_fund', groupKey: 'invest', side: 'asset'),
    AzTypeSpec(code: 'A6', label: '别的投资', subTable: 'az_asset_other_invest', groupKey: 'invest', side: 'asset'),
    AzTypeSpec(code: 'A7', label: '房产', subTable: 'az_asset_property', groupKey: 'real', side: 'asset'),
    AzTypeSpec(code: 'A8', label: '车辆', subTable: 'az_asset_vehicle', groupKey: 'real', side: 'asset'),
    AzTypeSpec(code: 'A9', label: '贵重物', subTable: 'az_asset_valuable', groupKey: 'real', side: 'asset'),
    AzTypeSpec(code: 'A10', label: '生意', subTable: 'az_asset_business', groupKey: 'business', side: 'asset'),
    AzTypeSpec(code: 'A11', label: '其他', subTable: 'az_asset_misc', groupKey: 'business', side: 'asset'),
    AzTypeSpec(code: '贷款', label: '贷款', subTable: 'az_liability_loan', groupKey: 'loan', side: 'liability'),
    AzTypeSpec(code: '分期', label: '分期', subTable: 'az_liability_installment', groupKey: 'installment', side: 'liability'),
  ];

  static const List<String> allTables = <String>[
    'az_assets',
    'az_asset_loan',
    'az_asset_loan_interest',
    'az_asset_loan_repay',
    'az_asset_stock',
    'az_asset_stock_buy',
    'az_asset_stock_sell',
    'az_asset_stock_sell_fill',
    'az_asset_stock_dividend',
    'az_asset_fund',
    'az_asset_fund_buy',
    'az_asset_fund_sell',
    'az_asset_fund_sell_fill',
    'az_asset_fund_dividend',
    'az_asset_other_invest',
    'az_asset_property',
    'az_asset_property_rent_record',
    'az_asset_property_income_record',
    'az_asset_vehicle',
    'az_asset_vehicle_rent_record',
    'az_asset_valuable',
    'az_asset_valuable_buy',
    'az_asset_valuable_sell',
    'az_asset_business',
    'az_asset_business_income_record',
    'az_asset_misc',
    'az_liabilities',
    'az_liability_loan',
    'az_liability_loan_repay',
    'az_liability_loan_draw',
    'az_liability_installment',
    'az_liability_installment_repay',
  ];

  /// 表名 → 列清单（逐字从草案 DDL 解析，含系统列，供详情展示与写库校验）。
  static const Map<String, List<AzColumn>> tableColumns = <String, List<AzColumn>>{
    'az_assets': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('book_id', '账本 id', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('asset_class', '资产类型', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A10', 'A11']),
      const AzColumn('name', '名称', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('icon_key', '图标', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('note', '说明', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('total_gain', '总收益', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('link_account_id', '关联账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('sort_order', '排序', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('archived', '归档状态', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('deleted_at', '删除时间', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('delete_reason', '删除原因', 'TEXT', required: false, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_loan': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('amount', '金额', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('repaid_amount', '实还金额', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('confirmed_repaid', '确认收回', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('lent_at', '借出日期', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('due_at', '应还日', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('has_interest', '是否有息', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('annual_rate', '年利率（小数）', 'REAL', required: false, kind: AzInputKind.money),
      const AzColumn('voucher_note', '凭证备注', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('repay_state', '回收状态', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_loan_interest': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('period', '周期', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('due_at', '应还日', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('amount', '金额', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('state', '状态', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['pending', 'paid', 'overdue', 'cancelled']),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_loan_repay': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('repaid_at', '实际还款时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('method', '方式', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('principal_part', '本期本金', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('interest_part', '本期利息', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('note', '说明', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_stock': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('code', '代码', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('cost_price', '成本单价', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('total_quantity', '总数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('total_commission', '累计佣金', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('current_price', '当前单价', 'TEXT', required: false, kind: AzInputKind.text),
      const AzColumn('total_stamp_tax', '累计印花税', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('total_dividend_tax', '累计红利税', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('confirmed_income', '确认收入', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('total_cost', '总成本', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_stock_buy': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('buy_price', '买入单价', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('buy_quantity', '买入数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('remaining_quantity', '剩余数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('buy_fee', '买入手续费', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('sell_state', '卖出状态', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_stock_sell': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sell_price', '卖出单价', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('sell_quantity', '卖出数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('sell_fee', '卖出手续费', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_stock_sell_fill': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sell_id', '卖出记录 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('buy_id', '买入批次 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('quantity', '数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_stock_dividend': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('dividend_method', '分红方式', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('dividend_cash', '现金分红', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_fund': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('code', '代码', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('default_account_id', '默认账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('current_nav', '当前净值', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('quantity', '数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('cost_nav', '成本净值', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('fee_rate', '费率', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('total_redemption_fee', '累计赎回费', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('has_lock_period', '是否有封闭期', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('lock_value', '封闭期数值', 'REAL', required: false, kind: AzInputKind.text),
      const AzColumn('lock_unit', '封闭期单位', 'TEXT', required: false, kind: AzInputKind.text),
      const AzColumn('confirmed_income', '确认收入', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('total_cost', '总成本', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_fund_buy': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('buy_nav', '买入净值', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('buy_quantity', '买入数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('buy_fee_rate', '买入费率', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('debit_account_id', '扣款账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_fund_sell': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sell_nav', '卖出净值', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('sell_quantity', '卖出数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('redemption_fee', '赎回费', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('credit_account_id', '到账账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_fund_sell_fill': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sell_id', '卖出记录 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('buy_id', '买入批次 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('quantity', '数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_fund_dividend': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('nav_before', '除权前净值', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('nav_after', '除权后净值', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('dividend_amount', '分红金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('credit_account_id', '到账账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_other_invest': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('code', '代码', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('invest_amount', '投入金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('due_at', '应还日', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('cycle_value', '周期数值', 'REAL', required: false, kind: AzInputKind.text),
      const AzColumn('cycle_unit', '周期单位', 'TEXT', required: false, kind: AzInputKind.text),
      const AzColumn('income_amount', '收入金额', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('annual_rate', '年利率（小数）', 'REAL', required: false, kind: AzInputKind.money),
      const AzColumn('account_id', '账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_property': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('purchase_amount', '购入金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('renovation_amount', '装修花费', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('current_value', '当前估值', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('bought_at', '购入日期', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('use_mode', '使用方式', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('monthly_rent', '月租金', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('mortgage_state', '抵押状态', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_property_rent_record': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('period', '周期', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('rent_amount', '租金金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('state', '状态', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['pending', 'paid', 'overdue', 'cancelled']),
      const AzColumn('received_at', '到账时间', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_property_income_record': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('period', '周期', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('income_amount', '收入金额', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('note', '说明', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_vehicle': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('purchase_amount', '购入金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('current_value', '当前估值', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('bought_at', '购入日期', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('mortgage_state', '抵押状态', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_vehicle_rent_record': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('period', '周期', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('rent_amount', '租金金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('received_at', '到账时间', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_valuable': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('total_cost', '总成本', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('current_quantity', '当前数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('current_unit_price', '当前单价', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('total_income', '累计收入', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('confirmed_income', '确认收入', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_valuable_buy': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('unit_price', '单价', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('quantity', '数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('total_amount', '总金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('occurred_at', '发生时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_valuable_sell': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('unit_price', '单价', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('quantity', '数量', 'REAL', required: true, kind: AzInputKind.text),
      const AzColumn('total_amount', '总金额', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('occurred_at', '发生时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_business': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('invest_amount', '投入金额', 'TEXT', required: false, kind: AzInputKind.text),
      const AzColumn('share_ratio', '份额比例', 'REAL', required: false, kind: AzInputKind.text),
      const AzColumn('current_value', '当前估值', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_business_income_record': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_asset_id', '关联资产次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('amount', '金额', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('occurred_at', '发生时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_asset_misc': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('asset_id', '关联资产 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('cost', '成本', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('current_value', '当前估值', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_liabilities': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('book_id', '账本 id', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('liability_type', '负债类型', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['贷款', '分期']),
      const AzColumn('icon_key', '图标', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('name', '名称', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('note', '说明', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('link_account_id', '关联账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('total_loss', '总亏损', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('start_date', '起始日（时间戳）', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('end_date', '到期日（时间戳）', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('status', '状态', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['normal', 'overdue', 'settled']),
      const AzColumn('sort_order', '排序', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('archived', '归档状态', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('deleted_at', '删除时间', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('delete_reason', '删除原因', 'TEXT', required: false, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_liability_loan': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('liability_id', '关联负债 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('loan_amount', '贷款金额（本金）', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('actual_received_amount', '实际到账金额', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('service_fee', '服务费', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('remaining_principal', '剩余待还本金', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('repay_method', '还款方式', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['equal_principal', 'equal_installment', 'interest_first', 'lump_sum', 'revolving']),
      const AzColumn('annual_rate', '年利率（小数）', 'REAL', required: false, kind: AzInputKind.money),
      const AzColumn('overdue_penalty_rate', '逾期罚息率', 'REAL', required: true, kind: AzInputKind.money),
      const AzColumn('repay_day', '每期还款日', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('paid_terms', '已还期数', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('total_terms', '总期数', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('term_unit', '期数单位', 'TEXT', required: false, kind: AzInputKind.choice, options: const <String>['month', 'quarter', 'year', 'day', 'week']),
      const AzColumn('prepay_penalty_rate', '提前还款违约金率', 'REAL', required: true, kind: AzInputKind.money),
      const AzColumn('has_collateral', '是否有抵押', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('link_asset_id', '抵押资产 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_liability_loan_repay': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('liability_id', '关联负债 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_liability_id', '关联负债次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('record_source', '记录来源', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['auto', 'user']),
      const AzColumn('term_no', '第几期', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('due_at', '应还日', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('principal_part', '本期本金', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('interest_part', '本期利息', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('remaining_after', '还完后剩余本金', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('fee', '本期费用', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('penalty_amount', '本笔费用合计', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('state', '状态', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['pending', 'paid', 'overdue', 'cancelled']),
      const AzColumn('repaid_at', '实际还款时间', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('repaid_amount', '实还金额', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('repay_account_id', '还款账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('manual_adjusted', '人工调整标记', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('note', '说明', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_liability_loan_draw': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('liability_id', '关联负债 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_liability_id', '关联负债次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('draw_amount', '支取金额', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('drawn_at', '支取时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('note', '说明', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_liability_installment': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('liability_id', '关联负债 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('installment_amount', '分期总额', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('remaining_principal', '剩余待还本金', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('total_terms', '总期数', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('paid_terms', '已还期数', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('repay_day', '每期还款日', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('annual_rate', '年利率（小数）', 'REAL', required: false, kind: AzInputKind.money),
      const AzColumn('per_term_fee_rate', '每期手续费率', 'REAL', required: false, kind: AzInputKind.money),
      const AzColumn('overdue_penalty_rate', '逾期罚息率', 'REAL', required: true, kind: AzInputKind.money),
      const AzColumn('mount_creditcard_id', '挂载信用卡 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
    'az_liability_installment_repay': <AzColumn>[
      const AzColumn('id', '记录 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('liability_id', '关联负债 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('sub_liability_id', '关联负债次表 id', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('record_source', '记录来源', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['auto', 'user']),
      const AzColumn('term_no', '第几期', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('due_at', '应还日', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('principal_part', '本期本金', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('interest_part', '本期利息', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('remaining_after', '还完后剩余本金', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('fee', '本期费用', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('penalty_amount', '本笔费用合计', 'TEXT', required: true, kind: AzInputKind.money),
      const AzColumn('settle_rule', '提前结清规则', 'TEXT', required: false, kind: AzInputKind.choice, options: const <String>['waive_unbilled', 'charge_all_remaining', 'charge_one_more', 'ratio_of_remaining', 'extra_service_fee']),
      const AzColumn('settle_rule_ratio', '结清比例', 'REAL', required: false, kind: AzInputKind.money),
      const AzColumn('settle_service_fee', '结清服务费', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('state', '状态', 'TEXT', required: true, kind: AzInputKind.choice, options: const <String>['pending', 'paid', 'overdue', 'cancelled']),
      const AzColumn('repaid_at', '实际还款时间', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('repaid_amount', '实还金额', 'TEXT', required: false, kind: AzInputKind.money),
      const AzColumn('repay_account_id', '还款账户 id', 'INTEGER', required: false, kind: AzInputKind.integer),
      const AzColumn('manual_adjusted', '人工调整标记', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('note', '说明', 'TEXT', required: true, kind: AzInputKind.text),
      const AzColumn('created_at', '创建时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('updated_at', '更新时间', 'INTEGER', required: true, kind: AzInputKind.integer),
      const AzColumn('revision', '版本号', 'INTEGER', required: true, kind: AzInputKind.integer),
    ],
  };

  /// 附属表 → 中文标题。
  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】详情页「关联记录」按表分块时用它取中文标题，不再把 DDL 表名直接摆给用户。
  /// 【使用限制】只读常量；键必须来自 allTables；未登记时 tableLabel 原样返回表名。
  /// 【入参与结果】静态常量 tableLabels；tableLabel 收表名返回中文标题。
  /// 【异常与调用方处理】不抛异常；未登记表名由调用方按原表名兜底，不得渲染成空标题。
  static const Map<String, String> tableLabels = <String, String>{
    'az_assets': '资产',
    'az_asset_loan': '借出的钱',
    'az_asset_loan_interest': '借出利息记录',
    'az_asset_loan_repay': '借出还款记录',
    'az_asset_stock': '股票',
    'az_asset_stock_buy': '股票买入批次',
    'az_asset_stock_sell': '股票卖出记录',
    'az_asset_stock_sell_fill': '股票卖出分摊',
    'az_asset_stock_dividend': '股票分红记录',
    'az_asset_fund': '基金',
    'az_asset_fund_buy': '基金买入记录',
    'az_asset_fund_sell': '基金卖出记录',
    'az_asset_fund_sell_fill': '基金卖出分摊',
    'az_asset_fund_dividend': '基金分红记录',
    'az_asset_other_invest': '其他投资',
    'az_asset_property': '房产',
    'az_asset_property_rent_record': '房产出租记录',
    'az_asset_property_income_record': '房产收入记录',
    'az_asset_vehicle': '车辆',
    'az_asset_vehicle_rent_record': '车辆出租记录',
    'az_asset_valuable': '贵重物',
    'az_asset_valuable_buy': '贵重物买入记录',
    'az_asset_valuable_sell': '贵重物卖出记录',
    'az_asset_business': '生意',
    'az_asset_business_income_record': '生意收入记录',
    'az_asset_misc': '其他资产',
    'az_liabilities': '负债',
    'az_liability_loan': '贷款',
    'az_liability_loan_repay': '贷款还款记录',
    'az_liability_loan_draw': '贷款支取记录',
    'az_liability_installment': '分期',
    'az_liability_installment_repay': '分期还款记录',
  };

  static String tableLabel(String table) => tableLabels[table] ?? table;

  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】按类型编码反查 AzTypeSpec（A3~A11 / 贷款 / 分期）。
  /// 【使用限制】只读；未登记编码返回 null，不得强转。
  /// 【入参与结果】收 code 字符串；返回 AzTypeSpec?，调用方必须判空。
  /// 【异常与调用方处理】不抛异常；调用方拿到 null 时应提示「类型未登记」并终止新增流程。
  static AzTypeSpec? byCode(String code) {
    for (final AzTypeSpec t in types) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】按次表名反查所属类型，详情反查次表行时用。
  /// 【使用限制】只读；未登记表名返回 null。
  /// 【入参与结果】收 subTable 字符串；返回 AzTypeSpec?。
  /// 【异常与调用方处理】不抛异常；调用方判空后按「无次表详情」展示。
  static AzTypeSpec? bySubTable(String subTable) {
    for (final AzTypeSpec t in types) {
      if (t.subTable == subTable) return t;
    }
    return null;
  }

  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】取某张表的全部列（含系统列），未登记返回空列表。
  /// 【使用限制】只读；返回值不可修改。
  /// 【入参与结果】收 table 字符串；返回 List<AzColumn>。
  /// 【异常与调用方处理】不抛异常；调用方需判断 isEmpty 再渲染。
  static List<AzColumn> columnsFor(String table) =>
      tableColumns[table] ?? const <AzColumn>[];

  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】取某张表在动态表单里允许录入的列：剔除系统列、外键、留痕、软删、归档、判别列与由软件计算的汇总列。
  /// 【使用限制】只读；主表的 asset_class / liability_type 由 AzWriteController 写入，表单不得覆盖；附表不进新增表单。
  /// 【入参与结果】收 table 字符串；返回可录入列 List<AzColumn>。
  /// 【异常与调用方处理】不抛异常；返回空列表时调用方应只提示「该表无需录入」。
  static List<AzColumn> editableColumns(String table) {
    const Set<String> skip = <String>{
      'id', 'book_id', 'created_at', 'updated_at', 'revision', 'sort_order',
      'archived', 'deleted_at', 'delete_reason',
      'asset_id', 'liability_id', 'sub_asset_id', 'sub_liability_id',
      'asset_class', 'liability_type', 'total_gain', 'total_loss',
      'remaining_after', 'record_source', 'manual_adjusted',
      // 以下列由软件计算或维护：表单露出会造成「用户填了却不生效」的假象。
      // 实收金额 = 合同本金 − 服务费；结束日 = 起始 + 总期 × 单位；
      // 剩余本金 / 已还期数 / 状态 / 抵押状态 / 罚费都由业务层写回。
      // end_date 保留：一次性还清 / 随借随还没有总期数，必须由用户填；
      // 按期类填了也会被 normalizeLoan 按「起始 + 总期 × 单位」覆盖。
      'actual_received_amount', 'remaining_principal',
      'paid_terms', 'status', 'state', 'mortgage_state',
      'penalty_amount', 'interest_part', 'principal_part',
      'principal_due', 'repaid_at', 'repaid_amount',
    };
    return columnsFor(table)
        .where((AzColumn c) => !skip.contains(c.name))
        .toList(growable: false);
  }

  /// 【所属模块】database/ledger · 资债元数据
  /// 【实现功能】列出某个类型组下的全部类型（按 groups.members 顺序）。
  /// 【使用限制】只读；groupKey 必须是 groups 中已登记的键。
  /// 【入参与结果】收 groupKey；返回 List<AzTypeSpec>，未登记组返回空列表。
  /// 【异常与调用方处理】不抛异常；调用方判空后不渲染该组。
  static List<AzTypeSpec> typesOfGroup(String groupKey) {
    for (final AzTypeGroup g in groups) {
      if (g.key != groupKey) continue;
      final List<AzTypeSpec> out = <AzTypeSpec>[];
      for (final String code in g.members) {
        final AzTypeSpec? t = byCode(code);
        if (t != null) out.add(t);
      }
      return out;
    }
    return const <AzTypeSpec>[];
  }
}
