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
/// [append] 不自己开事务：调用方（两个业务 Controller）负责把「一次业务
/// 动作」包进 `db.transaction`。转账 / 还款要写两条流水、改两个账户，
/// 必须是同一个事务，否则会只扣了一头（3.7 / 附录 A）。
///
/// 【规则由调用方显式传，DAO 不读账户类别】见 [AccountBalanceRule] 注释：
/// 储蓄类与信用卡的累计值方向相反，`rule` 没有默认值，漏传就编译不过。
class AccountEntryDao implements BaseDao {
  static const String table = AccountDb.entriesTable;
  static const String accountsTable = AccountDb.accountsTable;

  @override
  String get name => 'account_entry';

  /// 追加一条流水并同步账户累计值。
  ///
  /// 工作逻辑（4 步，全部在调用方给的事务执行器 [txn] 内）：
  ///   1. 在事务内读该账户**当前**累计值与总额度（不读内存快照，
  ///      避免并发/过期数据）；
  ///   2. `after = before + rule.delta(direction, amount)`。金额恒正，
  ///      符号由 direction 与 [rule] 共同决定：储蓄类入账加、信用卡
  ///      出账加（见 [AccountBalanceRule]）；**不再有「三类同一条公式」**；
  ///   3. insert 流水（带 balance_after；信用卡同时写
  ///      credit_limit_after = 该笔之后的总额度，储蓄类为 null）。
  ///      两者都是**逐笔时点快照**，与累计值在同一事务里锁定，
  ///      所以日后调额也不会改变旧流水能还原出的可用额度；
  ///   4. `UPDATE accounts SET balance = after, revision = revision + 1`
  ///      并检查受影响行数，0 行则整条事务回滚。
  /// 返回变动后的累计值，供 Controller 做后续提示 / 校验。
  ///
  /// 边界：账户不存在 / 已软删 → 抛 StateError 让事务回滚；
  /// amount <= 0 由 DDL 的 CHECK 挡住，业务层也会提前校验（10.6）。
  Future<double> append(
    DatabaseExecutor txn,
    AccountEntryRecord entry, {
    required AccountBalanceRule rule,
  }) async {
    final rows = await txn.query(
      accountsTable,
      columns: <String>['balance', 'credit_limit'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[entry.accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('账户不存在或已删除，不能记流水');
    }
    final double before = (rows.first['balance'] as num?)?.toDouble() ?? 0;
    final double after = before + rule.delta(entry.direction, entry.amount);
    // 只有信用卡规则写额度快照；储蓄类留 null。用 rule 而不是读账户
    // kind 判断，保持「DAO 不解释账户类别、规则由调用方显式给」的约定。
    final double? limitAfter = rule == AccountBalanceRule.credit
        ? (rows.first['credit_limit'] as num?)?.toDouble()
        : null;

    final Map<String, dynamic> values = entry.toMap()
      ..['balance_after'] = after
      ..['credit_limit_after'] = limitAfter;
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
  ///
  /// 【真分页】[limit] + [offset] 直接下推到 SQLite，不把几万条流水读进
  /// 内存后再截断。[direction] 给「全部 / 出账 / 入账」标签用，null = 不过滤。
  /// 排序固定 `occurred_at DESC, id DESC`，所以第 1 页就是最近 10 条。
  Future<List<AccountEntryRecord>> listForAccount(
    Database db,
    int accountId, {
    int? limit,
    int? offset,
    AccountDirection? direction,
    DateTime? from,
    DateTime? to,
  }) async {
    final List<String> where = <String>['account_id = ?'];
    final List<Object?> args = <Object?>[accountId];
    if (direction != null) {
      where.add('direction = ?');
      args.add(direction.dbValue);
    }
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
      offset: offset,
    );
    return rows.map(AccountEntryRecord.fromMap).toList(growable: false);
  }

  /// 满足条件的流水总条数，用于算总页数 / 标签条数。
  /// 与 [listForAccount] 共用同一套 where 条件，两者永远同源。
  Future<int> countForAccount(
    Database db,
    int accountId, {
    AccountDirection? direction,
    DateTime? from,
    DateTime? to,
  }) async {
    final List<String> where = <String>['account_id = ?'];
    final List<Object?> args = <Object?>[accountId];
    if (direction != null) {
      where.add('direction = ?');
      args.add(direction.dbValue);
    }
    if (from != null) {
      where.add('occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('occurred_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE ${where.join(' AND ')}',
      args,
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
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

  /// 恒等式审计（10.9）：返回「按规则算出的应有累计值 − 实际 balance」，
  /// 0 表示账实相符。供「余额对不上」时排查，不参与 UI。
  ///
  /// 【为什么这里按 kind 选规则，而 append 要显式传】审计是**读**路径，
  /// 本来就从 DB 读出了完整账户行，能安全推出规则；append 是**写**路径，
  /// 必须让处理器在调用点把规则说清楚，二者不矛盾。
  /// 信用卡没有「期初已用额度」，恒等式是 `Σ出账 − Σ入账`。
  Future<double> auditBalance(Database db, int accountId) async {
    final AccountRecord? account = await AccountDao().byId(db, accountId);
    if (account == null) return 0;
    final AccountEntrySummary summary = await summaryFor(db, accountId);
    final double expected = AccountBalanceRule.of(account.kind) ==
            AccountBalanceRule.savings
        ? account.initialBalance + summary.net
        : -summary.net;
    return expected - account.balance;
  }
}
