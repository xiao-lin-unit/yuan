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
class UniquenessService {
  const UniquenessService();

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
