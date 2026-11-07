// db_module.dart
import 'package:sqflite/sqflite.dart';

abstract class DbModule {
  /// 模块名（方便日志 / 调试）
  String get name;

  /// 创建表 + 初始化数据
  Future<void> onCreate(DatabaseExecutor db);
}