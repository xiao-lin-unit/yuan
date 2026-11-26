import 'package:sqflite/sqflite.dart';

import '../../components.dart';
import 'account_dao.dart';
import 'account_db.dart';
import 'account_record.dart';
import '../../utils/money.dart';

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
    String recordSource = 'user',
  }) async {
    // 【B2 阻断级】credit_limit 已下放 account_credit 次表：按 rule 分路
    // JOIN 取额度，不再从主表读；同时取 book_id（B15）与本期消费额。
    final bool isCredit = rule == AccountBalanceRule.credit;
    final List<Map<String, Object?>> rows = isCredit
        ? await txn.rawQuery(
            'SELECT a.balance AS balance, a.book_id AS book_id, '
            ' c.credit_limit AS credit_limit, '
            ' c.current_period_spent AS current_period_spent '
            ' FROM $accountsTable a '
            ' LEFT JOIN ${AccountDb.creditTable} c ON c.account_id = a.id '
            ' WHERE a.id = ? AND a.deleted_at IS NULL LIMIT 1',
            <Object?>[entry.accountId],
          )
        : await txn.rawQuery(
            'SELECT a.balance AS balance, a.book_id AS book_id, '
            ' i.net_transfer_in AS net_transfer_in '
            ' FROM $accountsTable a '
            ' LEFT JOIN ${AccountDb.investmentTable} i ON i.account_id = a.id '
            ' WHERE a.id = ? AND a.deleted_at IS NULL LIMIT 1',
            <Object?>[entry.accountId],
          );
    if (rows.isEmpty) {
      throw StateError('账户不存在或已删除，不能记流水');
    }
    // 【全局约定 2】DB 是 TEXT、累加全程 int 分，绝不走 double。
    final int before = Money.parse(rows.first['balance'] as String?);
    final int after = before +
        rule.deltaCents(entry.direction, Money.centsOf(entry.amount));
    final String? limitAfter =
        isCredit ? rows.first['credit_limit'] as String? : null;

    // 【契-15 / 本轮】K4 净转入额在「储蓄↔投资转入 / 转出」与「余额调整」
    // 两个时机同步增减，增量符号与 balance 完全一致（in 加 / out 减，
    // 由 rule.deltaCents 给出，不再按 entryType 手写正负号）。
    // 买入扣款 / 卖出到账 / 开户 opening 都不改这一列：
    // 开户期初值由新建账户事务直接落 account_investment（表单给初值）。
    // K1/K3 没有 investment 行、K2 走 isCredit 分支，都天然跳过。
    final String? netTransferIn =
        isCredit ? null : rows.first['net_transfer_in'] as String?;
    final bool netTransferChanged =
        entry.entryType == AccountEntryType.transferIn ||
            entry.entryType == AccountEntryType.transferOut ||
            entry.entryType == AccountEntryType.adjustment;
    if (netTransferIn != null && netTransferChanged) {
      final int signedDelta =
          rule.deltaCents(entry.direction, Money.centsOf(entry.amount));
      final int net = Money.parse(netTransferIn) + signedDelta;
      await txn.rawUpdate(
        'UPDATE ${AccountDb.investmentTable} SET net_transfer_in = ?, '
        'updated_at = ?, revision = revision + 1 WHERE account_id = ?',
        <Object?>[
          Money.format(net),
          DateTime.now().millisecondsSinceEpoch,
          entry.accountId,
        ],
      );
    }

    // 【方案 A】本期消费额与流水同事务累加；列是当期缓存，不是第二真源。
    // 账单出账归零由 CreditCardAccountController.rollStatement 负责。
    if (isCredit && entry.entryType == AccountEntryType.creditSpend) {
      final int spent =
          Money.parse(rows.first['current_period_spent'] as String?);
      await txn.rawUpdate(
        'UPDATE ${AccountDb.creditTable} SET current_period_spent = ?, '
        'updated_at = ?, revision = revision + 1 WHERE account_id = ?',
        <Object?>[
          Money.format(spent + Money.centsOf(entry.amount)),
          DateTime.now().millisecondsSinceEpoch,
          entry.accountId,
        ],
      );
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> values = entry.toMap()
      ..['balance_after'] = Money.format(after)
      ..['credit_limit_after'] = limitAfter
      ..['book_id'] = (rows.first['book_id'] as String?) ?? 'default'
      ..['record_source'] = recordSource
      ..['updated_at'] = now;
    final int id = await txn.insert(table, values);
    if (id <= 0) throw StateError('流水写入未生效');

    final int affected = await txn.rawUpdate(
      'UPDATE $accountsTable SET balance = ?, updated_at = ?, '
      'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
      <Object?>[Money.format(after), now, entry.accountId],
    );
    if (affected == 0) throw StateError('账户余额同步未生效');
    return Money.toYuan(after);
  }

  /// 某账户的流水（按交易时间倒序，附录 C）。
  ///
  /// 【真分页】[limit] + [offset] 直接下推到 SQLite，不把几万条流水读进
  /// 内存后再截断。[direction] 给「全部 / 出账 / 入账」标签用，null = 不过滤。
  /// 排序固定 `occurred_at DESC, id DESC`，所以第 1 页就是最近 10 条。
  Future<List<AccountEntryRecord>> listForAccount(
    DatabaseExecutor db,
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
    DatabaseExecutor db,
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
    DatabaseExecutor db,
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
      " COALESCE(SUM(CASE WHEN direction = 'in' THEN CAST(amount AS REAL) ELSE 0 END), 0) AS inc,"
      " COALESCE(SUM(CASE WHEN direction = 'out' THEN CAST(amount AS REAL) ELSE 0 END), 0) AS out"
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

  /// 账户使用频次 / 最近使用（只读聚合，供「常用账户」「记支出时预选
  /// 上次使用账户」备用）。**当前不接 UI**：常用的展示规则还没定，
  /// 先把数据能力备好，等「记支出」模块确定口径后直接取用。
  ///
  /// 【工作逻辑，3 步】
  ///   1. 可选按 [refType] 过滤：传 `'expense'` 只统计真实支出单据，
  ///      不传则按该账户的全部流水统计（含开户 / 转账 / 还款 / 校准）；
  ///   2. `GROUP BY account_id` 聚合出 `COUNT(*)` 与 `MAX(occurred_at)`；
  ///   3. 按最后使用时间倒序、次数倒序取前 [limit] 条。
  ///
  /// 【边界，如实写明】目前「记支出 / 记收入」模块尚未开发，流水里的
  /// `ref_type` 全是 NULL，所以传 `refType: 'expense'` 会返回空列表；
  /// 不传过滤则能拿到账户内部操作的活跃顺序，可作为开发期调试用，
  /// 但它**不是**最终意义上的「记账常用」。等支出单据写入后再启用
  /// 过滤参数，无需改表、无需迁移。
  /// 无数据时返回空列表，不抛异常。
  Future<List<AccountUsage>> usageByAccount(
    DatabaseExecutor db, {
    int limit = 5,
    String? refType,
  }) async {
    final List<String> where = <String>[];
    final List<Object?> args = <Object?>[];
    if (refType != null) {
      where.add('ref_type = ?');
      args.add(refType);
    }
    final String clause =
        where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT account_id AS account_id, COUNT(*) AS use_count, '
      ' MAX(occurred_at) AS last_used_at '
      ' FROM $table $clause '
      ' GROUP BY account_id '
      ' ORDER BY last_used_at DESC, use_count DESC '
      ' LIMIT ?',
      <Object?>[...args, limit],
    );
    return <AccountUsage>[
      for (final Map<String, Object?> r in rows)
        AccountUsage(
          accountId: (r['account_id'] as num?)?.toInt() ?? 0,
          useCount: (r['use_count'] as num?)?.toInt() ?? 0,
          lastUsedAt: DateTime.fromMillisecondsSinceEpoch(
            (r['last_used_at'] as num?)?.toInt() ?? 0,
          ),
        ),
    ];
  }

  /// 【全局约定 10】三个统计视图取数：生活成本 / 实际支出 / 资产抵消。
  ///
  /// 【工作逻辑】先限定「非 K2 存储账户 + direction='out' + 未软删账户」，
  /// 再按 `entry_type` 分两组：消费类 `expense`、还款类 `credit_repay`。
  /// 金额取 `amount` 全额、不分本金利息；`assetOffset` 是 `actualExpense`
  /// 的子集，同源不重复写数。K2 的 `credit_spend` / `interest` 动的是额度
  /// 与欠款，不进视图；账单出账息费也不另计（已含在还款金额里）。
  /// **取数不依赖 `ref_type`**：支出 / 收入模块未开工、ref_id 全空也能算。
  Future<AccountExpenseStats> expenseStats(
    DatabaseExecutor db, {
    String bookId = 'default',
    DateTime? from,
    DateTime? to,
  }) async {
    final List<String> where = <String>[
      'e.direction = ?',
      "a.kind <> 'credit'",
      'a.deleted_at IS NULL',
      'e.book_id = ?',
    ];
    final List<Object?> args = <Object?>['out', bookId];
    if (from != null) {
      where.add('e.occurred_at >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('e.occurred_at < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT '
      " COALESCE(SUM(CASE WHEN e.entry_type = 'expense' "
      '   THEN CAST(e.amount AS REAL) ELSE 0 END), 0) AS direct,'
      " COALESCE(SUM(CASE WHEN e.entry_type = 'credit_repay' "
      '   THEN CAST(e.amount AS REAL) ELSE 0 END), 0) AS indirect'
      ' FROM $table e JOIN $accountsTable a ON a.id = e.account_id'
      ' WHERE ${where.join(' AND ')}',
      args,
    );
    final double direct =
        (rows.first['direct'] as num?)?.toDouble() ?? 0;
    final double indirect =
        (rows.first['indirect'] as num?)?.toDouble() ?? 0;
    return AccountExpenseStats(
      livingCost: direct,
      actualExpense: direct + indirect,
      assetOffset: indirect,
    );
  }

  /// 恒等式审计（10.9）：返回「按规则算出的应有累计值 − 实际 balance」，
  /// 0 表示账实相符。供「余额对不上」时排查，不参与 UI。
  ///
  /// 【为什么这里按 kind 选规则，而 append 要显式传】审计是**读**路径，
  /// 本来就从 DB 读出了完整账户行，能安全推出规则；append 是**写**路径，
  /// 必须让处理器在调用点把规则说清楚，二者不矛盾。
  /// 信用卡没有「期初已用额度」，恒等式是 `Σ出账 − Σ入账`。
  Future<double> auditBalance(DatabaseExecutor db, int accountId) async {
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
