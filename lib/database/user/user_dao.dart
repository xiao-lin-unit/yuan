import 'package:sqflite/sqflite.dart';
import 'package:yuan/database/user/user_info.dart';

import '../../components.dart';

class UserInfoDao implements BaseDao {
  static const table = 'user_info';
  static const defaultId = 1;

  @override
  String get name => "user";

  Future<UserInfo> getUser(Database db) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [defaultId],
      limit: 1,
    );

    if (rows.isEmpty) {
      // 原来用递归 getUser(db) 兜底，若插入失败会无限递归。
      await db.rawInsert(
        'INSERT OR IGNORE INTO $table (id, avatar, username, user_sub) '
        'VALUES (?, ?, ?, ?)',
        [defaultId, '', '未设置名称', '用户很懒，什么都没有留下！！！'],
      );
      final inserted = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [defaultId],
        limit: 1,
      );
      return UserInfo.fromMap(inserted.first);
    }

    return UserInfo.fromMap(rows.first);
  }

  /// 返回受影响行数。调用方必须检查它，0 行说明写入根本没生效。
  Future<int> updateUser(Database db, UserInfo user) async {
    final id = user.id ?? defaultId;
    return db.update(
      table,
      user.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
