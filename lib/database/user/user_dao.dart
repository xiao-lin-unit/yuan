import 'package:sqflite/sqflite.dart';
import 'package:yuan/database/user/user_info.dart';

import '../../components.dart';

class UserInfoDao implements BaseDao {
  static const table = 'user_info';

  Future<UserInfo> getUser(Database db) async {
    final rows = await db.query(table, limit: 1);

    if (rows.isEmpty) {
      await db.insert(table, {'id': 1, 'avatar': '', 'username': '未设置名称', 'user_sub': '用户很懒，什么都没有留下！！！'}); // 触发默认值
      return getUser(db);
    }

    return UserInfo.fromMap(rows.first);
  }

  Future<void> updateUser(Database db, UserInfo user) async {
    await db.update(
      table,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  @override
  String get name => "user";
}