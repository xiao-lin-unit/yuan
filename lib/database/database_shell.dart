
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:yuan/database/account/account_db.dart';
import 'package:yuan/database/ledger/az_db.dart';
import 'package:yuan/database/db_module.dart';
import 'package:yuan/database/category/category_db.dart';
import 'package:yuan/database/user/user_db.dart';

/// 数据库服务：只负责建库建表，不存任何业务表。
///
/// ══════════════════════════════════════════════════════════════════
/// 【建表装配：只走 onCreate，不走 update】
/// ══════════════════════════════════════════════════════════════════
/// 此前每加一张新业务表都要在 `_onUpgrade` 手写一段逐版本补建，
/// 那条路径有四个问题：两条真源会漂移、发布后全是死代码、建表/灌种子/
/// 改结构/修数据口径挤在一个方法里、种子被重复执行。开发期靠它复用历史
/// 数据合理，但**不是最终方案**。
///
/// 现在收口成一条规则：
///   · **全新安装**：`_onCreate` 遍历 [_modules]，一次建完全部表 + 种子，
///     这是所有表的唯一建表路径；
///   · **升级**：`_onUpgrade` 里**没有任何 create / 补建**，只留发布之后
///     需要追加的真实数据迁移脚本（当前为空）；
///   · 新增表只登记进对应模块的 `onCreate`，不再往 `_onUpgrade` 补分支。
///
/// 【发布基线】`_dbVersion = 1`。开发机上 v1~v9 的旧库没有真实用户数据，
/// 通过 `onDowngrade: onDatabaseDowngradeDelete` 自动删库重建，重建走的
/// 依旧是完整的 `_onCreate`。两份草案都要求「旧表全删、不做迁移、
/// 全库一次性重建」，所以这里不再保留逐版本迁移链。
///
/// 【硬约束】`az_assets.link_account_id` / `az_liabilities.link_account_id`
/// 单向指向 `accounts.id`，因此**全库一次性重建**，禁止分模块先后执行。
/// 一旦有真实用户，立即切换纪律：已发布迁移脚本只读、只追加，禁止压平。
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _dbName = 'yuan.db';

  /// 发布基线：所有表由 `_onCreate` 一次建齐，之后每个版本只追加迁移。
  static const _dbVersion = 1;
  Database? _db;

  /// 全新安装的**唯一 Schema 清单**。新增模块只需登记在这里，
  /// 并让它的 `onCreate` 建好自己全部的表与种子。
  final List<DbModule> _modules = <DbModule>[
    UserDb(),
    CategoryDb(),
    AccountDb(),
    AzDb(),
  ];

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    debugPrint('📱 DB PATH = $dbPath');
    final bool exists = await databaseFactory.databaseExists(dbPath);
    debugPrint('📱 DB EXISTS = $exists');
    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // 开发期 v1~v9 旧库（版本号高于发布基线）直接删库重建：
      // 重建仍走完整的 _onCreate，升级路径不会补建任何表。
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  /// 全新安装：一个事务里按模块清单建全部表 + 种子。
  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.transaction((txn) async {
        for (final DbModule module in _modules) {
          await module.onCreate(txn);
        }
      });
    } catch (e, st) {
      debugPrint('❌ 数据库初始化失败: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// 升级：**不建表、不补建、不灌种子**。
  /// 当前发布基线为 v1，尚无需要保留的真实用户数据，故为空。
  /// 发布之后若需要 `ALTER` / 重建 / 数据订正，只在这里按版本追加脚本，
  /// 并且永远不要调用任何 `DbModule.onCreate`。
  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // 逐版本迁移脚本在此追加（只做 ALTER / 重建 / 数据订正，绝不建表）。
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
