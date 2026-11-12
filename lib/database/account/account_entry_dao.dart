import 'package:sqflite/sqflite.dart';

import '../../components.dart';
import 'account_dao.dart';
import 'account_db.dart';
import 'account_record.dart';

/// 出入流水的纯 SQL 层，也是**账户累计值的唯一写入点**。
///
/// 【准确性铁律 10.9 / 附录 E「单写点原则」】
/// `accounts.balance` 禁止在别处覆写：只有 [append] 会改它，而且
/// 「insert 一条流水」+「update 账户累计值」永远在同一个事务里完成。
/// 因此崩溃恢复后不会出现「流水记了但余额没变」或反之。
///
/// 【为什么 balance 要物化一列，而不是每次 SUM】
/// 3.8 说的是「余额是算出来的，不是**填**出来的」——禁止用户手填，
/// 不是禁止物化存储。逐笔存 `balance_after` 后，明细页能直接显示
/// 「进出后余额变成多少」（10.3），恒等式也能逐行回放审计；纯 SUM
/// 方案在几万条流水时每次翻页都要全表扫描，且无法还原历史时点。
///
/// [append] 不自己开事务：调用方（AccountController）负责把「一次业务
/// 动作」包进 `db.transaction`。转账要写两条流水、改两个账户，必须是
/// 同一个事务，否则会只扣了一头（3.7 / 附录 A「两边状态原子同步」）。
class AccountEntryDao implements BaseDao {
  static const String table = AccountDb.entriesTable;
  static const String accountsTable = AccountDb.accountsTable;

  @override
  String get name => 'account_entry';

  /// 追加一条流水并同步账户累计值。
  ///
  /// 工作逻辑（4 步，全部在调用方给的事务执行器 [txn] 内）：
  ///   1. 在事务内读该账户**当前**累计值（不读内存快照，避免并发/过期数据）；
  ///   2. `after = before + direction.sign * amount`；金额恒正，符号只由
  ///      方向决定，三类账户同一条公式（见 AccountDirection 注释）；
  ///   3. insert 流水（带 balance_after）；
  ///   4. `UPDATE accounts SET balance = after, revision = revision + 1`
  ///      并检查受影响行数，0 行则整条事务回滚。
  /// 返回变动后的累计值，供 Controller 做后续提示 / 校验。
  ///
  /// 边界：账户不存在 / 已软删 → 抛 StateError 让事务回滚；
  /// amount <= 0 由 DDL 的 CHECK 挡住，业务层也会提前校验（10.6）。
  Future<double> append(
    DatabaseExecutor txn,
    AccountEntryRecord entry,
  ) async {
    final rows = await txn.query(
      accountsTable,
      columns: <String>['balance'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[entry.accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('账户不存在或已删除，不能记流水');
    }
    final double before = (rows.first['balance'] as num?)?.toDouble() ?? 0;
    final double after = before + entry.direction.sign * entry.amount;

    final Map<String, dynamic> values = entry.toMap()
      ..['balance_after'] = after;
    final int id = await txn.insert(table, values);
    if (id <= 0) throw StateError('流水写入未生效');

    final int affected = await txn.rawUpdate(
      'UPDATE $accountsTable SET balance = ?, updated_at = ?, '
      'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
      <Object?>[
        after,
        DateTime.now().millisecondsSinceEpoch,
        entry.accountId,
      ],
    );
    if (affected == 0) throw StateError('账户余额同步未生效');
    return after;
  }

  /// 某账户的流水（按交易时间倒序，附录 C）。
  Future<List<AccountEntryRecord>> listForAccount(
    Database db,
    int accountId, {
    int? limit,
    DateTime? from,
    DateTime? to,
  }) async {
    final List<String> where = <String>['account_id = ?'];
    final List<Object?> args = <Object?>[accountId];
    if (from != null) {
      where.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('occurred_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.query(
      table,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(AccountEntryRecord.fromMap).toList(growable: false);
  }

  /// 明细页顶部「总入账 / 总出账 / 净变动 / 当前余额」。
  Future<AccountEntrySummary> summaryFor(
    Database db,
    int accountId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final List<String> where = <String>['account_id = ?'];
    final List<Object?> args = <Object?>[accountId];
    if (from != null) {
      where.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('occurred_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final String clause = where.join(' AND ');
    final rows = await db.rawQuery(
      'SELECT '
      " COALESCE(SUM(CASE WHEN direction = 'in' THEN amount ELSE 0 END), 0) AS inc,"
      " COALESCE(SUM(CASE WHEN direction = 'out' THEN amount ELSE 0 END), 0) AS out"
      ' FROM $table WHERE $clause',
      args,
    );
    final AccountRecord? account = await AccountDao().byId(db, accountId);
    return AccountEntrySummary(
      inbound: (rows.first['inc'] as num?)?.toDouble() ?? 0,
      outbound: (rows.first['out'] as num?)?.toDouble() ?? 0,
      balanceAfter: account?.balance ?? 0,
    );
  }

  /// 恒等式审计（10.9）：期初 + Σ入 − Σ出 必须等于当前 balance。
  /// 供「余额对不上」时排查，不参与 UI；返回差值，0 表示账实相符。
  Future<double> auditBalance(Database db, int accountId) async {
    final AccountRecord? account = await AccountDao().byId(db, accountId);
    if (account == null) return 0;
    final AccountEntrySummary summary = await summaryFor(db, accountId);
    return (account.initialBalance + summary.net) - account.balance;
  }
}
