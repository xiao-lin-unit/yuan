
import 'package:flutter/cupertino.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:yuan/database/db_module.dart';
import 'package:yuan/database/user/user_db.dart';

/// 数据库服务：只负责建库建表，不存任何业务表
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _dbName = 'yuan.db';
  static const _dbVersion = 1;
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
      rethrow; // ✅ 非常关键
    }
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // 后续版本迁移用
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

