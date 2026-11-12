import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yuan/database/account/account_dao.dart';
import 'package:yuan/database/account/account_entry_dao.dart';
import 'package:yuan/database/category/category_dao.dart';
import 'package:yuan/service/account_controller.dart';
import 'package:yuan/service/category_controller.dart';
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

    // 分类：启动时把 41 条预设 / 用户自定义分类读进内存快照，
    // 分类管理页与以后的记账选择器共用这一份，不在页面各读一遍。
    final categoryDao = CategoryDao();
    final categoryController = CategoryController(db, categoryDao);
    await categoryController.load();

    // 账户：启动时把账户、绑定用途读进内存快照；流水不预加载
    // （按账户点开明细时再读，避免几十万条流水常驻内存）。
    final accountDao = AccountDao();
    final accountEntryDao = AccountEntryDao();
    final accountController =
        AccountController(db, accountDao, accountEntryDao);
    await accountController.load();

    Components.components.putIfAbsent("user", () => userDao);
    Components.components.putIfAbsent("category", () => categoryDao);
    Components.components.putIfAbsent("account", () => accountDao);
    Components.components.putIfAbsent("account_entry", () => accountEntryDao);

    return <ChangeNotifierProvider>[
      ChangeNotifierProvider<UserController>.value(value: userController),
      ChangeNotifierProvider<CategoryController>.value(value: categoryController),
      ChangeNotifierProvider<AccountController>.value(value: accountController),
    ];
  }
}
