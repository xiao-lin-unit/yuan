import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yuan/service/user_controller.dart';

import 'database/user/user_dao.dart';

class Components {
  static Map<String, BaseDao> components = {

  };
}

abstract class BaseDao {
  String get name;
}

class Services {
  static List<ChangeNotifierProvider> initServices(Database db) {
    final userDao = UserInfoDao();
    final userController = UserController(db, userDao);
    userController.load();

    Components.components.putIfAbsent(
      "user",
          () => userDao,
    );

    return [
      ChangeNotifierProvider<UserController>.value(value: userController),
    ];
  }
}