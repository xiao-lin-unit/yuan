
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:yuan/database/account/account_db.dart';
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
  static const _dbVersion = 5;
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
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
