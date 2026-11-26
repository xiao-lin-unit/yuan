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
/// 【所属模块】service/core · 生命周期
/// 【实现功能】软删 / 恢复 / 归档 / 过期清理 / 排序的唯一功能接口；账户、分类、资债三模块共用一份实现，按 EntityKind 分派到对应 DAO。
/// 【使用限制】本类不自建事务，第一参数一律收 DatabaseExecutor；所有方法必须由调用方放进 UnitOfWork.run；DAO 不得再自建事务；不支持的操作由 supportsXxx 拒绝。
/// 【入参与结果】构造收三个 DAO（无状态，可默认 new）；方法统一收 (txn, EntityKind, id, ...)，返回 Future<void> / Future<int>。
/// 【异常与调用方处理】写入未生效抛 StateError；不支持该操作的实体抛 ArgumentError；DAO 层 SQL 异常原样上抛并回滚整个事务。调用方需自行 try/catch 提示用户、保持快照旧值。
class LifecycleService {
  /// 【所属模块】service/core · 生命周期
  /// 【实现功能】用三个 DAO 创建生命周期接口，DAO 无状态时可省略全部参数走默认值。
  /// 【使用限制】建议由 components.dart 注入与其它模块共享的 DAO 实例；不要在页面里 new。
  /// 【入参与结果】accountDao / categoryDao / azDao 均可选；无返回值（构造）。结果为可复用的 LifecycleService。
  /// 【异常与调用方处理】构造不抛异常；DAO 未就绪会在调用方法时暴露，调用方需保证装配顺序。
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

  /// 【所属模块】service/core · 生命周期
  /// 【实现功能】按实体类型软删一条记录（写 deleted_at / delete_reason / updated_at），资债侧委托 AzDao。
  /// 【使用限制】必须在 uow.run 的事务内调用；预设分类不可删的业务判断仍由 CategoryController 负责；user 不支持软删。
  /// 【入参与结果】txn / kind / id / reason 必填；at 可选（默认 DateTime.now()）。返回 Future<void>，必须 await；结果只表示 SQL 已执行，刷新由调用方挂在 afterCommit。
  /// 【异常与调用方处理】kind=EntityKind.user 或不支持的实体抛 ArgumentError；受影响行数为 0 抛 StateError；DAO 异常上抛并整体回滚。调用方需自行 try/catch 提示"删除未生效"。
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
      case EntityKind.asset || EntityKind.liability:
        await azDao.softDelete(txn, kind.table, id, reason);
        affected = 1; // AzDao 不返回行数，由调用方校验记录存在
      case EntityKind.user:
        throw ArgumentError('用户资料不支持软删');
    }
    if (affected == 0) throw StateError('${kind.name} 删除未生效');
  }

  /// 【所属模块】service/core · 生命周期
  /// 【实现功能】按实体类型恢复一条软删记录（清 deleted_at / delete_reason）。
  /// 【使用限制】必须在事务内调用；user 不支持恢复；恢复后排序由调用方另行调 reorder。
  /// 【入参与结果】txn / kind / id 必填；at 可选。返回 Future<void>，必须 await；刷新放 afterCommit。
  /// 【异常与调用方处理】不支持的实体抛 ArgumentError；受影响行数为 0 抛 StateError；DAO 异常上抛并回滚。调用方需自行 try/catch 提示"恢复未生效"。
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
      case EntityKind.asset || EntityKind.liability:
        await azDao.restore(txn, kind.table, id);
        affected = 1;
      case EntityKind.user:
        throw ArgumentError('用户资料不支持恢复');
    }
    if (affected == 0) throw StateError('${kind.name} 恢复未生效');
  }

  /// 账户与资债共用「归档」这一个接口（分类没有归档语义，只有隐藏）。
  /// 【所属模块】service/core · 生命周期
  /// 【实现功能】账户 / 资债共用的归档接口：只改标记并留痕，不改余额、不写流水；资债侧委托 AzDao。
  /// 【使用限制】仅 supportsArchive=true 的实体可调用（account / asset）；分类没有归档语义，只有隐藏（走 CategoryController.toggleHidden）。
  /// 【入参与结果】txn / kind / id / archived 必填。返回 Future<void>，必须 await；归档后刷新放 afterCommit。
  /// 【异常与调用方处理】不支持归档的实体抛 ArgumentError；账户不存在抛 StateError；更新行数 0 抛 StateError；DAO 异常上抛并回滚。调用方需自行 try/catch。
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
  /// 【所属模块】service/core · 生命周期
  /// 【实现功能】回收站过期清理（默认 30 天），预设分类永不物理删除由 DAO 的 where 兜底。
  /// 【使用限制】仅 supportsPurge=true 的实体可调用（account / category）；必须在事务内调用。
  /// 【入参与结果】txn / kind 必填；now / days 可选。返回 Future<int>（实际清理行数），调用方应据结果决定是否刷新快照（n>0 才 load）。
  /// 【异常与调用方处理】不支持清理的实体抛 ArgumentError；DAO 异常上抛并回滚。调用方需自行 try/catch，并在 n=0 时不发通知。
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
  /// 【所属模块】service/core · 生命周期
  /// 【实现功能】唯一的批量排序接口：账户表、分类表都走同一段 UPDATE，按 orderedIds 顺序写 sort_order。
  /// 【使用限制】仅 supportsReorder=true 的实体可调用；必须在事务内调用，且必须与触发它的写动作（如软删压平）同处一个 uow.run；DAO 不得自建事务。
  /// 【入参与结果】txn / kind / orderedIds 必填；bookId / categoryKind 可选（分类必须传 categoryKind 以隔离收支类型）。返回 Future<void>，必须 await。
  /// 【异常与调用方处理】不支持排序的实体抛 ArgumentError；SQL 异常上抛并整体回滚（含同一事务里的软删）。调用方需自行 try/catch 提示用户。
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
