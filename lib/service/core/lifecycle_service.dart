import 'package:sqflite/sqflite.dart';

import '../../database/account/account_dao.dart';
import '../../database/account/account_record.dart';
import '../../database/category/category_dao.dart';
import '../../database/ledger/az_dao.dart';
import 'entity_registry.dart';

/// 软删 / 恢复 / 归档 / 过期清理 / 排序的**唯一功能接口**。
///
/// 整改前这些动作在 `AccountController`、`CategoryController`、
/// `AzWriteController` 三处各写一套，DAO 里还各自 `db.transaction`
/// 重排（account_dao:158 / category_dao:68），事务边界被切碎。
///
/// 整改后：所有模块只调本类；本类**不自建事务**，第一参数收
/// [DatabaseExecutor]，由 [UnitOfWork] 统一编排，因此「删一条分类 +
/// 重排剩余 + 写一笔流水」可以在同一事务里完成，任一步失败全回滚。
class LifecycleService {
  LifecycleService({
    AccountDao? accountDao,
    CategoryDao? categoryDao,
    AzDao? azDao,
  })  : accountDao = accountDao ?? AccountDao(),
        categoryDao = categoryDao ?? CategoryDao(),
        azDao = azDao ?? AzDao();

  final AccountDao accountDao;
  final CategoryDao categoryDao;
  final AzDao azDao;

  Future<void> softDelete(
    DatabaseExecutor txn,
    EntityKind kind,
    int id, {
    required String reason,
    DateTime? at,
  }) async {
    final DateTime now = at ?? DateTime.now();
    final int affected;
    switch (kind) {
      case EntityKind.account:
        affected = await accountDao.softDelete(txn, id, at: now, reason: reason);
      case EntityKind.category:
        affected = await categoryDao.softDelete(txn, id, at: now, reason: reason);
      case EntityKind.asset ||
          EntityKind.liability ||
          EntityKind.contingent ||
          EntityKind.plan ||
          EntityKind.trade ||
          EntityKind.preference:
        await azDao.softDelete(txn, kind.table, id, reason);
        affected = 1; // AzDao 不返回行数，由调用方校验记录存在
      case EntityKind.user:
        throw ArgumentError('用户资料不支持软删');
    }
    if (affected == 0) throw StateError('${kind.name} 删除未生效');
  }

  Future<void> restore(
    DatabaseExecutor txn,
    EntityKind kind,
    int id, {
    DateTime? at,
  }) async {
    final DateTime now = at ?? DateTime.now();
    final int affected;
    switch (kind) {
      case EntityKind.account:
        affected = await accountDao.restore(txn, id, now);
      case EntityKind.category:
        affected = await categoryDao.restore(txn, id, now);
      case EntityKind.asset ||
          EntityKind.liability ||
          EntityKind.contingent ||
          EntityKind.plan ||
          EntityKind.trade ||
          EntityKind.preference:
        await azDao.restore(txn, kind.table, id);
        affected = 1;
      case EntityKind.user:
        throw ArgumentError('用户资料不支持恢复');
    }
    if (affected == 0) throw StateError('${kind.name} 恢复未生效');
  }

  /// 账户与资债共用「归档」这一个接口（分类没有归档语义，只有隐藏）。
  Future<void> setArchived(
    DatabaseExecutor txn,
    EntityKind kind,
    int id, {
    required bool archived,
  }) async {
    if (!kind.supportsArchive) {
      throw ArgumentError('${kind.name} 不支持归档');
    }
    if (kind.isLedger) {
      await azDao.setArchived(txn, kind.table, id, archived);
      return;
    }
    // 账户：整行覆盖，保留累计值与流水，只改标记 + 留痕。
    final AccountRecord? old = await accountDao.byId(txn, id);
    if (old == null) throw StateError('账户不存在');
    final int affected = await accountDao.update(
      txn,
      old.copyWith(
        archived: archived,
        updatedAt: DateTime.now(),
        revision: old.revision + 1,
      ),
    );
    if (affected == 0) throw StateError('归档状态写入未生效');
  }

  /// 回收站过期清理（30 天，10.7）。预设分类永不物理删除由 DAO 兜底。
  Future<int> purgeExpired(
    DatabaseExecutor txn,
    EntityKind kind, {
    DateTime? now,
    int days = 30,
  }) async {
    if (!kind.supportsPurge) {
      throw ArgumentError('${kind.name} 不支持过期清理');
    }
    final DateTime at = now ?? DateTime.now();
    return switch (kind) {
      EntityKind.account => accountDao.purgeExpired(txn, at),
      EntityKind.category => categoryDao.purgeExpired(txn, at),
      _ => 0,
    };
  }

  /// **唯一排序接口**：账户表、分类表都走同一段批量 UPDATE。
  /// 之前 account_dao.reorder / category_dao.reorder 各自包一层事务，
  /// 现在由调用方的 [UnitOfWork] 统一持事务，DAO 不再自建。
  Future<void> reorder(
    DatabaseExecutor txn,
    EntityKind kind, {
    required List<int> orderedIds,
    String bookId = 'default',
    String? categoryKind,
  }) async {
    if (!kind.supportsReorder) {
      throw ArgumentError('${kind.name} 不支持排序');
    }
    final int stamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < orderedIds.length; i++) {
      final StringBuffer where = StringBuffer('id = ?');
      final List<Object?> args = <Object?>[orderedIds[i]];
      if (kind.hasBookId) {
        where.write(' AND book_id = ?');
        args.add(bookId);
      }
      if (kind.supportsCategoryKind && categoryKind != null) {
        where.write(' AND kind = ?');
        args.add(categoryKind);
      }
      await txn.update(
        kind.table,
        <String, Object?>{'sort_order': i, 'updated_at': stamp},
        where: where.toString(),
        whereArgs: args,
      );
    }
  }
}
