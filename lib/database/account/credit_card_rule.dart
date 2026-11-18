import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// 信用卡「章程」：3.4 新增的十项规则，按**这张卡自己的章程**填，
/// 不是全国统一的数。
///
/// ══════════════════════════════════════════════════════════════════
/// 【为什么单独一张表，而不是往 accounts 主表加 11 个可空列】
/// ══════════════════════════════════════════════════════════════════
/// 这些是「一两张信用卡才有、储蓄类账户永远用不上」的参数。塞进主表会
/// 让 22 列膨胀到 33 列，且每行都要挂一串 NULL；列表查询、AccountRecord
/// 的 toMap/fromMap、copyWith 也都得跟着背这些与余额无关的字段。
/// 沿用 v5 已经定下的决策：**账单周期与卡章程走一对一附属表，主表不动**
/// （当时把 statement_day / due_day 留在主表是因为它们参与提醒，属于
/// 例外；其余十项全在这里）。
///
/// 与将来 `credit_statements` 的分工：
///   · 本表存**用户填的规则**（章程，静态参数，只存不算）；
///   · `credit_statements` 存**按规则算出来的账单周期结果**（本期应还、
///     还款计划、免息期归属）。7.7 六种还款算法属于负债模块，等那个模块
///     开工时再算 —— 现在不算，就是不拿估算冒充银行账单。
///
/// 【表结构版本】v7 → v8 只**补建这一张新表**，无数据迁移、无重建：
///   · 全新安装：`AccountDb.onCreate` 末尾调 [CreditCardRuleDb.create]；
///   · 开发期老库：`DatabaseService._onUpgrade` 的 `oldV < 8` 补建段调
///     同一个 [CreditCardRuleDb.create]。
/// 两处调同一个方法、DDL 单一真源，符合「B 延后期间纪律 ①」。
/// `CREATE TABLE IF NOT EXISTS` 幂等，oldV<4 的分支已经建过一次也不会出错。
///
/// 【生命周期边界，如实写清】账户软删 / 归档后本表行**保留**，不做物理
/// 删除、不加外键级联（3.8「历史记录保留」，10.7 回收站可恢复）。
/// 账户 id 是 AUTOINCREMENT 不复用，所以恢复后章程仍然对得上。
///
/// 【动态逻辑说明】本文件全是静态定义与纯 SQL，没有状态、没有通知、
/// 没有跨帧回调。唯一一处「按旧行递增 revision」在
/// [CreditCardRuleDao.upsert] 里，工作逻辑写在该方法的紧邻注释里。
abstract final class CreditCardRuleDb {
  static const String table = 'credit_card_rules';

  /// 唯一 DDL 真源：全新安装与 v8 补建共用。
  ///
  /// 所有规则列都允许「没填」：用户嫌麻烦可以一项都不写，软件照样能
  /// 记消费与还款，只是不显示利息估算、不生成还款计划。
  /// `interest_method` 用 CHECK 锁三个取值，避免以后读到无法解释的字符串。
  static String ddlFor(String name) => '''
    CREATE TABLE IF NOT EXISTS $name (
      account_id                 INTEGER PRIMARY KEY,
      booking_day                INTEGER CHECK (booking_day IS NULL OR
                                   booking_day BETWEEN 1 AND 31),
      interest_free_days         INTEGER CHECK (interest_free_days IS NULL OR
                                   interest_free_days >= 0),
      min_payment_rule           TEXT    NOT NULL DEFAULT '',
      daily_rate                 REAL    CHECK (daily_rate IS NULL OR
                                   (daily_rate >= 0 AND daily_rate < 1)),
      interest_method            TEXT    NOT NULL DEFAULT ''
                                 CHECK (interest_method IN ('','full','unpaid')),
      monthly_compound           INTEGER NOT NULL DEFAULT 0
                                 CHECK (monthly_compound IN (0,1)),
      grace_period_days          INTEGER NOT NULL DEFAULT 0
                                 CHECK (grace_period_days >= 0),
      grace_amount               REAL    NOT NULL DEFAULT 0
                                 CHECK (grace_amount >= 0),
      cash_advance_interest_free INTEGER NOT NULL DEFAULT 0
                                 CHECK (cash_advance_interest_free IN (0,1)),
      installment_fee_rule       TEXT    NOT NULL DEFAULT '',
      late_fee_rule              TEXT    NOT NULL DEFAULT '',
      note                       TEXT    NOT NULL DEFAULT '',
      updated_at                 INTEGER NOT NULL,
      revision                   INTEGER NOT NULL DEFAULT 1
    )
  ''';

  /// 幂等建表。参数用 [DatabaseExecutor]：`_onCreate` 传事务里的
  /// `Transaction`，`_onUpgrade` 传 `Database`，两者都能收（与
  /// AccountDb.createIndexes / AccountEntryDao.append 同一套写法）。
  /// 不自己开事务 —— 调用方已经持有事务边界。
  static Future<void> create(DatabaseExecutor db) async {
    await db.execute(ddlFor(table));
  }
}

/// 计息方式（3.4）。空串 = 用户还没填，界面显示「未填写」。
enum CreditInterestMethod {
  unspecified('', '未填写'),
  full('full', '全额计息'),
  unpaid('unpaid', '只按未还部分计息');

  const CreditInterestMethod(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static CreditInterestMethod fromDb(String? value) => switch (value) {
        'full' => full,
        'unpaid' => unpaid,
        _ => unspecified,
      };
}

/// 一张信用卡的章程（一对一，没填过时全部是默认值）。
@immutable
class CreditCardRule {
  const CreditCardRule({
    required this.accountId,
    this.bookingDay,
    this.interestFreeDays,
    this.minPaymentRule = '',
    this.dailyRate,
    this.interestMethod = CreditInterestMethod.unspecified,
    this.monthlyCompound = false,
    this.gracePeriodDays = 0,
    this.graceAmount = 0,
    this.cashAdvanceInterestFree = false,
    this.installmentFeeRule = '',
    this.lateFeeRule = '',
    this.note = '',
    required this.updatedAt,
    this.revision = 1,
  });

  /// 该卡还没填过章程时的空值。表单初值用它，不返回 null，
  /// 免得每个字段都要写 `rule?.xxx ?? ...`。
  factory CreditCardRule.empty(int accountId) => CreditCardRule(
        accountId: accountId,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        revision: 0,
      );

  final int accountId;
  final int? bookingDay;
  final int? interestFreeDays;
  final String minPaymentRule;

  /// 日利率（小数，例如 0.0005 = 万分之五）。**用户手填**，软件不联网
  /// 查银行利率；只在提醒里做粗估，且必须标「估算，以账单为准」。
  final double? dailyRate;
  final CreditInterestMethod interestMethod;
  final bool monthlyCompound;
  final int gracePeriodDays;
  final double graceAmount;
  final bool cashAdvanceInterestFree;
  final String installmentFeeRule;
  final String lateFeeRule;
  final String note;
  final DateTime updatedAt;
  final int revision;

  factory CreditCardRule.fromMap(Map<String, dynamic> m) => CreditCardRule(
        accountId: (m['account_id'] as num?)?.toInt() ?? 0,
        bookingDay: m['booking_day'] as int?,
        interestFreeDays: m['interest_free_days'] as int?,
        minPaymentRule: (m['min_payment_rule'] as String?) ?? '',
        dailyRate: (m['daily_rate'] as num?)?.toDouble(),
        interestMethod: CreditInterestMethod.fromDb(
          m['interest_method'] as String?,
        ),
        monthlyCompound: (m['monthly_compound'] as int?) == 1,
        gracePeriodDays: (m['grace_period_days'] as int?) ?? 0,
        graceAmount: (m['grace_amount'] as num?)?.toDouble() ?? 0,
        cashAdvanceInterestFree:
            (m['cash_advance_interest_free'] as int?) == 1,
        installmentFeeRule: (m['installment_fee_rule'] as String?) ?? '',
        lateFeeRule: (m['late_fee_rule'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updated_at'] as num?)?.toInt() ?? 0,
        ),
        revision: (m['revision'] as int?) ?? 1,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'account_id': accountId,
        'booking_day': bookingDay,
        'interest_free_days': interestFreeDays,
        'min_payment_rule': minPaymentRule,
        'daily_rate': dailyRate,
        'interest_method': interestMethod.dbValue,
        'monthly_compound': monthlyCompound ? 1 : 0,
        'grace_period_days': gracePeriodDays,
        'grace_amount': graceAmount,
        'cash_advance_interest_free': cashAdvanceInterestFree ? 1 : 0,
        'installment_fee_rule': installmentFeeRule,
        'late_fee_rule': lateFeeRule,
        'note': note,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'revision': revision,
      };
}

/// 章程表的纯 SQL 层。无状态，业务处理器与共享账本都直接 `new` 一个
/// （与 AccountEntryDao.summaryFor 里 `AccountDao().byId(...)` 同一套用法），
/// 因此不用改 Services.initServices 的装配参数。
class CreditCardRuleDao {
  static const String table = CreditCardRuleDb.table;

  Future<CreditCardRule?> byId(Database db, int accountId) async {
    final List<Map<String, dynamic>> rows = await db.query(
      table,
      where: 'account_id = ?',
      whereArgs: <Object?>[accountId],
      limit: 1,
    );
    return rows.isEmpty ? null : CreditCardRule.fromMap(rows.first);
  }

  /// 一次读出全部章程（卡通常只有几张），供共享账本 load() 建内存快照。
  /// key = account_id，没填过章程的卡不在结果里，取用时按
  /// `CreditCardRule.empty(id)` 兜底。
  Future<Map<int, CreditCardRule>> all(Database db) async {
    final List<Map<String, dynamic>> rows = await db.query(table);
    return <int, CreditCardRule>{
      for (final Map<String, dynamic> m in rows)
        (m['account_id'] as num?)?.toInt() ?? 0: CreditCardRule.fromMap(m),
    };
  }

  /// 全量覆盖一行。
  ///
  /// 【revision 为什么在这里递增，3 步】
  ///   ① 先查旧行的 revision（没有则 0）；
  ///   ② 把 `rule.toMap()` 的 revision 覆盖成 `旧值 + 1`；
  ///   ③ `insert ... conflictAlgorithm: replace` 按主键覆盖。
  /// 这样业务层只管填字段，10.9「变更留痕」的版本号不会漏加，也不会
  /// 因为调用方传了固定 1 而每次保存都归零。事务边界由调用方持有：
  /// 本方法只有一次读 + 一次写，独立调用时由 CreditCardAccountController
  /// 包在 `db.transaction` 里。
  Future<void> upsert(
    DatabaseExecutor db,
    CreditCardRule rule,
  ) async {
    final List<Map<String, dynamic>> old = await db.query(
      table,
      columns: <String>['revision'],
      where: 'account_id = ?',
      whereArgs: <Object?>[rule.accountId],
      limit: 1,
    );
    final int previous = old.isEmpty
        ? 0
        : (old.first['revision'] as num?)?.toInt() ?? 0;
    final Map<String, dynamic> values = rule.toMap()
      ..['revision'] = previous + 1
      ..['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
