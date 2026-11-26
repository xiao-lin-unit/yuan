import 'package:sqflite/sqflite.dart';

import 'az_record.dart';
import 'az_schema.dart';

/// 资债模块唯一 DAO：32 张表统一走这里，页面与其它模块不得直连 db.query / db.insert。
///
/// 所有方法第一参数收 [DatabaseExecutor]，在 UnitOfWork.run 里自动复用同一个
/// txn；本类**不自建事务**，满足《项目规范与契约.md》硬-19。
/// 【所属模块】database/ledger · 资债读写
/// 【实现功能】按 AzSchema.allTables 白名单对 32 张表做查询 / 插入 / 更新 / 软删 / 恢复 / 归档，并一次性加载全量快照。
/// 【使用限制】必须在 UnitOfWork.run 事务内执行写方法；表名只允许 AzSchema.allTables 中的常量，禁止拼接用户输入；不自建事务、不调 refresh。
/// 【入参与结果】方法首参均为 DatabaseExecutor；loadAll 返回 AzData，insert 返回新行 id，其余返回 Future<void> 或影响行数；调用方必须 await。
/// 【异常与调用方处理】表名未登记抛 ArgumentError；SQL / CHECK 异常原样上抛并由外层事务整体回滚；调用方需自行 try/catch 提示用户并保持旧快照，不得吞异常后继续展示半写数据。
class AzDao {
  const AzDao();

  static const Set<String> _mainTables = <String>{'az_assets', 'az_liabilities'};

  /// 【所属模块】database/ledger · 资债读写
  /// 【实现功能】校验表名是否在 AzSchema 白名单内，拒绝任何拼接 / 用户输入表名。
  /// 【使用限制】所有公开方法调用前必经；只允许 32 张登记表。
  /// 【入参与结果】收 table；合法时无返回，非法抛 ArgumentError。
  /// 【异常与调用方处理】非法表名抛 ArgumentError('未登记的资债表: xxx')；调用方需自行 try/catch 或保证表名来自 AzSchema 常量。
  void _assertTable(String table) {
    if (!AzSchema.allTables.contains(table)) {
      throw ArgumentError('未登记的资债表: $table');
    }
  }

  /// 【所属模块】database/ledger · 资债读写
  /// 【实现功能】一次性读齐 32 张表：两张主表过滤软删，其余次表 / 附表全量取回，组成 AzData 快照。
  /// 【使用限制】只读，可在事务内也可在事务外调用；不得在写事务 body 里调用本方法做「先查再写」的跨模块判断（应改用 UniquenessService）。
  /// 【入参与结果】收 DatabaseExecutor db；返回 Future<AzData>，调用方必须 await；today 取 DateTime.now()。
  /// 【异常与调用方处理】表未建 / 查询失败抛 DatabaseException 并上抛；调用方需自行 try/catch 并展示错误态，保留上一次快照，不得清空页面。
  Future<AzData> loadAll(DatabaseExecutor db) async {
    final Map<String, List<AzRecord>> byTable = <String, List<AzRecord>>{};
    for (final String table in AzSchema.allTables) {
      final List<Map<String, Object?>> rows = await db.query(
        table,
        where: _mainTables.contains(table) ? 'deleted_at IS NULL' : null,
        orderBy: _mainTables.contains(table) ? 'sort_order ASC, id ASC' : 'id ASC',
      );
      byTable[table] = rows
          .map((Map<String, Object?> r) => AzRecord(table, r))
          .toList(growable: false);
    }
    return AzData(
      assets: byTable['az_assets'] ?? const <AzRecord>[],
      liabilities: byTable['az_liabilities'] ?? const <AzRecord>[],
      rowsByTable: byTable,
      today: DateTime.now(),
    );
  }

  /// 【所属模块】database/ledger · 资债读写
  /// 【实现功能】向指定表插一行，返回自增 id；供 AzWriteController 在同一事务里写主表 + 次表。
  /// 【使用限制】必须在 uow.run 事务内调用；values 的键必须是该表真实列名；金额列传 String。
  /// 【入参与结果】收 txn / table / values；返回 Future<int> 新行 id，调用方必须 await 并用于次表外键。
  /// 【异常与调用方处理】非法表名抛 ArgumentError；NOT NULL / UNIQUE / CHECK 失败抛 DatabaseException 并整体回滚；调用方需自行 try/catch 提示用户。
  Future<int> insert(
    DatabaseExecutor txn,
    String table,
    Map<String, Object?> values,
  ) async {
    _assertTable(table);
    return txn.insert(table, values);
  }

  /// 【所属模块】database/ledger · 资债读写
  /// 【实现功能】按主键更新一行，返回影响行数。
  /// 【使用限制】必须在事务内调用；id 必须 > 0；values 不得包含 id。
  /// 【入参与结果】收 txn / table / id / values；返回 Future<int>（通常为 1），调用方必须 await 并判 0 为未生效。
  /// 【异常与调用方处理】非法表名抛 ArgumentError；SQL 异常上抛并回滚；调用方需自行 try/catch 并提示「更新未生效」。
  Future<int> update(
    DatabaseExecutor txn,
    String table,
    int id,
    Map<String, Object?> values,
  ) async {
    _assertTable(table);
    return txn.update(table, values, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// 【所属模块】database/ledger · 资债读写
  /// 【实现功能】软删一行：写 deleted_at / delete_reason / updated_at，不物理删除。供 LifecycleService 调用（保持历史签名）。
  /// 【使用限制】必须在 uow.run 事务内调用；只对两张主表有意义；调用方负责先判断记录存在。
  /// 【入参与结果】收 txn / table / id / reason（位置参数）；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】非法表名抛 ArgumentError；SQL 异常上抛并整体回滚；调用方需自行 try/catch 提示「删除未生效」。
  Future<void> softDelete(
    DatabaseExecutor txn,
    String table,
    int id,
    String reason,
  ) async {
    _assertTable(table);
    final int now = DateTime.now().millisecondsSinceEpoch;
    await txn.update(
      table,
      <String, Object?>{
        'deleted_at': now,
        'delete_reason': reason,
        'updated_at': now,
        'revision': 1,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 【所属模块】database/ledger · 资债读写
  /// 【实现功能】恢复一条软删记录：清 deleted_at / delete_reason。供 LifecycleService 调用。
  /// 【使用限制】必须在事务内调用；只对两张主表有意义。
  /// 【入参与结果】收 txn / table / id；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】非法表名抛 ArgumentError；SQL 异常上抛并回滚；调用方需自行 try/catch。
  Future<void> restore(DatabaseExecutor txn, String table, int id) async {
    _assertTable(table);
    await txn.update(
      table,
      <String, Object?>{'deleted_at': null, 'delete_reason': null},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 【所属模块】database/ledger · 资债读写
  /// 【实现功能】设置归档标记 0/1，只改标记与留痕，不碰余额与流水。供 LifecycleService 调用。
  /// 【使用限制】必须在事务内调用；只有 az_assets 支持归档（负债主表 archived 列存在但业务不开放）。
  /// 【入参与结果】收 txn / table / id / archived；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】非法表名抛 ArgumentError；SQL 异常上抛并回滚；调用方需自行 try/catch。
  Future<void> setArchived(
    DatabaseExecutor txn,
    String table,
    int id,
    bool archived,
  ) async {
    _assertTable(table);
    await txn.update(
      table,
      <String, Object?>{
        'archived': archived ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
