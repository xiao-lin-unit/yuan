import 'package:sqflite/sqflite.dart';

import 'az_db.dart';
import 'az_record.dart';

/// 资债模块的纯 SQL 层。
///
/// 【职责边界】本类无状态、不通知、不认识页面；只做「一行 ↔ 一条记录」。
/// 事务边界由 [AzWriteController] 持有（10.8 即时保存、崩溃不半写），
/// 所以这里的写方法都用 [DatabaseExecutor]：既能收 `Database`，也能收
/// `Transaction`，与 AccountEntryDao.append 同一套写法。
///
/// 【静态优先】没有缓存、没有 Notifier、没有跨帧回调。共享账本
/// [AzController] 负责在启动时把快照一次读进内存，页面不在这里逐条查。
class AzDao {
  /// 一次读齐模块全部数据。归档 / 软删的行**也读进来**：
  /// 10.7「所有操作可逆」，过滤掉之后页面就没有恢复入口了。
  /// 真正的「在用」过滤统一在 [AzData.activeAssets] 等 getter 里做。
  Future<AzData> loadAll(DatabaseExecutor db) async {
    final List<Map<String, Object?>> assets = await db.query(
      AzDb.assetsTable,
      orderBy: 'asset_class ASC, sort_order ASC, id ASC',
    );
    final List<Map<String, Object?>> liabilities = await db.query(
      AzDb.liabilitiesTable,
      orderBy: 'sort_order ASC, id ASC',
    );
    final List<Map<String, Object?>> plans = await db.query(
      AzDb.plansTable,
      orderBy: 'liability_id ASC, plan_version ASC, term_no ASC',
    );
    final List<Map<String, Object?>> trades = await db.query(
      AzDb.tradesTable,
      orderBy: 'asset_id ASC, occurred_at DESC, id DESC',
    );
    final List<Map<String, Object?>> contingents = await db.query(
      AzDb.contingentsTable,
      orderBy: 'kind ASC, sort_order ASC, id ASC',
    );
    final List<Map<String, Object?>> prefs =
        await db.query(AzDb.preferencesTable);
    return AzData(
      assets: assets.map(AssetRecord.fromMap).toList(growable: false),
      liabilities:
          liabilities.map(LiabilityRecord.fromMap).toList(growable: false),
      plans: plans.map(RepayPlanRecord.fromMap).toList(growable: false),
      trades: trades.map(AssetTradeRecord.fromMap).toList(growable: false),
      contingents:
          contingents.map(ContingentRecord.fromMap).toList(growable: false),
      preferences: AzPreferences.fromRows(prefs),
    );
  }

  /// 新增或整行覆盖一张资产。id 为 null 时 insert 并返回新 id。
  ///
  /// 【revision 在这里递增，3 步】① 先读旧行版本号；② 覆盖成 旧值+1；
  /// ③ 写库。业务层只管填字段，10.9「变更留痕」不会漏加，也不会因为
  /// 调用方传了固定 1 而每次归零。事务由调用方持有。
  Future<int> saveAsset(DatabaseExecutor db, AssetRecord record) async {
    final Map<String, Object?> values = record.toMap();
    final int? id = record.id;
    if (id == null) {
      return db.insert(AzDb.assetsTable, values);
    }
    values['revision'] = await _nextRevision(
      db,
      AzDb.assetsTable,
      id,
      record.revision,
    );
    values['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      AzDb.assetsTable,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return id;
  }

  Future<int> saveLiability(DatabaseExecutor db, LiabilityRecord record) async {
    final Map<String, Object?> values = record.toMap();
    final int? id = record.id;
    if (id == null) {
      return db.insert(AzDb.liabilitiesTable, values);
    }
    values['revision'] = await _nextRevision(
      db,
      AzDb.liabilitiesTable,
      id,
      record.revision,
    );
    values['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      AzDb.liabilitiesTable,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return id;
  }

  Future<int> saveContingent(
    DatabaseExecutor db,
    ContingentRecord record,
  ) async {
    final Map<String, Object?> values = record.toMap();
    final int? id = record.id;
    if (id == null) {
      return db.insert(AzDb.contingentsTable, values);
    }
    values['revision'] = await _nextRevision(
      db,
      AzDb.contingentsTable,
      id,
      record.revision,
    );
    values['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      AzDb.contingentsTable,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return id;
  }

  /// 记一笔买入 / 卖出。卖出的 [costBasis] / [realizedPnl] 由
  /// AzMath.tradeSummary 先算出当时平均成本后由业务层填入，历史不覆盖。
  Future<int> insertTrade(DatabaseExecutor db, AssetTradeRecord record) =>
      db.insert(AzDb.tradesTable, record.toMap());

  /// 一次写入一批还款计划（同一个 plan_version）。
  /// 重算时**不删旧版本**：旧行留着可对比（7.8），只是主表的
  /// active_plan_version 指向新版本，页面只显示生效的那一版。
  Future<void> insertPlans(
    DatabaseExecutor db,
    List<RepayPlanRecord> rows,
  ) async {
    for (final RepayPlanRecord row in rows) {
      await db.insert(
        AzDb.plansTable,
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> markPlanPaid(
    DatabaseExecutor db,
    int planId,
    double actualAmount,
    String reason,
  ) async {
    await db.update(
      AzDb.plansTable,
      <String, Object?>{
        'status': PlanStatus.paid.dbValue,
        'paid_at': DateTime.now().millisecondsSinceEpoch,
        'actual_amount': actualAmount,
        'reason': reason,
      },
      where: 'id = ?',
      whereArgs: <Object?>[planId],
    );
  }

  Future<void> setActivePlanVersion(
    DatabaseExecutor db,
    int liabilityId,
    int version,
  ) async {
    await db.update(
      AzDb.liabilitiesTable,
      <String, Object?>{
        'active_plan_version': version,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[liabilityId],
    );
  }

  /// 记录 / 显示口径开关。切估值口径要留痕（6.4 / 10.9），
  /// 所以每次写入都把 revision +1，updated_at 记下时间。
  Future<void> setPreference(
    DatabaseExecutor db,
    String key,
    String value,
  ) async {
    final List<Map<String, Object?>> old = await db.query(
      AzDb.preferencesTable,
      columns: <String>['revision'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    final int previous = old.isEmpty
        ? 0
        : (old.first['revision'] as num?)?.toInt() ?? 0;
    await db.insert(
      AzDb.preferencesTable,
      <String, Object?>{
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'revision': previous + 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 月末快照表由分析模块（8.1.3 / 8.1.4 / 13.12）接管：DDL 保留在
  /// 本模块建表，但资债不再读写它，不留下「点了没反应」的半成品入口。

  /// 软删进回收站（10.2 / 10.7）：保留历史记录，30 天内可恢复。
  /// [reason] 必填，与账户「余额调整必须填原因」同一条留痕规矩。
  Future<void> softDelete(
    DatabaseExecutor db,
    String table,
    int id,
    String reason,
  ) async {
    await db.update(
      table,
      <String, Object?>{
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'delete_reason': reason,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> restore(DatabaseExecutor db, String table, int id) async {
    await db.update(
      table,
      <String, Object?>{'deleted_at': null, 'delete_reason': null},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> setArchived(
    DatabaseExecutor db,
    String table,
    int id,
    bool archived,
  ) async {
    await db.update(
      table,
      <String, Object?>{
        'archived': archived ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 「万一这笔要我还」→ 正式转成一条真实负债（7.11 唯一入口）。
  /// 由业务层在一个事务里：插负债 + 软删原或有项，保证不会两边都算。
  Future<int> insertLiabilityFromContingent(
    DatabaseExecutor db,
    LiabilityRecord record,
    int contingentId,
  ) async {
    final int newId = await db.insert(AzDb.liabilitiesTable, record.toMap());
    await softDelete(
      db,
      AzDb.contingentsTable,
      contingentId,
      '已转成我欠的钱（负债 #$newId）',
    );
    return newId;
  }

  /// 「重名校验」：同一账本下未删除的行不能同名（部分唯一索引兜底，
  /// 这里提前给表单一句人话提示）。
  Future<bool> nameExists(
    DatabaseExecutor db,
    String table,
    String name, {
    int? exceptId,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      columns: <String>['id'],
      where: 'name = ? AND deleted_at IS NULL AND id <> ?',
      whereArgs: <Object?>[name, exceptId ?? -1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 删掉一个资产前数它的买卖记录（3.8「这个账户下还有 XX 笔记录」同款）。
  Future<int> countTrades(DatabaseExecutor db, int assetId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${AzDb.tradesTable} WHERE asset_id = ?',
      <Object?>[assetId],
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<int> countPlans(DatabaseExecutor db, int liabilityId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${AzDb.plansTable} WHERE liability_id = ?',
      <Object?>[liabilityId],
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<int> _nextRevision(
    DatabaseExecutor db,
    String table,
    int id,
    int fallback,
  ) async {
    final List<Map<String, Object?>> old = await db.query(
      table,
      columns: <String>['revision'],
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (old.isEmpty) return fallback;
    return ((old.first['revision'] as num?)?.toInt() ?? 0) + 1;
  }
}
