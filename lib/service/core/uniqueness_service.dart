import 'package:sqflite/sqflite.dart';

import 'entity_registry.dart';

/// 名称 / 代码查重的**唯一功能接口**（写侧真源）。
///
/// 整改前：`AccountController.nameExists`、`CategoryController.nameExists`、
/// `AzWriteController._checkAssetUnique` 三套查法，有的查内存快照、
/// 有的查库，口径还不一致（软删是否占位、是否按 kind 分类型）。
///
/// 整改后：表单 validator 可以保留内存快照做「即时提示」，但**写库前
/// 一律走本接口在同一事务内查库兜底**，口径唯一：未软删、排除自身、
/// 分类按 kind 隔离、投资类代码跨三张次表语义由 `codeExists` 承担。
/// 【所属模块】service/core · 查重
/// 【实现功能】名称 / 代码查重的唯一写侧真源：表单即时提示走内存快照，写库前一律在事务内查库兜底，口径全库一致。
/// 【使用限制】本类不自建事务，方法第一参数收 DatabaseExecutor；必须由调用方放进 uow.run；不支持查重的实体由 supportsUniqueName / supportsCode 拒绝。
/// 【入参与结果】const 构造无参；方法返回 Future<bool> / Future<void>；assertUnique 抛异常而非返回 bool。
/// 【异常与调用方处理】不支持的实体抛 ArgumentError；重名 / 重码抛 ArgumentError（人话提示）；DAO 异常原样上抛并回滚整个事务。调用方需自行 try/catch 把异常转成表单错误提示，不要吞掉后继续保存。
class UniquenessService {
  /// 【所属模块】service/core · 查重
  /// 【实现功能】创建无状态查重服务（const，可全局共享一份）。
  /// 【使用限制】无状态，不要在页面里 new 第二份；由 components.dart 注入所有 Controller 与 QueryFacade。
  /// 【入参与结果】无入参；无返回值（构造）。结果为可复用的 UniquenessService。
  /// 【异常与调用方处理】构造不抛异常。
  const UniquenessService();

  /// 【所属模块】service/core · 查重
  /// 【实现功能】按实体类型查名称是否重复：未软删、排除自身、有 bookId 的按账本、分类按 kind 隔离。
  /// 【使用限制】只读；必须在事务内调用以与后续写库同快照；表单即时提示不要用它替代内存快照。
  /// 【入参与结果】txn / kind / name 必填；excludeId / categoryKind / bookId 可选。返回 Future<bool>，true 表示名称已占用。
  /// 【异常与调用方处理】kind 不支持名称查重抛 ArgumentError；SQL 异常原样上抛。调用方需自行 try/catch 或改用 assertUnique。
  Future<bool> nameExists(
    DatabaseExecutor txn,
    EntityKind kind,
    String name, {
    int? excludeId,
    String? categoryKind,
    String bookId = 'default',
  }) async {
    if (!kind.supportsUniqueName) {
      throw ArgumentError('${kind.name} 不支持名称查重');
    }
    final List<Object?> args = <Object?>[name.trim()];
    final StringBuffer where = StringBuffer('name = ? AND deleted_at IS NULL');
    if (kind.hasBookId) {
      where.write(' AND book_id = ?');
      args.add(bookId);
    }
    if (kind.supportsCategoryKind && categoryKind != null) {
      where.write(' AND kind = ?');
      args.add(categoryKind);
    }
    where.write(' AND id <> ?');
    args.add(excludeId ?? -1);
    final List<Map<String, Object?>> rows = await txn.query(
      kind.table,
      columns: <String>['id'],
      where: where.toString(),
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 【所属模块】service/core · 查重
  /// 【实现功能】查投资类代码是否重复（TRIM 后比较、空代码不查、软删行不占位、排除自身）。
  /// 【使用限制】只读；仅 supportsCode=true 的实体可调用；必须在事务内调用。
  /// 【入参与结果】txn / kind / code 必填；excludeId 可选。返回 Future<bool>，true 表示已登记。
  /// 【异常与调用方处理】kind 不支持代码查重抛 ArgumentError；SQL 异常原样上抛。调用方需自行 try/catch 或改用 assertUnique。
  Future<bool> codeExists(
    DatabaseExecutor txn,
    EntityKind kind,
    String code, {
    int? excludeId,
  }) async {
    if (!kind.supportsCode) {
      throw ArgumentError('${kind.name} 不支持代码查重');
    }
    final List<Map<String, Object?>> rows = await txn.rawQuery(
      "SELECT id FROM ${kind.table} WHERE TRIM(code) = ? AND code <> '' "
      'AND deleted_at IS NULL AND id <> ? LIMIT 1',
      <Object?>[code.trim(), excludeId ?? -1],
    );
    return rows.isNotEmpty;
  }

  /// 写库前统一断言：重复直接抛人话异常，由 [UnitOfWork] 回滚整个事务。
  /// 【所属模块】service/core · 查重
  /// 【实现功能】写库前统一断言：名称重复、代码重复时直接抛人话异常，由 UnitOfWork 回滚整个事务。
  /// 【使用限制】必须在 uow.run 事务内、真正写库之前调用；不要拿它的返回 bool 做分支（它返回 void 且以异常表达结果）。
  /// 【入参与结果】txn / kind / name 必填；code / excludeId / categoryKind / bookId 可选。返回 Future<void>，调用方必须 await；无异常即表示可写。
  /// 【异常与调用方处理】重名抛 ArgumentError「已经有同名的…了，换个名字吧」，重码抛 ArgumentError「这个代码已经登记过了」；不支持的实体抛 ArgumentError；DAO 异常原样上抛。调用方需自行 try/catch 并原样展示给表单，不要吞掉后继续写库。
  Future<void> assertUnique(
    DatabaseExecutor txn,
    EntityKind kind, {
    required String name,
    String? code,
    int? excludeId,
    String? categoryKind,
    String bookId = 'default',
  }) async {
    if (await nameExists(
      txn,
      kind,
      name,
      excludeId: excludeId,
      categoryKind: categoryKind,
      bookId: bookId,
    )) {
      throw ArgumentError('已经有同名的${_label(kind)}了，换个名字吧');
    }
    if (code != null && code.trim().isNotEmpty &&
        await codeExists(txn, kind, code, excludeId: excludeId)) {
      throw ArgumentError('这个代码已经登记过了');
    }
  }

  String _label(EntityKind kind) => switch (kind) {
        EntityKind.account => '账户',
        EntityKind.category => '分类',
        EntityKind.asset => '一项东西',
        EntityKind.liability => '一笔欠款',
        EntityKind.contingent => '一笔或有项',
        _ => '记录',
      };
}
