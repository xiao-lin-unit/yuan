import 'package:sqflite/sqflite.dart';

import '../db_module.dart';

/// 资债模块七张表（DB v9）。
///
/// ══════════════════════════════════════════════════════════════════
/// 【构想：两本账分开，家底账只算一次】
/// ══════════════════════════════════════════════════════════════════
/// 原型 az.js 的三条铁律全部落进表结构：
///   1. 不重复计算：A1（卡里和手上的钱）/ A2（暂时动不了的钱）**不建表**，
///      由 `accounts` 实时聚合出只读镜像；本模块只存 A3~A11 自登记资产。
///      账户是唯一写入点，这里反向引用。
///   2. 本金不算消耗：还款计划逐期把 本金 / 利息 / 手续费 **分列**存，
///      「这个月白给银行多少」= Σ(interest + fee)，不含 principal。
///   3. 同屏可核对：每个总数都能下钻到明细；展开的算法逐项由 [AzMath] 算，
///      页面不写死任何金额。
///
/// 【为什么是七张表，而不是一张大表】
///   az_assets        A3~A11 自登记资产（6.3 共用字段 + 各类专属列）
///   az_liabilities   欠的每一笔（7.4 / 7.5 / 7.6）
///   az_repay_plans   逐期还款计划（7.8），版本化，旧版本保留可对比
///   az_asset_trades  股票/基金买入卖出批次（6.5），结算已落袋赚亏
///   az_contingents   「万一要我还的钱」+「万一出事有人替我付」成对清单，
///                     一张表用 kind 区分（7.11 / 13.10），默认不进总账
///   az_preferences   口径开关 KV（估值口径、90 天提示、偿债三档、月收入、
///                     每月必须花的钱、应急金月数、物价假设）——13.13 唯一入口
///   az_monthly_snapshots 月末快照（10.9 / 13.12），INSERT OR IGNORE 锁历史
///
/// 【DDL 不锁枚举取值】v5 曾把 type 写死在 CHECK 里，加「花呗/借呗」被迫
/// 重建整表。这里所有枚举字符串（asset_class / purpose / status / …）都只
/// 约束非空或数值范围，取值合法性交给 Dart 枚举与 Controller 校验；
/// 以后加资产大类、加负债类型只改 Dart，不升版本。
///
/// 【B 延后期间纪律 ①】新表必须同时登记两处：
///   全新安装 → DatabaseService._modules 里的 AzDb.onCreate；
///   开发期老库 → _onUpgrade 的 `oldV < 9` 补建段。
/// 两边都调 [create]（DDL 单一真源、IF NOT EXISTS 幂等），漏一处就会出现
/// 「新装正常、开发机老库缺表」。v9 无数据迁移、无重建。
class AzDb implements DbModule {
  static const String assetsTable = 'az_assets';
  static const String liabilitiesTable = 'az_liabilities';
  static const String plansTable = 'az_repay_plans';
  static const String tradesTable = 'az_asset_trades';
  static const String contingentsTable = 'az_contingents';
  static const String preferencesTable = 'az_preferences';
  static const String snapshotsTable = 'az_monthly_snapshots';

  @override
  String get name => 'ledger';

  /// 唯一 DDL 真源。参数用 [DatabaseExecutor]：`_onCreate` 传事务里的
  /// Transaction、`_onUpgrade` 传 Database，两者都能收。不自建事务。
  static Future<void> create(DatabaseExecutor db) async {
    // ── ① 自登记资产（A3~A11，6.3 / 6.4 / 6.6 / 6.7）──────────────
    // cost = 买它一共花了多少（含税费，10.6 正数）；
    // latest_value / valued_at = 「更新一下现在值多少」填一次即留痕；
    // valuation_source = 按买入价 / 按上次买卖价 / 你自己填的（6.4）。
    // counted=0 的东西（旧电动车）仍保留，只是不进家底账。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $assetsTable (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id            TEXT    NOT NULL DEFAULT 'default',
        asset_class        TEXT    NOT NULL,
        name               TEXT    NOT NULL,
        code               TEXT    NOT NULL DEFAULT '',
        icon_key           TEXT    NOT NULL DEFAULT 'other',
        cost               REAL    NOT NULL CHECK (cost > 0),
        latest_value       REAL    CHECK (latest_value IS NULL OR latest_value > 0),
        valued_at          INTEGER,
        valuation_source   TEXT    NOT NULL DEFAULT 'cost',
        liquidity          INTEGER NOT NULL DEFAULT 2
                           CHECK (liquidity BETWEEN 0 AND 4),
        stability          TEXT    NOT NULL DEFAULT 'unset',
        monthly_in         REAL    NOT NULL DEFAULT 0 CHECK (monthly_in >= 0),
        monthly_out        REAL    NOT NULL DEFAULT 0 CHECK (monthly_out >= 0),
        exit_cost          REAL    NOT NULL DEFAULT 0 CHECK (exit_cost >= 0),
        counted            INTEGER NOT NULL DEFAULT 1 CHECK (counted IN (0,1)),
        counted_reason     TEXT    NOT NULL DEFAULT '',
        intention          TEXT    NOT NULL DEFAULT '',
        note               TEXT    NOT NULL DEFAULT '',
        link_debt_id       INTEGER,
        link_account_id    INTEGER,
        quantity           REAL    CHECK (quantity IS NULL OR quantity > 0),
        unit_price         REAL    CHECK (unit_price IS NULL OR unit_price > 0),
        use_mode           TEXT    NOT NULL DEFAULT '',
        depreciation_note  TEXT    NOT NULL DEFAULT '',
        sort_order         INTEGER NOT NULL DEFAULT 0,
        archived           INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0,1)),
        deleted_at         INTEGER,
        delete_reason      TEXT,
        created_at         INTEGER NOT NULL,
        updated_at         INTEGER NOT NULL,
        revision           INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_az_assets_active_name
        ON $assetsTable (book_id, name) WHERE deleted_at IS NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_az_assets_list
        ON $assetsTable (book_id, deleted_at, asset_class, sort_order, id)
    ''');

    // ── ② 欠的每一笔（7.4 / 7.5 / 7.6）───────────────────────────────
    // principal = 当前剩余本金；「这个月白给银行多少」只取
    // monthly_interest + monthly_fee，本金不算消耗（7.12）。
    // account_id 反向引用 accounts 里的信用卡账户（3.4 自动建对应负债），
    // 用部分唯一索引保证一张卡最多一条，避免同一笔欠款算两遍。
    // active_plan_version 保证 7.8「同一笔债不允许同时存在两个生效版本」。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $liabilitiesTable (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id               TEXT    NOT NULL DEFAULT 'default',
        liability_type        TEXT    NOT NULL,
        icon_key              TEXT    NOT NULL DEFAULT 'other',
        name                  TEXT    NOT NULL,
        purpose               TEXT    NOT NULL DEFAULT 'T4',
        original_principal    REAL    NOT NULL DEFAULT 0
                              CHECK (original_principal >= 0),
        principal             REAL    NOT NULL CHECK (principal >= 0),
        interest_on           INTEGER NOT NULL DEFAULT 1 CHECK (interest_on IN (0,1)),
        rate                  REAL    NOT NULL DEFAULT 0 CHECK (rate >= 0 AND rate < 1),
        rate_type             TEXT    NOT NULL DEFAULT 'fixed',
        nominal_rate          REAL,
        monthly_fee           REAL    NOT NULL DEFAULT 0 CHECK (monthly_fee >= 0),
        fee_note              TEXT    NOT NULL DEFAULT '',
        repay_method          TEXT    NOT NULL DEFAULT 'equal_payment',
        pay_day               INTEGER CHECK (pay_day IS NULL OR pay_day BETWEEN 1 AND 31),
        start_date            INTEGER,
        end_date              INTEGER,
        paid_terms            INTEGER NOT NULL DEFAULT 0 CHECK (paid_terms >= 0),
        total_terms           INTEGER NOT NULL DEFAULT 0 CHECK (total_terms >= 0),
        monthly_pay           REAL    NOT NULL DEFAULT 0 CHECK (monthly_pay >= 0),
        monthly_principal     REAL    NOT NULL DEFAULT 0 CHECK (monthly_principal >= 0),
        monthly_interest      REAL    NOT NULL DEFAULT 0 CHECK (monthly_interest >= 0),
        link_asset_id         INTEGER,
        link_account_id       INTEGER,
        account_id            INTEGER,
        status                TEXT    NOT NULL DEFAULT 'normal',
        prepay_penalty_rate   REAL    NOT NULL DEFAULT 0 CHECK (prepay_penalty_rate >= 0),
        rate_reset_date       INTEGER,
        rate_basis_points     REAL    NOT NULL DEFAULT 0,
        promo_until           INTEGER,
        note                  TEXT    NOT NULL DEFAULT '',
        active_plan_version   INTEGER NOT NULL DEFAULT 1 CHECK (active_plan_version >= 1),
        sort_order            INTEGER NOT NULL DEFAULT 0,
        archived              INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0,1)),
        deleted_at            INTEGER,
        delete_reason         TEXT,
        created_at            INTEGER NOT NULL,
        updated_at            INTEGER NOT NULL,
        revision              INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_az_liab_active_name
        ON $liabilitiesTable (book_id, name) WHERE deleted_at IS NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_az_liab_credit_account
        ON $liabilitiesTable (account_id)
        WHERE account_id IS NOT NULL AND deleted_at IS NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_az_liab_list
        ON $liabilitiesTable (book_id, deleted_at, sort_order, id)
    ''');

    // ── ③ 逐期还款计划（7.8）──────────────────────────────────────
    // 重算时**另存新版本**：plans 里插一批 plan_version+1 的行，主表
    // active_plan_version 指向新版本，旧行保留可对比、不覆盖。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $plansTable (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        liability_id        INTEGER NOT NULL,
        plan_version        INTEGER NOT NULL DEFAULT 1,
        term_no             INTEGER NOT NULL CHECK (term_no >= 1),
        due_date            INTEGER NOT NULL,
        principal           REAL    NOT NULL DEFAULT 0 CHECK (principal >= 0),
        interest            REAL    NOT NULL DEFAULT 0 CHECK (interest >= 0),
        fee                 REAL    NOT NULL DEFAULT 0 CHECK (fee >= 0),
        remaining_principal REAL    NOT NULL DEFAULT 0,
        status              TEXT    NOT NULL DEFAULT 'pending',
        paid_at             INTEGER,
        actual_amount       REAL,
        reason              TEXT    NOT NULL DEFAULT '',
        created_at          INTEGER NOT NULL,
        revision            INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_az_plan_term
        ON $plansTable (liability_id, plan_version, term_no)
    ''');

    // ── ④ 买卖批次（6.5）────────────────────────────────────────
    // 只在资产详情页展示「买卖记录 / 已经落袋的赚亏 / 还没卖的部分」。
    // 【边界，如实写清】本轮**不写账户流水、不改账户余额、不进家底账**：
    // 现金收付要走 AccountEntryDao.append 单写点，属「记支出/记收入」模块
    // 开工时的联动；现在只登记批次并结算，避免账算错或伪装成已完成。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tradesTable (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id       INTEGER NOT NULL,
        direction      TEXT    NOT NULL CHECK (direction IN ('buy','sell')),
        occurred_at    INTEGER NOT NULL,
        unit_price     REAL    NOT NULL CHECK (unit_price > 0),
        quantity       REAL    NOT NULL CHECK (quantity > 0),
        fee            REAL    NOT NULL DEFAULT 0 CHECK (fee >= 0),
        amount         REAL    NOT NULL CHECK (amount > 0),
        cost_basis     REAL,
        realized_pnl   REAL,
        account_id     INTEGER,
        note           TEXT    NOT NULL DEFAULT '',
        created_at     INTEGER NOT NULL,
        revision       INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_az_trades_asset
        ON $tradesTable (asset_id, occurred_at DESC, id DESC)
    ''');

    // ── ⑤ 成对清单（7.11 + 13.10）────────────────────────────────
    // 两张清单结构相同，一张表用 kind 区分；**默认不进总资产、不进总负债、
    // 不抵扣**，只有「转成我欠的钱」才写进 az_liabilities。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $contingentsTable (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id         TEXT    NOT NULL DEFAULT 'default',
        kind            TEXT    NOT NULL CHECK (kind IN ('contingent','insured')),
        title           TEXT    NOT NULL,
        max_amount      REAL    NOT NULL CHECK (max_amount >= 0),
        condition_text  TEXT    NOT NULL DEFAULT '',
        eta             TEXT    NOT NULL DEFAULT '',
        note            TEXT    NOT NULL DEFAULT '',
        sort_order      INTEGER NOT NULL DEFAULT 0,
        archived        INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0,1)),
        deleted_at      INTEGER,
        delete_reason   TEXT,
        created_at      INTEGER NOT NULL,
        updated_at      INTEGER NOT NULL,
        revision        INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_az_contingents_list
        ON $contingentsTable (book_id, kind, deleted_at, sort_order, id)
    ''');

    // ── ⑥ 口径开关（13.13 唯一入口）──────────────────────────────
    // 不替用户猜月收入 / 每月必须花的钱：默认 0，界面显示「—」并提示
    // 去设置里填。物价假设默认 0（13.1 默认不开启）。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $preferencesTable (
        key         TEXT PRIMARY KEY,
        value       TEXT NOT NULL,
        updated_at  INTEGER NOT NULL,
        revision    INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // ── ⑦ 月末快照（10.9 / 13.12）───────────────────────────────
    // 主键即年月，写入用 INSERT OR IGNORE：之后改价、切口径、改分类标记
    // 都不改写历史月份。8.1.3 趋势与 8.1.4 归因读这份，不回溯重算。
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $snapshotsTable (
        year_month      TEXT PRIMARY KEY,
        account_total   REAL NOT NULL,
        asset_total     REAL NOT NULL,
        debt_total      REAL NOT NULL,
        net_worth       REAL NOT NULL,
        valuation_mode  TEXT NOT NULL,
        snapshot_at     INTEGER NOT NULL,
        note            TEXT NOT NULL DEFAULT '',
        locked          INTEGER NOT NULL DEFAULT 1 CHECK (locked IN (0,1)),
        revision        INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 偏好默认值种子：INSERT OR IGNORE 幂等，全新安装与老库补建都安全。
    // 用户改过的值不会被覆盖（10.9「改了不覆盖历史」）。
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final MapEntry<String, String> entry in const <String, String>{
      'valuation_mode': 'cost',
      'stale_days': '90',
      'debt_ratio_level': 'std',
      'hide_zero': '1',
      'monthly_income': '0',
      'must_cost': '0',
      'emergency_months': '3',
      'inflation_rate': '0',
      'include_debt_cost_in_expense': '1',
    }.entries) {
      await db.insert(
        preferencesTable,
        <String, Object?>{
          'key': entry.key,
          'value': entry.value,
          'updated_at': now,
          'revision': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  @override
  Future<void> onCreate(DatabaseExecutor db) async => create(db);
}
