import '../../database/account/account_db.dart' as account_db;
import '../../database/category/category_db.dart' as category_db;
import '../../database/ledger/az_db.dart' as az_db;
import '../../database/user/user_db.dart' as user_db;

/// 可维护的实体类型（全库唯一枚举）。
///
/// 【为什么要有这张表】整改前「软删 / 恢复 / 归档 / 排序 / 查重」在账户、
/// 分类、资债三个模块各写一套，SQL 差异散在 3 个 Controller + 2 个 DAO
/// 里。把「实体 → 表名 → 支持哪些操作」收成一张注册表之后，生命周期与
/// 查重就只需要**一个**接口，新增实体只加一行，不用再复制一套逻辑。
enum EntityKind {
  account(account_db.AccountDb.accountsTable, hasBookId: true, supportsArchive: true, supportsPurge: true, supportsReorder: true, supportsUniqueName: true),
  category(category_db.CategoryDb.tableName, hasBookId: true, supportsPurge: true, supportsReorder: true, supportsUniqueName: true, supportsCategoryKind: true),
  asset(az_db.AzDb.assetsTable, supportsArchive: true, supportsUniqueName: true, supportsCode: true),
  liability(az_db.AzDb.liabilitiesTable, supportsUniqueName: true),
  contingent(az_db.AzDb.contingentsTable),
  plan(az_db.AzDb.plansTable),
  trade(az_db.AzDb.tradesTable),
  preference(az_db.AzDb.preferencesTable),
  user(user_db.UserDb.tableName);

  const EntityKind(
    this.table, {
    this.hasBookId = false,
    this.supportsArchive = false,
    this.supportsPurge = false,
    this.supportsReorder = false,
    this.supportsUniqueName = false,
    this.supportsCode = false,
    this.supportsCategoryKind = false,
  });

  /// 物理表名。生命周期 / 查重接口只认这个，不认 Controller。
  final String table;
  final bool hasBookId;
  final bool supportsArchive;
  final bool supportsPurge;
  final bool supportsReorder;
  final bool supportsUniqueName;
  final bool supportsCode;
  final bool supportsCategoryKind;

  /// 资债侧实体表名前缀（用于分派到 AzDao 的通用方法）。
  bool get isLedger => table.startsWith('az_');

  /// 表名 → 实体：资债侧的公开方法历史上传 `String table`，
  /// 这里统一反查，避免每个 Controller 自己写 switch。
  static EntityKind fromTable(String table) => EntityKind.values.firstWhere(
        (EntityKind k) => k.table == table,
        orElse: () => throw ArgumentError('未登记的实体表: $table'),
      );
}
