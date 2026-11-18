
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:yuan/database/account/account_db.dart';
import 'package:yuan/database/account/credit_card_rule.dart';
import 'package:yuan/database/db_module.dart';
import 'package:yuan/database/category/category_db.dart';
import 'package:yuan/database/user/user_db.dart';
import 'package:yuan/service/image/image_migration.dart';

/// 数据库服务：只负责建库建表，不存任何业务表
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _dbName = 'yuan.db';
  // v1: 头像存 base64；v2: 统一图片引用（ImageRef），由 ImageMigration 收编旧数据；
  // v3: 新增 categories（收支分类，一张表 + 41 条预设种子）；
  // v4: 新增 accounts（三类账户共用一张主表）+ account_category_bindings
  //     （受限账户绑定用途）+ account_entries（账户出入流水）。
  // v5: accounts 主表重建：DDL 不再把具体形态写死在 CHECK 里，
  //     形态合法性交给 Dart 枚举（以后加「花呗 / 借呗」这类形态不升版本）。
  // v6: 信用卡流水 direction 翻转（消费 → 出账、还款 → 入账）。
  //     DDL 与列结构不变，只做一次幂等 UPDATE；balance_after 原样保留。
  // v7: account_entries 新增 credit_limit_after（每笔流水当时的总额度），
  //     用于精确还原历史流水的可用额度；历史数据按当前额度回填兜底。
  // v8: 新增 credit_card_rules（3.4 信用卡章程十项，一对一附属表）。
  //     只补建一张新表，无数据迁移、无重建，accounts / entries 的 DDL
  //     一字节不动；章程由用户自己填，旧数据按「没填过」兼容。
  static const _dbVersion = 8;
  Database? _db;

  final List<DbModule> _modules = <DbModule>[
    UserDb(),
    CategoryDb(),
    AccountDb(),
  ];

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    debugPrint('📱 DB PATH = $dbPath');
    final exists = await databaseFactory.databaseExists(dbPath);
    debugPrint('📱 DB EXISTS = $exists');
    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.transaction((txn) async {
            for(final module in _modules) {
              await module.onCreate(txn);
            }
          });
    } catch (e, st) {
      debugPrint('❌ 数据库初始化失败: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      // 统一图片迁移：任何表的旧图片列都走同一套逻辑
      await ImageMigration.run(db);
    }
    if (oldV < 3) {
      // categories 表 + 索引 + 预设种子。CategoryDb.onCreate 是幂等的
      // （IF NOT EXISTS / INSERT OR IGNORE），全新安装与 v2→v3 升级共用。
      await CategoryDb().onCreate(db);
    }
    // 【分支工作逻辑，为什么是 if / else if 而不是两个独立 if】
    //   · oldV < 4（全新安装或 v1~v3）：accounts 还不存在，onCreate 用
    //     v5 的 DDL 一次性建好三张表，不需要重建；
    //   · oldV == 4：accounts 已按 v4 的旧 CHECK 建好，CREATE TABLE
    //     IF NOT EXISTS 不会改结构，必须走重建迁移；
    // 若写成两个独立 if，老用户在同一次升级里会「刚建好又重建」一遍。
    // openDatabase 的 onUpgrade 整体已在一个事务内，迁移方法不自建事务。
    if (oldV < 4) {
      // accounts / 绑定 / 流水三张表 + 索引。AccountDb.onCreate 幂等，
      // 全新安装与 v1~v3 升级共用；不插演示账户，用户账本保持干净。
      await AccountDb().onCreate(db);
    } else if (oldV == 4) {
      // v4 → v5：按列名全量拷贝 → DROP → RENAME → 重建索引。
      // 绑定表与流水表不动，id 原样保留。
      await AccountDb.migrateV4ToV5(db);
    }
    // v5 → v6 与上面的建表 / 重建**顺序执行、互不排斥**：
    //   · oldV == 4 的用户先重建主表，再翻转旧流水方向；
    //   · oldV == 5 的用户直接翻转；
    //   · oldV < 4 的用户表是空的，UPDATE 影响 0 行。
    // 写成独立 if 而不是 else if，是因为它属于「数据口径修正」，
    // 与「表结构建立 / 重建」是两件事，任何起点都要过这一遍。
    if (oldV < 6) {
      await AccountDb.migrateV5ToV6(db);
    }
    // v6 → v7：加列 + 回填。与上面的建表 / 重建**顺序执行、互不排斥**：
    //   · oldV < 4 的用户，onCreate 已建成含新列的表，迁移方法靠
    //     PRAGMA 判列跳过 ALTER，UPDATE 影响 0 行；
    //   · oldV == 4 / 5 / 6 的用户，entries 表是旧结构，正常 ALTER + 回填。
    // 写成独立 if，是因为「加列」与「建表 / 翻方向」是不同事项，
    // 任何起点都要过这一遍。
    if (oldV < 7) {
      await AccountDb.migrateV6ToV7(db);
    }
    // v7 → v8：补建 credit_card_rules（新业务表，不是改已有表结构）。
    //
    // 【B 延后期间纪律 ① 的落点】开发阶段每加一张新表，必须**同时**
    // 登记两处：全新安装走 _onCreate → AccountDb.onCreate → 本方法；
    // 老库升级走这里。两处调同一个 CreditCardRuleDb.create（DDL 单一
    // 真源、IF NOT EXISTS 幂等），漏一处就会出现「新装正常、开发机老库
    // 缺表」，而这种 bug 在一直在用的开发机上永远复现不出来。
    //
    // 【为什么写成独立 if，4 种起点都过一遍】
    //   · oldV < 4：上面的 AccountDb.onCreate 已建过，本段幂等跳过；
    //   · oldV == 4 / 5 / 6：走完各自迁移后在这里补建；
    //   · oldV == 7：只补建这一张表；
    //   · 全新安装：不走 onUpgrade，由 _onCreate 建。
    // 与「建表 / 翻方向 / 加列」是不同事项，不写成 else if。
    // 无数据迁移（用户还没填过章程），因此不需要 vN → vN+1 的数据订正。
    // 【事务边界】openDatabase.onUpgrade 整体已在事务内，不自建事务。
    if (oldV < 8) {
      await CreditCardRuleDb.create(db);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
