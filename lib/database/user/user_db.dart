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
        -- 统一图片引用：'分类目录/文件名'，例如 avatar/avatar_1_xxx.jpg
        -- 图片本体由 lib/service/image 管理，这里永不存 base64 或二进制
        avatar TEXT NOT NULL DEFAULT '',
        username TEXT NOT NULL DEFAULT '',
        user_sub TEXT NOT NULL DEFAULT ''
      );
    ''');

    // 初始化默认用户；OR IGNORE 避免 onCreate 被重复触发时报唯一约束错
    await db.rawInsert(
      'INSERT OR IGNORE INTO $tableName (id, avatar, username, user_sub) '
      'VALUES (?, ?, ?, ?)',
      [1, '', '未设置名称', '用户很懒，什么都没有留下！！！'],
    );
  }
}
