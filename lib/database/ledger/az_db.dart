import 'package:sqflite/sqflite.dart';

import '../db_module.dart';

/// 资产与负债模块建表（按《资产表结构草案.md》当前版本，共 32 张表 / 24 个 SQL 块）。
///
/// 旧实现（7 张表、40 列大主表与版本化还款计划）已整体删除；
/// 本文件只留新草案的三级结构：资产主表 + 9 张次表 + 16 张附属表，
/// 负债主表 + 2 张次表 + 3 张附表。全库一次性重建，不做旧数据迁移。
/// 【所属模块】database/ledger · 资债 Schema
/// 【实现功能】作为 DbModule 登记进 DatabaseService._onCreate，一次建齐 32 张表与全部索引；DDL 逐字取自草案，不写 CHECK 约束枚举取值。
/// 【使用限制】只由 _onCreate 传入的 DatabaseExecutor 调用，不自建事务、不在 _onUpgrade 补建；表名常量是 EntityKind 与 DAO 的唯一真源，不得在别处拼字符串。
/// 【入参与结果】create / onCreate 收 DatabaseExecutor db；返回 Future<void>，必须 await；建表失败原样上抛，由 DatabaseService 打印并 rethrow。
/// 【异常与调用方处理】SQL 语法错误、表已存在但结构不符、磁盘 IO 异常均上抛；调用方（DatabaseService._onCreate）在同一事务里整体回滚，需自行 try/catch 并提示初始化失败，不得吞掉后继续启动。
class AzDb implements DbModule {
  static const String az_assets = 'az_assets';
  static const String az_asset_loan = 'az_asset_loan';
  static const String az_asset_loan_interest = 'az_asset_loan_interest';
  static const String az_asset_loan_repay = 'az_asset_loan_repay';
  static const String az_asset_stock = 'az_asset_stock';
  static const String az_asset_stock_buy = 'az_asset_stock_buy';
  static const String az_asset_stock_sell = 'az_asset_stock_sell';
  static const String az_asset_stock_sell_fill = 'az_asset_stock_sell_fill';
  static const String az_asset_stock_dividend = 'az_asset_stock_dividend';
  static const String az_asset_fund = 'az_asset_fund';
  static const String az_asset_fund_buy = 'az_asset_fund_buy';
  static const String az_asset_fund_sell = 'az_asset_fund_sell';
  static const String az_asset_fund_sell_fill = 'az_asset_fund_sell_fill';
  static const String az_asset_fund_dividend = 'az_asset_fund_dividend';
  static const String az_asset_other_invest = 'az_asset_other_invest';
  static const String az_asset_property = 'az_asset_property';
  static const String az_asset_property_rent_record = 'az_asset_property_rent_record';
  static const String az_asset_property_income_record = 'az_asset_property_income_record';
  static const String az_asset_vehicle = 'az_asset_vehicle';
  static const String az_asset_vehicle_rent_record = 'az_asset_vehicle_rent_record';
  static const String az_asset_valuable = 'az_asset_valuable';
  static const String az_asset_valuable_buy = 'az_asset_valuable_buy';
  static const String az_asset_valuable_sell = 'az_asset_valuable_sell';
  static const String az_asset_business = 'az_asset_business';
  static const String az_asset_business_income_record = 'az_asset_business_income_record';
  static const String az_asset_misc = 'az_asset_misc';
  static const String az_liabilities = 'az_liabilities';
  static const String az_liability_loan = 'az_liability_loan';
  static const String az_liability_loan_repay = 'az_liability_loan_repay';
  static const String az_liability_loan_draw = 'az_liability_loan_draw';
  static const String az_liability_installment = 'az_liability_installment';
  static const String az_liability_installment_repay = 'az_liability_installment_repay';
  static const String assetsTable = 'az_assets';
  static const String liabilitiesTable = 'az_liabilities';

  @override
  String get name => 'ledger';

  /// 【所属模块】database/ledger · 资债 Schema
  /// 【实现功能】DbModule 装配入口，转调 [create] 建齐本模块全部表。
  /// 【使用限制】只在全库 _onCreate 事务内调用；不得在升级路径调用。
  /// 【入参与结果】收 DatabaseExecutor db；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】DDL 异常原样上抛并由外层事务回滚；调用方需自行 try/catch 提示建库失败。
  @override
  Future<void> onCreate(DatabaseExecutor db) => create(db);

  /// 【所属模块】database/ledger · 资债 Schema
  /// 【实现功能】按草案顺序执行 24 个 SQL 块拆出的全部 CREATE TABLE / CREATE INDEX 语句，一次建齐 32 张表与索引。
  /// 【使用限制】不自建事务；枚举不写 CHECK，取值合法性由业务层与 AzSchema 校验；金额列为 TEXT 十进制字符串，不得用 REAL 覆盖。
  /// 【入参与结果】收 DatabaseExecutor db（通常是 _onCreate 的 txn）；返回 Future<void>，调用方必须 await；无返回值，建表结果以 sqlite_master 为准。
  /// 【异常与调用方处理】任一语句失败上抛 DatabaseException，外层事务整体回滚；调用方需自行 try/catch 并提示初始化失败，不能继续使用半套 Schema。
  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS az_assets (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id          TEXT    NOT NULL DEFAULT 'default',
  asset_class      TEXT    NOT NULL,  -- A3~A11，决定去哪张次表
  name             TEXT    NOT NULL,
  icon_key         TEXT    NOT NULL DEFAULT 'other',
  note             TEXT    NOT NULL DEFAULT '',
  total_gain       TEXT    NOT NULL DEFAULT '0',  -- 总收益（收益值，不是收入值；收益值 = 收入值 − 成本值），各类公用
  link_account_id  INTEGER,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  archived         INTEGER NOT NULL DEFAULT 0,  -- 允许值：0/1（0=否，1=是）
  deleted_at       INTEGER,
  delete_reason    TEXT,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS uq_az_assets_active_name
  ON az_assets (book_id, name) WHERE deleted_at IS NULL;''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_assets_list
  ON az_assets (book_id, deleted_at, asset_class, sort_order, id);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_loan (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id       INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  amount    TEXT    NOT NULL CHECK (CAST(amount AS REAL) > 0),  -- 借了多少
  repaid_amount      TEXT    NOT NULL DEFAULT '0' CHECK (CAST(repaid_amount AS REAL) >= 0),  -- 已还金额
  confirmed_repaid   TEXT    NOT NULL DEFAULT '0' CHECK (CAST(confirmed_repaid AS REAL) >= 0),  -- 确认收回：借款人累计已实际还回、且确认到账的全部钱（本金部分+利息部分）= Σ(principal_part+interest_part)；定义见标注 6
  lent_at        INTEGER,  -- 哪天借
  due_at         INTEGER,  -- 说好什么时候还，可空
  has_interest   INTEGER NOT NULL DEFAULT 0,  -- 是否计息，新增时选；允许值：0/1（0=否，1=是）
  annual_rate    REAL    CHECK (annual_rate IS NULL OR annual_rate >= 0),  -- 年利率，5% 写 0.05；不计息留空
  voucher_note   TEXT    NOT NULL DEFAULT '',  -- 借条 / 转账凭证
  -- 状态：详情阶段用，新增不填
  repay_state    TEXT    NOT NULL DEFAULT 'normal',  -- 正常/部分收回/已收回/可能收不回
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  revision       INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_loan_interest (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_loan.id（次表主键）
  period        TEXT    NOT NULL,  -- 哪个月，'2026-12'
  due_at        INTEGER,  -- 到这天转「待还」
  amount        TEXT    NOT NULL CHECK (CAST(amount AS REAL) >= 0),  -- 这月利息，生成时算定，往期不重算
  state         TEXT    NOT NULL DEFAULT 'inactive',  -- 未生效 / 待还 / 已还
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_loan_interest_asset
  ON az_asset_loan_interest (asset_id, period);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_loan_repay (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id        INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id    INTEGER NOT NULL,  -- → az_asset_loan.id（次表主键）
  repaid_at       INTEGER NOT NULL,  -- 哪天还的
  method          TEXT    NOT NULL,  -- 还本金 / 还本息
  principal_part  TEXT    NOT NULL DEFAULT '0' CHECK (CAST(principal_part AS REAL) >= 0),  -- 这次还了多少本金
  interest_part   TEXT    NOT NULL DEFAULT '0' CHECK (CAST(interest_part AS REAL) >= 0),  -- 这次还了多少利息
  note            TEXT    NOT NULL DEFAULT '',
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_loan_repay_asset
  ON az_asset_loan_repay (asset_id, repaid_at);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_stock (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  code              TEXT    NOT NULL DEFAULT '',  -- 同码禁止二次新增
  cost_price        TEXT    NOT NULL CHECK (CAST(cost_price AS REAL) > 0),  -- 成本价，每股
  total_quantity    REAL    NOT NULL CHECK (total_quantity > 0),  -- 总数，股数
  total_commission  TEXT    NOT NULL DEFAULT '0' CHECK (CAST(total_commission AS REAL) >= 0),  -- 总佣金
  current_price     TEXT    CHECK (current_price IS NULL OR CAST(current_price AS REAL) > 0),  -- 当前价，没有就空着
  total_stamp_tax   TEXT    NOT NULL DEFAULT '0' CHECK (CAST(total_stamp_tax AS REAL) >= 0),  -- 总印花税
  total_dividend_tax TEXT  NOT NULL DEFAULT '0' CHECK (CAST(total_dividend_tax AS REAL) >= 0),  -- 总红利税
  confirmed_income  TEXT    NOT NULL DEFAULT '0' CHECK (CAST(confirmed_income AS REAL) >= 0),  -- 确认收入
  total_cost        TEXT    NOT NULL DEFAULT '0' CHECK (CAST(total_cost AS REAL) >= 0),  -- 总成本
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  revision          INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_stock_buy (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id            INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id        INTEGER NOT NULL,  -- → az_asset_stock.id（次表主键）
  buy_price           TEXT    NOT NULL CHECK (CAST(buy_price AS REAL) > 0),  -- 买入价
  buy_quantity        REAL    NOT NULL CHECK (buy_quantity > 0),  -- 买入数量
  remaining_quantity  REAL    NOT NULL CHECK (remaining_quantity >= 0),  -- 剩余数量
  buy_fee             TEXT    NOT NULL DEFAULT '0' CHECK (CAST(buy_fee AS REAL) >= 0),  -- 买入费用
  sell_state          TEXT    NOT NULL DEFAULT 'unsold',  -- 未卖出 / 部分卖出 / 全部卖出
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_stock_sell (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id        INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id    INTEGER NOT NULL,  -- → az_asset_stock.id（次表主键）
  sell_price      TEXT    NOT NULL CHECK (CAST(sell_price AS REAL) > 0),  -- 卖出价
  sell_quantity   REAL    NOT NULL CHECK (sell_quantity > 0),  -- 卖出数量
  sell_fee        TEXT    NOT NULL DEFAULT '0' CHECK (CAST(sell_fee AS REAL) >= 0),  -- 卖出费用
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_stock_sell_fill (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_stock.id（次表主键）
  sell_id       INTEGER NOT NULL,  -- 哪笔卖出
  buy_id        INTEGER NOT NULL,  -- 挂到哪笔买入
  quantity      REAL    NOT NULL CHECK (quantity > 0),  -- 从这笔买入消耗了多少,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_stock_dividend (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id        INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id    INTEGER NOT NULL,  -- → az_asset_stock.id（次表主键）
  dividend_method TEXT    NOT NULL,  -- 分红方式：10派1元 / 10转3股 / 10送3股 …
  dividend_cash   TEXT    NOT NULL DEFAULT '0' CHECK (CAST(dividend_cash AS REAL) >= 0),  -- 分红现金，没有就 0
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_stock_buy_asset
  ON az_asset_stock_buy (asset_id, created_at);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_stock_sell_fill
  ON az_asset_stock_sell_fill (sell_id, buy_id);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_fund (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id              INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  code                  TEXT    NOT NULL DEFAULT '',  -- 同码禁止二次新增
  default_account_id    INTEGER,  -- 默认交易账户，买卖记录里可覆盖
  current_nav           TEXT    NOT NULL CHECK (CAST(current_nav AS REAL) > 0),  -- 当前净值
  quantity              REAL    NOT NULL CHECK (quantity > 0),  -- 数量，份额可小数
  cost_nav              TEXT    NOT NULL CHECK (CAST(cost_nav AS REAL) > 0),  -- 成本净值
  fee_rate              REAL    NOT NULL DEFAULT 0 CHECK (fee_rate >= 0),  -- 费率，5% 写 0.05
  total_redemption_fee  TEXT    NOT NULL DEFAULT '0' CHECK (CAST(total_redemption_fee AS REAL) >= 0),  -- 总赎回费
  has_lock_period       INTEGER NOT NULL DEFAULT 0,  -- 是否有锁定期；允许值：0/1（0=否，1=是）
  lock_value            REAL    CHECK (lock_value IS NULL OR lock_value > 0),  -- 锁定期数值
  lock_unit             TEXT,  -- 单位：天/月/年；允许值：day/month/year（可空）
  confirmed_income      TEXT    NOT NULL DEFAULT '0' CHECK (CAST(confirmed_income AS REAL) >= 0),  -- 确认收入
  total_cost            TEXT    NOT NULL DEFAULT '0' CHECK (CAST(total_cost AS REAL) >= 0),  -- 总成本
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL,
  revision              INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_fund_buy (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id      INTEGER NOT NULL,  -- → az_asset_fund.id（次表主键）
  buy_nav           TEXT    NOT NULL CHECK (CAST(buy_nav AS REAL) > 0),  -- 买入净值
  buy_quantity      REAL    NOT NULL CHECK (buy_quantity > 0),  -- 买入数量，份额可小数
  buy_fee_rate      REAL    NOT NULL DEFAULT 0 CHECK (buy_fee_rate >= 0),  -- 买入费率
  debit_account_id  INTEGER,  -- 扣款账户
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_fund_sell (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id      INTEGER NOT NULL,  -- → az_asset_fund.id（次表主键）
  sell_nav          TEXT    NOT NULL CHECK (CAST(sell_nav AS REAL) > 0),  -- 卖出净值
  sell_quantity     REAL    NOT NULL CHECK (sell_quantity > 0),  -- 卖出数量
  redemption_fee    TEXT    NOT NULL DEFAULT '0' CHECK (CAST(redemption_fee AS REAL) >= 0),  -- 赎回费
  credit_account_id INTEGER,  -- 到账账户
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_fund_sell_fill (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_fund.id（次表主键）
  sell_id       INTEGER NOT NULL,  -- 哪笔卖出
  buy_id        INTEGER NOT NULL,  -- 挂到哪笔买入
  quantity      REAL    NOT NULL CHECK (quantity > 0),  -- 从这笔买入消耗了多少,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_fund_dividend (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id      INTEGER NOT NULL,  -- → az_asset_fund.id（次表主键）
  nav_before        TEXT    NOT NULL CHECK (CAST(nav_before AS REAL) > 0),  -- 分红前基金净值
  nav_after         TEXT    NOT NULL CHECK (CAST(nav_after AS REAL) > 0),  -- 分红后基金净值
  dividend_amount   TEXT    NOT NULL DEFAULT '0' CHECK (CAST(dividend_amount AS REAL) >= 0),  -- 分红金额
  credit_account_id INTEGER,  -- 到账账户
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_fund_buy_asset
  ON az_asset_fund_buy (asset_id, created_at);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_fund_sell_asset
  ON az_asset_fund_sell (asset_id, created_at);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_fund_dividend_asset
  ON az_asset_fund_dividend (asset_id, created_at);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_fund_sell_fill
  ON az_asset_fund_sell_fill (sell_id, buy_id);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_other_invest (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  code              TEXT    NOT NULL DEFAULT '',  -- 同码禁止二次新增；与 A4（股票）/ A5（基金）一致
  invest_amount     TEXT    NOT NULL CHECK (CAST(invest_amount AS REAL) > 0),  -- 投入金额
  due_at            INTEGER,  -- 到期日
  cycle_value       REAL    CHECK (cycle_value IS NULL OR cycle_value > 0),  -- 周期数值，如 6 / 1
  cycle_unit        TEXT,  -- 周期单位；允许值：day/month/year（可空）
  income_amount     TEXT    CHECK (income_amount IS NULL OR CAST(income_amount AS REAL) > 0),  -- 收入金额，到期拿回多少
  annual_rate       REAL    CHECK (annual_rate IS NULL OR annual_rate >= 0),  -- 年收益率，5% 写 0.05，可空
  account_id        INTEGER,  -- 绑定账户
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  revision          INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_property (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id            INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  purchase_amount     TEXT    NOT NULL CHECK (CAST(purchase_amount AS REAL) > 0),  -- 买入金额
  renovation_amount   TEXT    NOT NULL DEFAULT '0' CHECK (CAST(renovation_amount AS REAL) >= 0),  -- 装修金额
  current_value       TEXT    NOT NULL CHECK (CAST(current_value AS REAL) > 0),  -- 当前估值
  bought_at           INTEGER,  -- 买入时间
  use_mode            TEXT    NOT NULL DEFAULT 'self',  -- 使用方式：自用 / 出租 / 空置
  monthly_rent        TEXT    NOT NULL DEFAULT '0' CHECK (CAST(monthly_rent AS REAL) >= 0),  -- 每月租金
  -- 状态：详情阶段用，新增不填
  mortgage_state      TEXT    NOT NULL DEFAULT 'unmortgaged',  -- 允许值：unmortgaged(未抵押)/mortgaged(已抵押)；未抵押 / 已抵押
  created_at          INTEGER NOT NULL,
  updated_at          INTEGER NOT NULL,
  revision            INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_property_rent_record (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_property.id（次表主键）
  period        TEXT    NOT NULL,  -- 哪个月，'2026-12'
  rent_amount   TEXT    NOT NULL CHECK (CAST(rent_amount AS REAL) > 0),  -- 这个月租金
  state         TEXT    NOT NULL DEFAULT 'pending',  -- 待到账 / 已到账
  received_at   INTEGER,  -- 到账那天，未到账就空着
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE UNIQUE INDEX IF NOT EXISTS uq_az_property_rent_period
  ON az_asset_property_rent_record (asset_id, period);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_property_income_record (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_property.id（次表主键）
  period        TEXT    NOT NULL,  -- 周期（时长），如 '5天'
  income_amount TEXT    NOT NULL CHECK (CAST(income_amount AS REAL) > 0),  -- 总收益
  note          TEXT    NOT NULL DEFAULT '',  -- 备注，如 '做民宿'
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_property_income_asset
  ON az_asset_property_income_record (asset_id, created_at);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_vehicle (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id           INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  purchase_amount    TEXT    NOT NULL CHECK (CAST(purchase_amount AS REAL) > 0),  -- 买入金额
  current_value      TEXT    NOT NULL CHECK (CAST(current_value AS REAL) > 0),  -- 当前估值
  bought_at          INTEGER,  -- 买入时间
  -- 状态：详情阶段用，新增不填
  mortgage_state     TEXT    NOT NULL DEFAULT 'unmortgaged',  -- 允许值：unmortgaged(未抵押)/mortgaged(已抵押)；未抵押 / 已抵押
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  revision           INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_vehicle_rent_record (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_vehicle.id（次表主键）
  period        TEXT    NOT NULL,  -- 周期（时长），如 '5天'；按月汇总记时也可写 '2026-12'，两种写法按录入场景取用
  rent_amount   TEXT    NOT NULL CHECK (CAST(rent_amount AS REAL) > 0),  -- 收了多少
  received_at   INTEGER,  -- 到账那天（可选留痕，不参与收益计算），没到账就空着
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_vehicle_rent_asset
  ON az_asset_vehicle_rent_record (asset_id, period);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_valuable (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id            INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  total_cost          TEXT    NOT NULL CHECK (CAST(total_cost AS REAL) > 0),  -- 总成本
  current_quantity    REAL    NOT NULL CHECK (current_quantity > 0),  -- 当前数量，可小数
  current_unit_price  TEXT    NOT NULL CHECK (CAST(current_unit_price AS REAL) > 0),  -- 当前单价
  total_income        TEXT    NOT NULL DEFAULT '0',  -- 总收入
  confirmed_income    TEXT    NOT NULL DEFAULT '0',  -- 确认收入
  created_at          INTEGER NOT NULL,
  updated_at          INTEGER NOT NULL,
  revision            INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_valuable_buy (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_valuable.id（次表主键）
  unit_price    TEXT    NOT NULL CHECK (CAST(unit_price AS REAL) > 0),  -- 单价
  quantity      REAL    NOT NULL CHECK (quantity > 0),  -- 数量，可小数
  total_amount  TEXT    NOT NULL CHECK (CAST(total_amount AS REAL) > 0),  -- 总金额
  occurred_at   INTEGER NOT NULL,  -- 时间,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_valuable_sell (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_valuable.id（次表主键）
  unit_price    TEXT    NOT NULL CHECK (CAST(unit_price AS REAL) > 0),  -- 单价
  quantity      REAL    NOT NULL CHECK (quantity > 0),  -- 数量，可小数
  total_amount  TEXT    NOT NULL CHECK (CAST(total_amount AS REAL) > 0),  -- 总金额
  occurred_at   INTEGER NOT NULL,  -- 时间,
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_business (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  invest_amount     TEXT    CHECK (invest_amount IS NULL OR CAST(invest_amount AS REAL) >= 0),  -- 投入金额，技术投资可填 0 或空
  share_ratio       REAL    CHECK (share_ratio IS NULL OR share_ratio >= 0),  -- 所占比例，20% 写 0.2，可不填
  current_value     TEXT    CHECK (current_value IS NULL OR CAST(current_value AS REAL) > 0),  -- 当前估值，可不填
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  revision          INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_business_income_record (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id      INTEGER NOT NULL,  -- → az_assets.id（主表主键）
  sub_asset_id  INTEGER NOT NULL,  -- → az_asset_business.id（次表主键）
  amount        TEXT    NOT NULL CHECK (CAST(amount AS REAL) <> 0),  -- 正数=分红 / 卖出回款，负数=亏损或追加投入；0 不记记录
  occurred_at   INTEGER NOT NULL,  -- 哪天
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_business_income_asset
  ON az_asset_business_income_record (asset_id, occurred_at);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_asset_misc (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  asset_id          INTEGER NOT NULL UNIQUE,
  -- 数据：新增录入
  cost              TEXT    NOT NULL CHECK (CAST(cost AS REAL) >= 0),  -- 花了多少；赠与 / 免费获得可填 0
  current_value     TEXT    CHECK (current_value IS NULL OR CAST(current_value AS REAL) > 0),  -- 现在值多少，可不填
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  revision          INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_liabilities (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id          TEXT    NOT NULL DEFAULT 'default',  -- 账本分组，当前恒 'default'
  liability_type   TEXT    NOT NULL,  -- 贷款 / 分期；信用卡不进负债表
  icon_key         TEXT    NOT NULL DEFAULT 'other',  -- 图标
  name             TEXT    NOT NULL,  -- 名字
  note             TEXT    NOT NULL DEFAULT '',  -- 随便写
  link_account_id  INTEGER,  -- 绑定账户：用户用哪张卡/账户来还这笔债（贷款=放款到账/默认扣款，分期=还款账户；负债侧唯一一处）
  total_loss       TEXT    NOT NULL DEFAULT '0',  -- 总亏损：所有亏损之和 = 利息 + 费用 + 违约金 + 放款时先扣的服务费
  start_date       INTEGER,  -- 起始日；贷款 / 分期均必填（DDL 仍可空，约束在录入层）
  end_date         INTEGER,  -- 到期日；按期类禁用（由起始日+总期×单位推出），一次性还清/随借随还类可编辑
  status           TEXT    NOT NULL DEFAULT 'normal',  -- 状态：默认正常（正常/已结清/逾期…，取值由业务层管）
  sort_order       INTEGER NOT NULL DEFAULT 0,  -- 排序
  archived         INTEGER NOT NULL DEFAULT 0,  -- 归档，0/1；允许值：0/1（0=否，1=是）
  deleted_at       INTEGER,  -- 软删时间
  delete_reason    TEXT,  -- 删除原因
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  revision         INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''-- 与资产主表对称：同账本下未软删的债务名字唯一
CREATE UNIQUE INDEX IF NOT EXISTS uq_az_liabilities_active_name
  ON az_liabilities (book_id, name) WHERE deleted_at IS NULL;''');
    await db.execute('''-- 列表/筛选：账本 + 软删 + 类型 + 排序
CREATE INDEX IF NOT EXISTS idx_az_liabilities_list
  ON az_liabilities (book_id, deleted_at, liability_type, sort_order, id);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_liability_loan (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  liability_id          INTEGER NOT NULL UNIQUE,  -- → az_liabilities.id（主表主键）
  -- 数据：新增录入
  loan_amount            TEXT   NOT NULL CHECK (CAST(loan_amount AS REAL) > 0),  -- 贷款金额（合同本金）
  actual_received_amount TEXT   CHECK (actual_received_amount IS NULL OR CAST(actual_received_amount AS REAL) >= 0),  -- 实际到账金额，先扣服务费时小于合同本金
  service_fee            TEXT   NOT NULL DEFAULT '0' CHECK (CAST(service_fee AS REAL) >= 0),  -- 服务费（放款时先扣的那笔，计入主表 total_loss 亏损）
  remaining_principal    TEXT   NOT NULL CHECK (CAST(remaining_principal AS REAL) >= 0),  -- 剩余待还（待还本金）
  repay_method           TEXT   NOT NULL,  -- 允许值：equal_principal(等额本金)/equal_installment(等额本息)/interest_first(先息后本)/lump_sum(一次性还清)/revolving(随借随还)；封闭枚举：等额本金 / 等额本息 / 先息后本 / 一次性还清 / 随借随还；软件按取值选用不同公式计算每期
  annual_rate            REAL   CHECK (annual_rate IS NULL OR annual_rate >= 0),  -- 年利率，5% 写 0.05；软件按 term_unit 折算成期利率用于计算
  overdue_penalty_rate   REAL   NOT NULL DEFAULT 0 CHECK (overdue_penalty_rate >= 0),  -- 逾期罚息率（年化，合同载明的罚息利率，常为合同利率上浮 30%~50%，不是正常年利率），9% 写 0.09；软件按「逾期本金 × 率/365 × 逾期天数」算罚息，并对到期应付未付的期内利息按同率计复利
  repay_day              INTEGER,  -- 还款日：按月/季/年时填「每期第几号」；day/week 留空（due_at 由起始日按单位顺推，见标注 5）
  paid_terms             INTEGER NOT NULL DEFAULT 0,  -- 已还期数
  total_terms            INTEGER,  -- 总期数
  term_unit              TEXT   DEFAULT 'month',  -- 期数单位：day/week/month/quarter/year，默认月；无固定期数显式写 NULL。day=每 N 天、week=每周六、month/quarter/year=每月固定几号；见标注 5
  prepay_penalty_rate    REAL   NOT NULL DEFAULT 0 CHECK (prepay_penalty_rate >= 0),  -- 提前还款违约金率，5% 写 0.05；软件按「提前还本金额 × 率」计算，逐笔记在附表
  has_collateral         INTEGER NOT NULL DEFAULT 0,  -- 是否有抵押；允许值：0/1（0=否，1=是）
  link_asset_id          INTEGER,  -- 抵押资产 → az_assets.id；多笔贷款可指同一资产
  created_at             INTEGER NOT NULL,
  updated_at             INTEGER NOT NULL,
  revision               INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_liability_loan_repay (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  liability_id       INTEGER NOT NULL,  -- → az_liabilities.id（主表主键）
  sub_liability_id   INTEGER NOT NULL,  -- → az_liability_loan.id（次表主键）
  record_source      TEXT    NOT NULL DEFAULT 'auto',  -- 记录来源：auto=软件按计划生成并算好；user=用户主动发起的还款（提前还款 / 一次性类主动还），用户只填动作输入
  term_no            INTEGER,  -- 第几期；一次性还清 / 随借随还留空
  due_at             INTEGER,  -- 应还日
  -- 以下金额列由软件按次表参数计算写入，用户不填（fee 例外：由用户还款时填）
  principal_part     TEXT    NOT NULL DEFAULT '0' CHECK (CAST(principal_part AS REAL) >= 0),  -- 本期本金
  interest_part      TEXT    NOT NULL DEFAULT '0' CHECK (CAST(interest_part AS REAL) >= 0),  -- 本期利息
  remaining_after    TEXT,  -- 还完后剩余本金：生成 pending 时留空，执行还款动作算出后才填
  fee                TEXT    NOT NULL DEFAULT '0' CHECK (CAST(fee AS REAL) >= 0),  -- 本期费用：用户还款时填写，软件不预测
  penalty_amount     TEXT    NOT NULL DEFAULT '0' CHECK (CAST(penalty_amount AS REAL) >= 0),  -- 本条记录的所有额外费用/罚费合计：提前还款违约金 / 逾期罚息 / 复利等相加；构成由软件写进 note，不拆列
  state              TEXT    NOT NULL DEFAULT 'pending',  -- 状态：未还 / 已还 / 逾期 …
  repaid_at          INTEGER,  -- 实际还款时间，未还留空
  repaid_amount      TEXT,  -- 实还金额，未还留空
  repay_account_id   INTEGER,  -- 还款账户：这一期实际从哪个账户还的，未单独选沿用主表 link_account_id
  manual_adjusted    INTEGER NOT NULL DEFAULT 0,  -- 人工调整标记：软件算出的金额被人工改过=1，未改=0；允许值：0/1（0=未改，1=已人工调整）
  note               TEXT    NOT NULL DEFAULT '',  -- 说明；penalty_amount 的各项构成由软件自动追加在此（用户不用手填）
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,  -- 更新时间
  revision           INTEGER NOT NULL DEFAULT 1  -- 版本号
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_liability_loan_repay
  ON az_liability_loan_repay (liability_id, term_no);''');
    await db.execute('''-- 逾期扫描：按状态 + 应还日找待还/逾期记录
CREATE INDEX IF NOT EXISTS idx_az_liability_loan_repay_due
  ON az_liability_loan_repay (state, due_at);''');
    await db.execute('''-- 按次表反查该笔贷款的全部还款记录
CREATE INDEX IF NOT EXISTS idx_az_liability_loan_repay_sub
  ON az_liability_loan_repay (sub_liability_id);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_liability_loan_draw (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  liability_id       INTEGER NOT NULL,  -- → az_liabilities.id（主表主键）
  sub_liability_id   INTEGER NOT NULL,  -- → az_liability_loan.id（次表主键）
  draw_amount        TEXT    NOT NULL CHECK (CAST(draw_amount AS REAL) > 0),  -- 本次支取金额
  drawn_at           INTEGER NOT NULL,  -- 支取日
  note               TEXT    NOT NULL DEFAULT '',  -- 说明
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  revision           INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_liability_loan_draw
  ON az_liability_loan_draw (sub_liability_id, drawn_at);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_liability_installment (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  liability_id          INTEGER NOT NULL UNIQUE,  -- → az_liabilities.id（主表主键）
  installment_amount    TEXT   NOT NULL CHECK (CAST(installment_amount AS REAL) > 0),  -- 分期总额（订单 / 账单金额）
  remaining_principal   TEXT   NOT NULL CHECK (CAST(remaining_principal AS REAL) >= 0),  -- 剩余待还本金
  total_terms           INTEGER NOT NULL,  -- 总期数，固定 N 期、恒按月
  paid_terms            INTEGER NOT NULL DEFAULT 0,  -- 已还期数
  repay_day             INTEGER,  -- 还款日：每期第几号
  annual_rate           REAL   CHECK (annual_rate IS NULL OR annual_rate >= 0),  -- 年利率，5% 写 0.05；有息计费填，免息计费留空/0。软件按它算利息写附表 interest_part
  per_term_fee_rate     REAL   CHECK (per_term_fee_rate IS NULL OR per_term_fee_rate >= 0),  -- 每期手续费率，5% 写 0.05；软件按它算手续费写附表 fee（与年利率分开两笔）
  overdue_penalty_rate  REAL   NOT NULL DEFAULT 0 CHECK (overdue_penalty_rate >= 0),  -- 逾期罚息率（年化，合同载明的罚息利率，常为合同利率上浮 30%~50%，不是正常年利率），9% 写 0.09；软件按「逾期本金 × 率/365 × 逾期天数」算罚息，并对到期应付未付的期内利息按同率计复利
  mount_creditcard_id   INTEGER,  -- 挂载信用卡 → 账户侧信用卡账户；仅信用卡分期填，商品分期留空（关联标记）
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL,
  revision              INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE TABLE IF NOT EXISTS az_liability_installment_repay (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  liability_id       INTEGER NOT NULL,  -- → az_liabilities.id（主表主键）
  sub_liability_id   INTEGER NOT NULL,  -- → az_liability_installment.id（次表主键）
  record_source      TEXT    NOT NULL DEFAULT 'auto',  -- 记录来源：auto=软件逐期生成并算好；user=用户主动发起的提前还款记录，用户只填动作输入
  term_no            INTEGER NOT NULL,  -- 第几期：这条还款记录对应分期合同的第几期，1..total_terms；全额提前结清的 user 记录填「当期期号 = paid_terms + 1」，见标注 7
  due_at             INTEGER,  -- 应还日
  -- 以下金额列全部由软件按次表参数计算写入，用户不填（允许人工覆盖，见 manual_adjusted）
  principal_part     TEXT    NOT NULL DEFAULT '0' CHECK (CAST(principal_part AS REAL) >= 0),  -- 本期本金
  interest_part      TEXT    NOT NULL DEFAULT '0' CHECK (CAST(interest_part AS REAL) >= 0),  -- 本期利息：只由次表 annual_rate 算出；免息计费为 0
  remaining_after    TEXT,  -- 还完后剩余本金：生成 pending 时留空，执行还款动作算出后才填
  fee                TEXT    NOT NULL DEFAULT '0' CHECK (CAST(fee AS REAL) >= 0),  -- 本期手续费：只由次表 per_term_fee_rate 算出 / 软件算出的提前结清剩余手续费
  penalty_amount     TEXT    NOT NULL DEFAULT '0' CHECK (CAST(penalty_amount AS REAL) >= 0),  -- 本条记录的所有额外费用/罚费合计：提前结清违约金 / 服务费 / 逾期罚息 / 复利等相加；构成由软件写进 note，不拆列
  settle_rule        TEXT,  -- 提前结清规则名：仅 user 结清记录填（免收未出账/收齐剩余各期/只加收一期/按剩余本金比例/另收服务费）；auto 留空
  settle_rule_ratio  REAL   CHECK (settle_rule_ratio IS NULL OR settle_rule_ratio >= 0),  -- 规则输入：选「按剩余本金比例」时用户填的比例，5% 写 0.05；仅该规则用，其余规则留空
  settle_service_fee TEXT   CHECK (settle_service_fee IS NULL OR CAST(settle_service_fee AS REAL) >= 0),  -- 规则输入：选「另收一笔提前结清服务费」时用户填的金额；仅该规则用，其余规则留空
  state              TEXT    NOT NULL DEFAULT 'pending',  -- 状态：未还 / 已还 / 逾期 / 已取消（提前结清时当期计划作废）…
  repaid_at          INTEGER,  -- 实际还款时间，未还留空
  repaid_amount      TEXT,  -- 实还金额，未还留空
  repay_account_id   INTEGER,  -- 还款账户：这一期实际从哪张卡还的，未单独选沿用主表 link_account_id
  manual_adjusted    INTEGER NOT NULL DEFAULT 0,  -- 人工覆盖标记：软件算出的金额被人工改过=1；允许值：0/1（0=未改，1=已人工调整）
  note               TEXT    NOT NULL DEFAULT '',  -- 说明；penalty_amount 的各项构成由软件自动追加在此（用户不用手填）
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  revision           INTEGER NOT NULL DEFAULT 1
);''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_az_liability_installment_repay
  ON az_liability_installment_repay (liability_id, term_no);''');
    await db.execute('''-- 逾期扫描：按状态 + 应还日找待还/逾期记录
CREATE INDEX IF NOT EXISTS idx_az_liability_installment_repay_due
  ON az_liability_installment_repay (state, due_at);''');
    await db.execute('''-- 按次表反查该笔分期的全部还款记录
CREATE INDEX IF NOT EXISTS idx_az_liability_installment_repay_sub
  ON az_liability_installment_repay (sub_liability_id);''');
  }
}
