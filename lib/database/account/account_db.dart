import 'package:sqflite/sqflite.dart';

import '../db_module.dart';
import 'credit_card_rule.dart';

/// 账户模块 6 张表（《账户表结构草案.md》定稿）。
///
/// 主表 `accounts` 17 列四类共用；K2 / K4 各一张有真实专属列的次表
/// （K1 / K3 不造空表）；附属表 3 张：流水 / 绑定用途 / 信用卡章程。
///
/// 【金额一律 TEXT】见 `lib/utils/money.dart`：落库十进制字符串、计算
/// 走 int 分，避免 REAL 的浮点误差。CHECK 统一用 CAST(... AS REAL) 兜底。
///
/// 【CHECK 分两类，只去枚举取值 CHECK】kind / direction / entry_type /
/// interest_method 不写 CHECK，取值合法性交给 Dart 枚举（加形态不必重建
/// 整表）；跨列业务一致性 CHECK 与数值范围 CHECK 全部保留。
///
/// 【单写点】accounts.balance 只能由 AccountEntryDao.append 写；专属列
/// 下放次表后由 AccountDao.insert/update 在同一事务内分流写入，
/// listAll/byId 用 LEFT JOIN 并回行，AccountRecord 的公共 API 不变。
///
/// 【本模块只在 onCreate 建表】DatabaseService._onCreate 遍历模块清单
/// 调用本方法；_onUpgrade 不再调用任何 create，开发期旧库靠
/// onDowngrade 删库重建。DDL 单一真源就在这里。
class AccountDb implements DbModule {
  static const String accountsTable = 'accounts';
  static const String creditTable = 'account_credit';
  static const String investmentTable = 'account_investment';
  static const String bindingsTable = 'account_category_bindings';
  static const String entriesTable = 'account_entries';

  /// 主表 17 列（按草案顺序），也是 JOIN 查询的列真源。
  static const List<String> accountColumns = <String>[
    'id', 'book_id', 'kind', 'type', 'name', 'note',
    'balance', 'initial_balance', 'is_liquid', 'include_in_net_worth',
    'sort_order', 'archived', 'deleted_at', 'delete_reason',
    'created_at', 'updated_at', 'revision',
  ];

  /// K2 / K4 次表列（不进主表 toMap）。
  static const List<String> subColumns = <String>[
    'credit_limit', 'statement_day', 'due_day', 'repay_account_id',
    'min_payment_rate', 'current_period_spent', 'period_installed_amount',
    'last_period_key', 'net_transfer_in',
  ];

  static String accountsDdlFor(String table) => '''
    CREATE TABLE IF NOT EXISTS $table (
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id               TEXT    NOT NULL DEFAULT 'default',
      kind                  TEXT    NOT NULL,  -- liquid / credit / restricted / investment
      type                  TEXT    NOT NULL,  -- 四张形态清单，DDL 不锁取值
      name                  TEXT    NOT NULL,
      note                  TEXT    NOT NULL DEFAULT '',
      balance               TEXT    NOT NULL DEFAULT '0',  -- 累计值；可为负
      initial_balance       TEXT    NOT NULL DEFAULT '0'
                            CHECK (CAST(initial_balance AS REAL) >= 0),
      is_liquid             INTEGER NOT NULL DEFAULT 1 CHECK (is_liquid IN (0,1)),
      include_in_net_worth  INTEGER NOT NULL DEFAULT 1
                            CHECK (include_in_net_worth IN (0,1)),
      sort_order            INTEGER NOT NULL DEFAULT 0,
      archived              INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0,1)),
      deleted_at            INTEGER,
      delete_reason         TEXT,
      created_at            INTEGER NOT NULL,
      updated_at            INTEGER NOT NULL,
      revision              INTEGER NOT NULL DEFAULT 1,
      -- C7① 跨列业务一致性：信用卡不计入「能花的钱」/「真正属于你的钱」
      CHECK (kind <> 'credit' OR (is_liquid = 0 AND include_in_net_worth = 0)),
      CHECK (kind <> 'liquid' OR is_liquid = 1),
      CHECK (type NOT IN ('social_security','housing_fund') OR is_liquid = 0)
    )
  ''';

  static String creditDdlFor(String table) => '''
    CREATE TABLE IF NOT EXISTS $table (
      id                       INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id               INTEGER NOT NULL UNIQUE,
      credit_limit             TEXT    NOT NULL
                               CHECK (CAST(credit_limit AS REAL) > 0),
      statement_day            INTEGER CHECK (statement_day IS NULL OR
                                 statement_day BETWEEN 1 AND 31),
      due_day                  INTEGER CHECK (due_day IS NULL OR
                                 due_day BETWEEN 1 AND 31),
      repay_account_id         INTEGER,
      min_payment_rate         REAL    NOT NULL DEFAULT 0.1
                               CHECK (min_payment_rate >= 0 AND min_payment_rate <= 1),
      -- 方案 A 三列：本期消费额 / 本周期已办分期额 / 上次归零周期
      current_period_spent     TEXT    NOT NULL DEFAULT '0'
                               CHECK (CAST(current_period_spent AS REAL) >= 0),
      period_installed_amount  TEXT    NOT NULL DEFAULT '0'
                               CHECK (CAST(period_installed_amount AS REAL) >= 0),
      last_period_key          TEXT,
      created_at               INTEGER NOT NULL,
      updated_at               INTEGER NOT NULL,
      revision                 INTEGER NOT NULL DEFAULT 1
    )
  ''';

  static String investmentDdlFor(String table) => '''
    CREATE TABLE IF NOT EXISTS $table (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id       INTEGER NOT NULL UNIQUE,
      net_transfer_in  TEXT    NOT NULL DEFAULT '0',  -- 净转入额，可为负
      created_at       INTEGER NOT NULL,
      updated_at       INTEGER NOT NULL,
      revision         INTEGER NOT NULL DEFAULT 1
    )
  ''';

  static String bindingsDdlFor(String table) => '''
    CREATE TABLE IF NOT EXISTS $table (
      account_id   INTEGER NOT NULL,
      category_id  INTEGER NOT NULL,
      created_at   INTEGER NOT NULL,
      updated_at   INTEGER NOT NULL,
      revision     INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (account_id, category_id)
    )
  ''';

  static String entriesDdlFor(String table) => '''
    CREATE TABLE IF NOT EXISTS $table (
      id                       INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id                  TEXT    NOT NULL DEFAULT 'default',
      account_id               INTEGER NOT NULL,
      direction                TEXT    NOT NULL,  -- in / out，不写 CHECK
      amount                   TEXT    NOT NULL
                               CHECK (CAST(amount AS REAL) > 0),
      balance_after            TEXT    NOT NULL,  -- 可为负
      credit_limit_after       TEXT    CHECK (credit_limit_after IS NULL OR
                                 CAST(credit_limit_after AS REAL) > 0),
      entry_type               TEXT    NOT NULL,  -- 见全局约定 3，不写 CHECK
      record_source            TEXT    NOT NULL DEFAULT 'user',
      occurred_at              INTEGER NOT NULL,
      counterparty_account_id  INTEGER,  -- 转账对手；禁止指向 kind='credit'
      transfer_group_id        TEXT,
      category_id              INTEGER,
      payee                    TEXT    NOT NULL DEFAULT '',
      note                     TEXT    NOT NULL DEFAULT '',
      reason                   TEXT    NOT NULL DEFAULT '',
      non_binding              INTEGER NOT NULL DEFAULT 0 CHECK (non_binding IN (0,1)),
      image_ref                TEXT,
      ref_type                 TEXT,
      ref_id                   INTEGER,
      created_at               INTEGER NOT NULL,
      updated_at               INTEGER NOT NULL,
      revision                 INTEGER NOT NULL DEFAULT 1,
      -- C7① 跨列业务一致性 CHECK（枚举取值 CHECK 全部去掉）
      CHECK (entry_type <> 'adjustment' OR length(trim(reason)) > 0),
      CHECK (entry_type NOT IN ('transfer_out','transfer_in','credit_repay')
             OR (transfer_group_id IS NOT NULL AND counterparty_account_id IS NOT NULL)),
      CHECK (entry_type <> 'opening' OR direction = 'in')
    )
  ''';

  static Future<void> createIndexes(DatabaseExecutor db, String table) async {
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_accounts_active_name
        ON $table (book_id, name) WHERE deleted_at IS NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_accounts_list
        ON $table (book_id, deleted_at, archived, kind, sort_order, id)
    ''');
  }

  @override
  String get name => 'account';

  /// **唯一建表入口**：只由 DatabaseService._onCreate 调用（在一个事务里）。
  /// 升级路径不再调用本方法，也不在任何地方「补建」单张表。
  @override
  Future<void> onCreate(DatabaseExecutor db) async {
    await db.execute(accountsDdlFor(accountsTable));
    await createIndexes(db, accountsTable);

    // ② K2 次表：额度与方案 A 三列
    await db.execute(creditDdlFor(creditTable));
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_account_credit_repay
        ON $creditTable (repay_account_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_account_credit_statement
        ON $creditTable (statement_day)
    ''');

    // ③ K4 次表：净转入额
    await db.execute(investmentDdlFor(investmentTable));

    // ④ 绑定用途
    await db.execute(bindingsDdlFor(bindingsTable));
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_bindings_category
        ON $bindingsTable (category_id, account_id)
    ''');

    // ⑤ 流水
    await db.execute(entriesDdlFor(entriesTable));
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_account_time
        ON $entriesTable (account_id, occurred_at DESC, id DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_book_time
        ON $entriesTable (book_id, occurred_at, entry_type)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_account_type_time
        ON $entriesTable (account_id, entry_type, occurred_at)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_transfer
        ON $entriesTable (transfer_group_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_ref
        ON $entriesTable (ref_type, ref_id)
    ''');

    // ⑥ 信用卡章程（一对一附属表，DDL 真源在 CreditCardRuleDb）
    await CreditCardRuleDb.create(db);
  }
}
