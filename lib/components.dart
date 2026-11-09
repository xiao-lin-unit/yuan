import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yuan/service/user_controller.dart';

import 'database/user/user_dao.dart';

class Components {
  static final Map<String, BaseDao> components = <String, BaseDao>{};
}

abstract class BaseDao {
  String get name;
}

class Services {
  /// 改成 async：首屏渲染前必须把用户数据读出来。
  /// 原实现 userController.load() 被丢掉，首帧 user == null，页面先闪空白，
  /// 且 load 抛错时没有任何地方能捕获。
  static Future<List<ChangeNotifierProvider>> initServices(Database db) async {
    final userDao = UserInfoDao();
    final userController = UserController(db, userDao);
    await userController.load();

    Components.components.putIfAbsent(
      "user",
          () => userDao,
    );

    return [
      ChangeNotifierProvider<UserController>.value(value: userController),
    ];
  }
}
