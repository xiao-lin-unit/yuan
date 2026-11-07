import '../db_module.dart';
import 'package:sqflite/sqflite.dart';

class UserDb implements DbModule {
  static const tableName = 'user_info';

  @override
  String get name => 'user';

  @override
  Future<void> onCreate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY,
        avatar TEXT NOT NULL DEFAULT '',
        username TEXT NOT NULL DEFAULT '',
        user_sub TEXT NOT NULL DEFAULT ''
      );
    ''');

    // 初始化默认用户
    await db.insert(tableName, {'id': 1, 'avatar': '', 'username': '未设置名称', 'user_sub': '用户很懒，什么都没有留下！！！'});
  }
}