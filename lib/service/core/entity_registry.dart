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
/// 【所属模块】service/core · 实体登记
/// 【实现功能】全库唯一的实体类型枚举：把"实体 → 表名 → 支持哪些操作"收成一张注册表，生命周期与查重接口据此分派，新增实体只加一行。
/// 【使用限制】只允许在 core/ 内维护；表名必须与 DDL 常量一致；不得在 Controller 里另写表名 switch；枚举值顺序不影响逻辑，但 isLedger 依赖 az_ 前缀。
/// 【入参与结果】每个枚举值带 table + 若干 supportsXxx 布尔；消费方通过字段或 fromTable 取用，结果为不可变 EntityKind。
/// 【异常与调用方处理】不支持的操作由各功能接口抛 ArgumentError；调用方应先用 supportsXxx 判断再调用，或自行 try/catch。
enum EntityKind {
  account(account_db.AccountDb.accountsTable, hasBookId: true, supportsArchive: true, supportsPurge: true, supportsReorder: true, supportsUniqueName: true),
  category(category_db.CategoryDb.tableName, hasBookId: true, supportsPurge: true, supportsReorder: true, supportsUniqueName: true, supportsCategoryKind: true),
  asset(az_db.AzDb.assetsTable, supportsArchive: true, supportsUniqueName: true, supportsCode: true),
  liability(az_db.AzDb.liabilitiesTable, supportsUniqueName: true),
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
  /// 【所属模块】service/core · 实体登记
  /// 【实现功能】判断实体是否属于资债侧（表名以 az_ 开头），供 LifecycleService 分派到 AzDao。
  /// 【使用限制】只读派生，不能当作"是否支持某操作"的判断；具体能力仍看 supportsXxx。
  /// 【入参与结果】无入参；返回 bool。结果为 true 时生命周期接口走 AzDao，false 时走 AccountDao / CategoryDao。
  /// 【异常与调用方处理】不抛异常；新增实体表名若不按 az_ 前缀命名会静默分派错，调用方（新增实体的人）需自行保证命名。
  bool get isLedger => table.startsWith('az_');

  /// 表名 → 实体：资债侧的公开方法历史上传 `String table`，
  /// 这里统一反查，避免每个 Controller 自己写 switch。
  /// 【所属模块】service/core · 实体登记
  /// 【实现功能】由物理表名反查 EntityKind，供历史上传 String table 的资债侧方法统一转换。
  /// 【使用限制】只接受已登记的表名；不得传入拼接 / 用户输入的表名。
  /// 【入参与结果】入参 table 必须是 DDL 中的真实表名；返回对应的 EntityKind，可直接传给 LifecycleService / UniquenessService。
  /// 【异常与调用方处理】未登记的表名抛 ArgumentError「未登记的实体表」。调用方需自行 catch 或先确保表名来自本枚举。
  static EntityKind fromTable(String table) => EntityKind.values.firstWhere(
        (EntityKind k) => k.table == table,
        orElse: () => throw ArgumentError('未登记的实体表: $table'),
      );
}
