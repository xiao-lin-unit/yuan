import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yuan/database/account/account_dao.dart';
import 'package:yuan/database/account/account_entry_dao.dart';
import 'package:yuan/database/asset_liability/az_dao.dart';
import 'package:yuan/database/category/category_dao.dart';
import 'package:yuan/service/account_controller.dart';
import 'package:yuan/service/az_controller.dart';
import 'package:yuan/service/category_controller.dart';
import 'package:yuan/service/credit_card_account_controller.dart';
import 'package:yuan/service/savings_account_controller.dart';
import 'package:yuan/service/user_controller.dart';

import 'database/user/user_dao.dart';

class Components {
  static final Map<String, BaseDao> components = <String, BaseDao>{};
}

abstract class BaseDao {
  String get name;
}

class Services {
  /// 页面一律 `context.read<XxxController>()` 取用。
  static Future<List<SingleChildWidget>> initServices(Database db) async {
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

    // 资债：启动时把资产 / 负债 / 还款计划 / 成对清单 / 口径开关
    // 读进内存快照。账户镜像不在这里复制，页面同时 watch
    // AccountController，余额一变家底账当场跟着变，不注册第二份监听。
    // AzDao 不登记进 Components.components：那个 Map 的类型是
    // BaseDao，数据层不该反向依赖 components.dart；本模块由下面两个
    // Provider 直接持有实例即可。
    final azDao = AzDao();
    final azController = AzController(db, azDao);
    await azController.load();

    Components.components.putIfAbsent("user", () => userDao);
    Components.components.putIfAbsent("category", () => categoryDao);
    Components.components.putIfAbsent("account", () => accountDao);
    Components.components.putIfAbsent("account_entry", () => accountEntryDao);

    return <SingleChildWidget>[
      ChangeNotifierProvider<UserController>.value(value: userController),
      ChangeNotifierProvider<CategoryController>.value(value: categoryController),
      ChangeNotifierProvider<AccountController>.value(value: accountController),
      Provider<SavingsAccountController>.value(
        value: SavingsAccountController(
            db, accountDao, accountEntryDao, accountController),
      ),
      Provider<CreditCardAccountController>.value(
        value: CreditCardAccountController(
            db, accountDao, accountEntryDao, accountController),
      ),
      ChangeNotifierProvider<AzController>.value(value: azController),
      Provider<AzWriteController>.value(
        value: AzWriteController(db, azDao, azController),
      ),
    ];
  }
}
