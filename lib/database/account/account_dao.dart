import 'package:sqflite/sqflite.dart';

import '../../components.dart';
import 'account_db.dart';
import 'account_record.dart';

/// 账户主表 / 绑定表的纯 SQL 层：**不含业务规则**（余额联动在
/// AccountEntryDao.append，校验与事务编排在 AccountController）。
class AccountDao implements BaseDao {
  static const String table = AccountDb.accountsTable;
  static const String bindingsTable = AccountDb.bindingsTable;
  static const String entriesTable = AccountDb.entriesTable;
  static const String defaultBookId = 'default';

  @override
  String get name => 'account';

  /// 取一个账本下全部账户。默认排除回收站与归档（3.7「归档后不出现在
  /// 日常列表，但历史记录保留」）；两个开关给「已归档」视图和回收站用。
  Future<List<AccountRecord>> listAll(
    Database db, {
    String bookId = defaultBookId,
    bool includeDeleted = false,
    bool includeArchived = false,
  }) async {
    final List<String> where = <String>['book_id = ?'];
    final List<Object?> args = <Object?>[bookId];
    if (!includeDeleted) where.add('deleted_at IS NULL');
    if (!includeArchived) where.add('archived = 0');
    final rows = await db.query(
      table,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(AccountRecord.fromMap).toList(growable: false);
  }

  Future<AccountRecord?> byId(Database db, int id) async {
    final rows = await db.query(
      table,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : AccountRecord.fromMap(rows.first);
  }

  /// 返回新 id。AUTOINCREMENT 保证软删后 id 不复用，流水与关联绑定
  /// 里按 id 引用的历史不会指错账户。
  Future<int> insert(DatabaseExecutor db, AccountRecord record) =>
      db.insert(table, record.toMap());

  /// 返回受影响行数；0 行说明 where 没命中，调用方必须检查
  /// （与 UserInfoDao / CategoryDao 同规矩，前几轮修过 copyWith 漏 id）。
  Future<int> update(DatabaseExecutor db, AccountRecord record) {
    final int? id = record.id;
    if (id == null) throw ArgumentError('update 需要带 id 的 AccountRecord');
    // 10.9 单写点：balance 只能由 AccountEntryDao.append 写。
    // 编辑账户（改名 / 改额度 / 归档）时把这两列从 UPDATE 里摘掉，
    // 免得「旧 balance 写回旧 balance」看起来像第二个写入点。
    final Map<String, dynamic> values = record.toMap()
      ..remove('balance')
      ..remove('initial_balance');
    return db.update(
      table,
      values,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[id],
    );
  }

  /// 批量重排：一次事务写完全部 sort_order，避免中途崩溃留下脏顺序
  /// （10.8 即时保存 / 附录 E 事务边界）。
  Future<void> reorder(
    Database db,
    List<int> orderedIds, {
    String bookId = defaultBookId,
  }) async {
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          table,
          <String, Object?>{'sort_order': i},
          where: 'id = ? AND book_id = ?',
          whereArgs: <Object?>[orderedIds[i], bookId],
        );
      }
    });
  }

  Future<int> softDelete(
    Database db,
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

  Future<int> restore(Database db, int id, DateTime at) => db.update(
        table,
        <String, Object?>{
          'deleted_at': null,
          'delete_reason': null,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id = ? AND deleted_at IS NOT NULL',
        whereArgs: <Object?>[id],
      );

  /// 回收站过期清理（10.7：30 天）。只做物理删除行；流水**永远保留**
  /// （3.8「删除后这些记录仍会保留但不再关联账户」）。
  Future<int> purgeExpired(Database db, DateTime now) => db.delete(
        table,
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: <Object?>[
          now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        ],
      );

  /// 删除前提示用（3.8「这个账户下还有 XX 笔记录」）。
  Future<int> countEntries(Database db, int accountId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $entriesTable WHERE account_id = ?',
      <Object?>[accountId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  // ── 绑定用途（3.5 多对多）────────────────────────────────────────

  Future<List<AccountCategoryBinding>> bindingsFor(
    Database db,
    int accountId,
  ) async {
    final rows = await db.query(
      bindingsTable,
      where: 'account_id = ?',
      whereArgs: <Object?>[accountId],
    );
    return <AccountCategoryBinding>[
      for (final Map<String, dynamic> m in rows)
        AccountCategoryBinding(
          accountId: m['account_id'] as int,
          categoryId: m['category_id'] as int,
        ),
    ];
  }

  /// 全量替换某账户的绑定（先删后插）。
  ///
  /// 【为什么参数是 DatabaseExecutor，而不是 Database】
  /// sqflite 里 `Database` 和 `Transaction` 都实现 `DatabaseExecutor`。
  /// `AccountController.save` 在 `db.transaction((txn) ...)` 里调本方法，
  /// 回调拿到的是 `Transaction`；参数写成 `Database` 会编译不过，写成
  /// `DatabaseExecutor` 则两种执行器都能传（本文件 insert/update、
  /// AccountEntryDao.append、AccountDb.onCreate 都是这个写法）。
  ///
  /// 【为什么不自己开事务】事务边界由调用方统一持有：`save` 已经把
  /// 「写账户 + 开户流水 + 绑定替换」放进同一个事务，这里再开一层会把
  /// 回滚范围切碎；独立调用见 `AccountController.setBindings`，它自己
  /// 包一层 `db.transaction`，两边都只有一层事务。
  /// 注意：不要把事务里的 `txn` 改成外层 `db` 来「绕开类型错误」——
  /// 那样绑定写入不属于当前事务，失败时无法和账户一起回滚（10.9）。
  Future<void> replaceBindings(
    DatabaseExecutor txn,
    int accountId,
    Set<int> categoryIds,
  ) async {
    await txn.delete(
      bindingsTable,
      where: 'account_id = ?',
      whereArgs: <Object?>[accountId],
    );
    for (final int categoryId in categoryIds) {
      await txn.insert(bindingsTable, <String, Object?>{
        'account_id': accountId,
        'category_id': categoryId,
      });
    }
  }
}
