// db_module.dart
import 'package:sqflite/sqflite.dart';

abstract class DbModule {
  /// 模块名（方便日志 / 调试）
  String get name;

  /// 创建本模块**全部**表 + 初始化数据。
  /// 只在全新安装（DatabaseService._onCreate）里被调用一次；
  /// 升级路径不调用本方法，也不在任何地方「补建」单张表。
  Future<void> onCreate(DatabaseExecutor db);
}