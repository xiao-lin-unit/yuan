import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yuan/database/account/account_dao.dart';
import 'package:yuan/database/account/account_entry_dao.dart';
import 'package:yuan/database/ledger/az_dao.dart';
import 'package:yuan/database/category/category_dao.dart';
import 'package:yuan/service/account_controller.dart';
import 'package:yuan/service/ledger/az_controller.dart';
import 'package:yuan/service/category_controller.dart';
import 'package:yuan/service/credit_card_account_controller.dart';
import 'package:yuan/service/savings_account_controller.dart';
import 'package:yuan/service/user_controller.dart';
import 'package:yuan/service/core/account_ledger.dart';
import 'package:yuan/service/core/image_transaction.dart';
import 'package:yuan/service/core/lifecycle_service.dart';
import 'package:yuan/service/core/query_facade.dart';
import 'package:yuan/service/core/uniqueness_service.dart';
import 'package:yuan/service/core/unit_of_work.dart';
import 'package:yuan/service/image/image_service.dart';
import 'package:yuan/service/ledger/az_repayment_service.dart';

import 'database/user/user_dao.dart';

class Components {
  static final Map<String, BaseDao> components = <String, BaseDao>{};
}

abstract class BaseDao {
  String get name;
}

/// 全局装配点。
///
/// 【项目检查 1 / 2 / 3 的落点】
///   · 功能接口（事务 / 资金 / 生命周期 / 查重 / 查询 / 图片 / 跨模块编排）
///     全部在这里**各建一份实例**，注入所有业务处理器并注册 Provider；
///     页面一律 `context.read<Xxx>()` 取用，与具体页面无关 —— 换掉整套
///     UI 不需要重写任何功能。
///   · 账户侧与资债侧拿的是**同一个** [UnitOfWork] 和 [AccountLedger]，
///     因此「债务处理 + 账户出账」能放进同一个事务，后者失败回滚前者。
///
/// 【契约】本装配点是《项目规范与契约.md》的执行点：架构三条（要-17 ~ 要-19 /
/// 硬-17 ~ 硬-19 / 契-16 ~ 契-18）与接口注释标准（要-20 / 硬-20 / 契-19）。
/// 新增模块 / 换页面前先读该文 2.4 / 2.5 / 三-D / 三-E / 4.3 / 4.4；
/// 本文件必须为 8 个功能接口各建且只建一份实例，否则即违约。
class Services {
  /// 页面一律 `context.read<XxxController>()` 取用。
  static Future<List<SingleChildWidget>> initServices(Database db) async {
    // ── 1. 数据层（无状态，全库一份）──────────────────────────────
    final userDao = UserInfoDao();
    final categoryDao = CategoryDao();
    final accountDao = AccountDao();
    final accountEntryDao = AccountEntryDao();
    final azDao = AzDao();

    // ── 2. 功能接口层（全库唯一实例，页面无关）────────────────────
    final uow = UnitOfWork(db);
    final uniqueness = const UniquenessService();
    final accountLedger = AccountLedger(accountEntryDao);
    final lifecycle = LifecycleService(
      accountDao: accountDao,
      categoryDao: categoryDao,
      azDao: azDao,
    );
    final queries = QueryFacade(
      entryDao: accountEntryDao,
      accountDao: accountDao,
      uniqueness: uniqueness,
    );
    final images = ImageService.instance;
    final imageTx = ImageTransaction(uow, images);

    // ── 3. 共享账本（ChangeNotifier，页面 watch 它们）──────────────
    final userController = UserController(
      db,
      userDao,
      images: images,
      uow: uow,
      imageTx: imageTx,
    );
    await userController.load();

    final categoryController = CategoryController(
      db,
      categoryDao,
      images: images,
      uow: uow,
      lifecycle: lifecycle,
      uniqueness: uniqueness,
      imageTx: imageTx,
    );
    await categoryController.load();

    final accountController = AccountController(
      db,
      accountDao,
      accountEntryDao,
      uow: uow,
      lifecycle: lifecycle,
      uniqueness: uniqueness,
      queries: queries,
    );
    await accountController.load();

    final azController = AzController(db, azDao);
    await azController.load();

    // ── 4. 业务处理器（薄层：校验 + 调功能接口 + 提交后刷新）────────
    final savings = SavingsAccountController(
      db,
      accountDao,
      accountEntryDao,
      accountController,
      uow: uow,
      ledger: accountLedger,
      uniqueness: uniqueness,
    );
    final credit = CreditCardAccountController(
      db,
      accountDao,
      accountEntryDao,
      accountController,
      uow: uow,
      ledger: accountLedger,
      uniqueness: uniqueness,
    );
    final azWrite = AzWriteController(
      db,
      azDao,
      azController,
      uow: uow,
      lifecycle: lifecycle,
      uniqueness: uniqueness,
    );
    final azRepayment = AzRepaymentService(
      uow: uow,
      azWrite: azWrite,
      ledger: accountLedger,
      refreshAccounts: () => accountController.load(),
    );

    Components.components.putIfAbsent("user", () => userDao);
    Components.components.putIfAbsent("category", () => categoryDao);
    Components.components.putIfAbsent("account", () => accountDao);
    Components.components.putIfAbsent("account_entry", () => accountEntryDao);

    return <SingleChildWidget>[
      // 共享账本
      ChangeNotifierProvider<UserController>.value(value: userController),
      ChangeNotifierProvider<CategoryController>.value(value: categoryController),
      ChangeNotifierProvider<AccountController>.value(value: accountController),
      ChangeNotifierProvider<AzController>.value(value: azController),
      // 业务处理器（保持原有类型，页面零改动）
      Provider<SavingsAccountController>.value(value: savings),
      Provider<CreditCardAccountController>.value(value: credit),
      Provider<AzWriteController>.value(value: azWrite),
      // 功能接口：新页面直接 context.read<...>() 调用，与 UI 完全解耦
      Provider<UnitOfWork>.value(value: uow),
      Provider<AccountLedger>.value(value: accountLedger),
      Provider<LifecycleService>.value(value: lifecycle),
      Provider<UniquenessService>.value(value: uniqueness),
      Provider<QueryFacade>.value(value: queries),
      Provider<ImageTransaction>.value(value: imageTx),
      Provider<AzRepaymentService>.value(value: azRepayment),
    ];
  }
}
