
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:yuan/database/db_module.dart';
import 'package:yuan/database/user/user_db.dart';
import 'package:yuan/service/image/image_migration.dart';

/// 数据库服务：只负责建库建表，不存任何业务表
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _dbName = 'yuan.db';
  // v1: 头像存 base64；v2: 统一图片引用（ImageRef），由 ImageMigration 收编旧数据
  static const _dbVersion = 2;
  Database? _db;

  final List<DbModule> _modules = [
    UserDb()
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
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
