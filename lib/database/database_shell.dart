
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';  

/// 数据库服务：只负责建库建表，不存任何业务表
class DatabaseService {
  static const _dbName = 'yuan.db';
  static const _dbVersion = 1;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 后续按模块建表，先空着
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // 后续版本迁移用
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

