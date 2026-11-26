import 'package:sqflite/sqflite.dart';

import '../../components.dart';
import 'category_db.dart';
import 'category_record.dart';

/// 分类表的纯 SQL 层：**不含业务规则**（预设不可删、重名提示、30 天清理
/// 都在 CategoryController），只负责把行搬进搬出。
/// 【本轮】所有方法收 [DatabaseExecutor]，可在跨模块事务里复用同一个 txn。
class CategoryDao implements BaseDao {
  static const table = CategoryDb.tableName;
  static const defaultBookId = 'default';

  @override
  String get name => 'category';

  /// 取一个账本下全部未软删的分类（两种类型一起取，Controller 再分组）。
  Future<List<CategoryRecord>> listAll(
    DatabaseExecutor db, {
    String bookId = defaultBookId,
    bool includeDeleted = false,
  }) async {
    final rows = await db.query(
      table,
      where: includeDeleted
          ? 'book_id = ?'
          : 'book_id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[bookId],
      orderBy: 'kind ASC, sort_order ASC, id ASC',
    );
    return rows.map(CategoryRecord.fromMap).toList(growable: false);
  }

  Future<CategoryRecord?> byId(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : CategoryRecord.fromMap(rows.first);
  }

  /// 返回新 id；AUTOINCREMENT 保证软删/物理清理后 id 永不复用，
  /// 流水表里按 id 引用的历史记录不会指错分类。
  Future<int> insert(DatabaseExecutor db, CategoryRecord record) =>
      db.insert(table, record.toMap());

  /// 返回受影响行数；0 行说明 where 没命中，调用方必须检查（与 UserInfoDao 同规矩）。
  Future<int> update(DatabaseExecutor db, CategoryRecord record) {
    final id = record.id;
    if (id == null) throw ArgumentError('update 需要带 id 的 CategoryRecord');
    return db.update(
      table,
      record.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 批量重排：事务由调用方（LifecycleService + UnitOfWork）统一持有，
  /// 这里只写 SQL，保证「删分类 + 压平顺序」等组合动作同事务。
  Future<void> reorder(
    DatabaseExecutor db,
    CategoryKind kind,
    List<int> orderedIds, {
    String bookId = defaultBookId,
  }) async {
    // 【本轮】排序统一走 LifecycleService.reorder（UnitOfWork 持事务），
    // DAO 不再自建事务，否则跨模块组合会被切成两段、无法整体回滚。
    for (var i = 0; i < orderedIds.length; i++) {
      await db.update(
        table,
        <String, Object?>{'sort_order': i},
        where: 'id = ? AND kind = ? AND book_id = ?',
        whereArgs: <Object?>[orderedIds[i], kind.dbValue, bookId],
      );
    }
  }

  /// 软删：不真删，写删除时刻与原因，30 天后由 [purgeExpired] 清理。
  Future<int> softDelete(
    DatabaseExecutor db,
    int id, {
    required DateTime at,
    required String reason,
  }) =>
      db.update(
        table,
        <String, Object?>{
          'deleted_at': at.millisecondsSinceEpoch,
          'delete_reason': reason,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
      );

  Future<int> restore(DatabaseExecutor db, int id, DateTime at) => db.update(
        table,
        <String, Object?>{
          'deleted_at': null,
          'delete_reason': null,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id = ? AND deleted_at IS NOT NULL',
        whereArgs: <Object?>[id],
      );

  /// 回收站过期清理（10.7：30 天）。只删自定义分类，预设永不物理删除。
  Future<int> purgeExpired(DatabaseExecutor db, DateTime now) => db.delete(
        table,
        where: 'deleted_at IS NOT NULL AND deleted_at < ? AND preset = 0',
        whereArgs: <Object?>[
          now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        ],
      );
}
