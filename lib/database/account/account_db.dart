import 'package:sqflite/sqflite.dart';

import '../db_module.dart';
import 'account_record.dart';

/// 账户模块的三张表。
///
/// ══════════════════════════════════════════════════════════════════
/// 【先回答任务 3A 的那道判断题】储蓄卡与信用卡能不能放一张表？
/// ══════════════════════════════════════════════════════════════════
/// **能，而且应该。** 用一张 `accounts` 主表 + `kind` 区分，信用卡专属
/// 字段设为可空列并用 CHECK 锁死适用范围。理由不是「省一张表」，是：
///
/// 1. 共享字段占 80%：名字、形态、备注、排序、归档、软删、公共字段、
///    账本、计入总资产、初始余额……拆两张表后，账户列表、拖拽排序、
///    回收站、删除校验、记账选择器都要写两遍，且极易出现「改了这头忘了那头」。
/// 2. **「余额」和「信用卡已用额度」是同一个量纲**：3.8 / 10.9 规定
///    二者都只能由流水推导、禁止手填；3.4 规定「每消费一笔累加、每还一笔
///    扣减」。所以统一成一个 `balance` 列：
///      · 流动资金 / 受限账户 → 当前余额
///      · 信用卡              → 已用额度（欠款）
///    可用额度 = credit_limit − balance，永远是算出来的，不存第二列。
///    **但运算规则必须按类别分开**：储蓄类「入账 + / 出账 −」，信用卡
///    「消费出账 + / 还款入账 −」，见 [AccountBalanceRule]。共用一列
///    不等于共用一条公式；v6 起由流水 DAO 的必传 `rule` 参数区分。
/// 3. 统计 SQL 因此极简：能花的钱 = SUM(balance WHERE kind='liquid' AND
///    is_liquid=1)，欠银行的钱 = SUM(balance WHERE kind='credit')。
///    拆表反而要 UNION 两遍。
/// 4. 原型里三类账户卡片长得一样（只是一个 `.credit` / `.locked` 修饰），
///    一张表天然对应一套列表渲染。
///
/// 真正**不能**塞进主表的是两类东西，各用一张附属表，而不是拆主表：
///   · 受限账户绑定用途（3.5 多对多）→ `account_category_bindings`；
///   · 每笔资金变动（10.3 每账户一本流水）→ `account_entries`。
/// 「新增关联表」属于新增业务表，不是把主表改成垃圾桶。
/// 【表结构演进的原则】业务没变化、又非必要时，不为无关改动重建整表
/// 造成大面积迁移；但只要**完整功能确实需要**，该加的列、该升的版就加，
/// 不拿「不改表结构」当借口留下半截功能（见 credit_limit_after）。
///
/// ══════════════════════════════════════════════════════════════════
/// 字段出处（每条都对应《软件设计想法》，不是随手预留）
/// ══════════════════════════════════════════════════════════════════
/// | 字段 | 出处 |
/// |---|---|
/// | kind / type / name / note | 3.2 / 3.3 / 3.4 / 3.5 |
/// | balance / initial_balance | 3.8「余额是算出来的」、10.9 恒等式 |
/// | credit_limit / statement_day / due_day / repay_account_id / min_payment_rate | 3.4、原型信用卡明细 |
/// | is_liquid | 3.3 默认能花不可改、3.5 受限账户可手动改 / 社保公积金强制否 |
/// | include_in_net_worth | 3.6「真正属于你的钱」、6.3「算不算进总资产」 |
/// | sort_order / archived | 3.7 拖拽排序 / 账户归档 |
/// | deleted_at / delete_reason | 10.2 / 10.7 回收站 30 天、10.9 留痕 |
/// | book_id | 十一章「多个账本」 |
/// | created_at / updated_at / revision | 10.2 公共字段、10.9 变更留痕 |
/// | account_entries.amount / direction / balance_after / occurred_at | 10.3、10.6、10.9、附录 C/D |
/// | account_entries.credit_limit_after | 10.3 逐笔时点快照：精确还原每笔当时的总额度 / 可用额度 |
/// | account_entries.reason | 3.8 余额调整必须填原因 |
/// | account_entries.non_binding | 3.5 软约束「非绑定用途」 |
/// | account_entries.transfer_group_id / counterparty_account_id | 3.7 账户间转账 |
/// | account_entries.ref_type / ref_id / category_id / image_ref | 4.3、5.3 业务单据外挂 |
///
/// ══════════════════════════════════════════════════════════════════
/// 明确**不**放进这些表的东西（避免做成垃圾桶）
/// ══════════════════════════════════════════════════════════════════
/// · 信用卡「本期应还 / 还款计划 / 免息期」：属于账单周期计算结果，
///   将来建 `credit_statements` 表；主表只存生成它需要的账单日/还款日。
/// · 自动创建的对应负债（3.4 / 7.5）：第二阶段建 `liabilities` 表时
///   用 `liabilities.account_id` **反向引用**本表，主表不加悬空外键列。
/// · 资产↔账户联动（6.3）：同样由资产表带 account_id 反向引用。
/// · 支出/收入的业务明细（商家、报销、标签、报税、重复规则、预算）：
///   走 ref_type/ref_id 挂业务表，本表只留流水必要列。
/// · 最近使用 / 使用次数：由流水聚合，不冗余一份可能算错的计数。
/// · 变更历史 JSON 快照：将来做全局 `change_log`，revision 只给版本号。
///
/// ══════════════════════════════════════════════════════════════════
/// 约束与准确性（10.9 / 附录 A、D、E）
/// ══════════════════════════════════════════════════════════════════
/// · CHECK 锁死类别取值与「信用卡专属列只能出现在信用卡行」；
///   type 的具体形态由 Dart 枚举校验，DDL 不再写死（见 accountsDdlFor 注释）；
/// · amount > 0（10.6 只填正数，方向单独一列）；
/// · **balance 允许为负**：4.7 明确「余额不足时保存成功但给橙色提示，
///   不拦着」，所以 balance / balance_after 不加 `>= 0` 约束；
/// · 单写点：balance 唯一写入点是 AccountEntryDao.append()，
///   它在**一个事务**里同时 insert 流水 + update 账户，崩溃不会只写一半；
/// · 部分唯一索引让「归档/软删的旧名字」不占用重名名额；
/// · 流水索引覆盖「按账户按时间倒序翻明细」和「按账本按月统计」。
class AccountDb implements DbModule {
  static const String accountsTable = 'accounts';
  static const String bindingsTable = 'account_category_bindings';
  static const String entriesTable = 'account_entries';

  /// v4 → v5 重建表时按列名拷贝，**禁止 SELECT \***（列顺序不能靠猜）。
  /// 顺序与 [accountsDdlFor] 的 CREATE TABLE 一致。
  static const List<String> accountColumns = <String>[
    'id', 'book_id', 'kind', 'type', 'name', 'balance',
    'initial_balance', 'credit_limit', 'statement_day', 'due_day',
    'repay_account_id', 'min_payment_rate', 'note', 'is_liquid',
    'include_in_net_worth', 'sort_order', 'archived', 'deleted_at',
    'delete_reason', 'created_at', 'updated_at', 'revision',
  ];

  /// 账户主表的**唯一 DDL 真源**：全新安装与 v4→v5 重建共用同一份，
  /// 避免两处 SQL 各自演化成不同结构。
  ///
  /// 【为什么 DDL 不再写 CHECK (type IN (...))】
  /// v4 把 10 个形态写死在 CHECK 里，还锁了
  /// `kind='credit' → type='credit_card'`：加「花呗 / 借呗」会被数据库
  /// 直接拒写，而 SQLite 不支持 ALTER TABLE … MODIFY CHECK，只能重建表。
  /// 现在只约束 type 非空，取值合法性交给 Dart 枚举
  /// [AccountType.supports] 与两个业务 Controller 的 save 兜底校验。
  /// 于是「以后再加形态 = 加一个枚举值 + 往该类别清单加一项」，不必
  /// 重建整张主表。这是**这一处**的设计结果，不是一条全局禁令：
  /// 别处因业务需要加列时照常加（见 v6→v7）。
  /// 社保 / 公积金的 is_liquid 强制为 0 是业务规则，保留在 CHECK 里；
  /// 新增形态不会触碰这条，因此不会造成版本升级。
  static String accountsDdlFor(String table) => '''
    CREATE TABLE IF NOT EXISTS $table (
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id               TEXT    NOT NULL DEFAULT 'default',
      kind                  TEXT    NOT NULL
                            CHECK (kind IN ('liquid','credit','restricted')),
      type                  TEXT    NOT NULL,
      name                  TEXT    NOT NULL,
      balance               REAL    NOT NULL DEFAULT 0,
      initial_balance       REAL    NOT NULL DEFAULT 0
                            CHECK (initial_balance >= 0),
      credit_limit          REAL    CHECK (credit_limit IS NULL OR
                              (kind = 'credit' AND credit_limit > 0)),
      statement_day         INTEGER CHECK (statement_day IS NULL OR
                              (kind = 'credit' AND statement_day BETWEEN 1 AND 31)),
      due_day               INTEGER CHECK (due_day IS NULL OR
                              (kind = 'credit' AND due_day BETWEEN 1 AND 31)),
      repay_account_id      INTEGER CHECK (repay_account_id IS NULL OR
                              kind = 'credit'),
      min_payment_rate      REAL    NOT NULL DEFAULT 0.1
                            CHECK (min_payment_rate >= 0 AND min_payment_rate <= 1),
      note                  TEXT    NOT NULL DEFAULT '',
      is_liquid             INTEGER NOT NULL DEFAULT 1 CHECK (is_liquid IN (0,1)),
      include_in_net_worth  INTEGER NOT NULL DEFAULT 1
                            CHECK (include_in_net_worth IN (0,1)),
      sort_order            INTEGER NOT NULL DEFAULT 0,
      archived              INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0,1)),
      deleted_at            INTEGER,
      delete_reason         TEXT,
      created_at            INTEGER NOT NULL,
      updated_at            INTEGER NOT NULL,
      revision              INTEGER NOT NULL DEFAULT 1,

      -- 3.3：流动资金账户「默认为是能自由花的，用户改不了」
      CHECK (kind <> 'liquid' OR is_liquid = 1),
      -- 信用卡的已用额度是欠款，绝不混进「能花的钱」统计（3.2 / 3.6）。
      CHECK (kind <> 'credit' OR (is_liquid = 0 AND include_in_net_worth = 0)),
      -- 3.5：社保 / 公积金强制不可花（按形态锁，不按类别锁）。
      CHECK (type NOT IN ('social_security','housing_fund') OR is_liquid = 0)
    )
  ''';

  /// 主表上的两个索引，建表与重建表共用（DROP TABLE 会连带删掉旧索引）。
  static Future<void> createIndexes(DatabaseExecutor db, String table) async {
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_accounts_active_name
        ON $table (book_id, name) WHERE deleted_at IS NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_accounts_list
        ON $table (book_id, deleted_at, archived, kind, sort_order, id)
    ''');
  }

  /// v4 → v5：重建 accounts 主表，去掉写死 type 取值的 CHECK。
  ///
  /// 【工作逻辑，4 步】
  ///   1. 用 [accountsDdlFor] 建临时表 `accounts_v5`（结构与全新安装一致）；
  ///   2. 按 [accountColumns] 全列 `INSERT … SELECT` 拷贝（不用 SELECT *，
  ///      避免列顺序依赖）；
  ///   3. DROP 旧表 → ALTER TABLE … RENAME 把临时表改回 `accounts`；
  ///   4. 重建两个索引。
  /// 绑定表 / 流水表一行不动：它们按 account_id 引用，重建后 id 原样保留。
  ///
  /// 【事务边界】sqflite 的 openDatabase.onUpgrade 回调本身就在一个事务里
  /// 执行，所以本方法**不自己开 transaction**；任一步抛异常，整个升级
  /// 回滚、旧表保持原样（与 onCreate 不自建事务是同一条规矩）。
  /// 【触发条件】只有 oldV == 4 时调用；oldV < 4 的用户由 onCreate 直接
  /// 建成 v5 结构，不需要重建。见 database_shell.dart 的 _onUpgrade。
  static Future<void> migrateV4ToV5(DatabaseExecutor db) async {
    const String tmp = 'accounts_v5';
    await db.execute('DROP TABLE IF EXISTS $tmp');
    await db.execute(accountsDdlFor(tmp));
    final String cols = accountColumns.join(', ');
    await db.execute('INSERT INTO $tmp ($cols) SELECT $cols FROM $accountsTable');
    await db.execute('DROP TABLE $accountsTable');
    await db.execute('ALTER TABLE $tmp RENAME TO $accountsTable');
    await createIndexes(db, accountsTable);
  }

  /// v5 → v6：只修正**信用卡流水的方向标签**，DDL 与列结构一字节不改。
  ///
  /// 【为什么要翻转】v4/v5 把「消费」记为 in、「还款」记为 out，理由是
  /// 那时 direction 表示「累计值的增减」。本轮按业务事实改成：direction
  /// 表示资金往哪走，信用卡消费是**出账**、还款是**入账**，累计值增减
  /// 交给 [AccountBalanceRule.credit]。于是历史数据要把 in/out 对调，
  /// 否则升级后旧流水会被新规则算反。
  ///
  /// 【工作逻辑，3 步】
  ///   1. 只挑 `account_id` 属于 `kind='credit'` 账户的流水；
  ///   2. `CASE` 把 'in' ↔ 'out' 互换；
  ///   3. `balance_after` **原样保留**：它记的是当时的累计值，本来就对，
  ///      错的只是方向标签，绝对不能重算（10.9 逐笔可审计）。
  ///
  /// 【边界】`entry_type <> 'opening'`：v4/v5 的表单不给信用卡填初始余额，
  /// 正常数据不存在 credit + opening 组合；留着这个排除条件是为了万一
  /// 有历史脏数据，也不会撞 DDL 的 `opening → direction='in'` CHECK
  /// 导致整个升级失败。全新安装表为空，本语句影响 0 行。
  /// 【事务边界】openDatabase.onUpgrade 已在事务内，本方法不自建事务。
  static Future<void> migrateV5ToV6(DatabaseExecutor db) async {
    await db.execute('''
      UPDATE $entriesTable
         SET direction = CASE WHEN direction = 'in' THEN 'out' ELSE 'in' END
       WHERE entry_type <> 'opening'
         AND account_id IN (SELECT id FROM $accountsTable WHERE kind = 'credit')
    ''');
  }

  /// v6 → v7：流水表新增 `credit_limit_after`，精确还原每笔当时的额度。
  ///
  /// 【为什么必须加列】此前详情页用「**当前**总额度 − balance_after」换算
  /// 历史流水的可用额度。额度调整后，旧流水会被新额度算出一个当年根本
  /// 不存在的数字（例：当时额度 1 万、消费 200，后来调额到 2 万，回看
  /// 那笔会显示可用 1.98 万，实际当时只有 0.98 万）。信息已经丢失，
  /// 只能在写入时连同时点一起存，事后无法反推。
  ///
  /// 【工作逻辑，3 步】
  ///   1. `PRAGMA table_info` 判列是否存在：oldV < 4 的升级路径走
  ///      [onCreate] 建表时已含该列，跳过 ALTER（否则会「duplicate column」）；
  ///      全新安装同理。这一步让本方法对任何起点都幂等。
  ///   2. 只在缺失时 `ALTER TABLE … ADD COLUMN`（可空 REAL，不加 NOT NULL
  ///      默认值，SQLite 的 ADD COLUMN 限制）；
  ///   3. 逐张信用卡把它**当前**的 credit_limit 回填给历史流水（只填
  ///      `credit_limit_after IS NULL` 的行，重复执行不覆盖）；储蓄类流水
  ///      保持 NULL —— 它们没有额度概念，页面显示「变动后余额」。
  ///
  /// 【历史精度边界，如实写清】v7 之前如果调过额度，历次调额轨迹从未
  /// 被记录，无法反推，回填值只是当时的最近一次额度，属兜底；
  /// **从 v7 起，每一笔新流水都由 append 记下当时额度，完全精确**，
  /// 包括「调额前最后一笔」与「调额后第一笔」各是各的值。
  /// 【事务边界】openDatabase.onUpgrade 已在事务内，本方法不自建事务。
  static Future<void> migrateV6ToV7(DatabaseExecutor db) async {
    final List<Map<String, Object?>> columns =
        await db.rawQuery('PRAGMA table_info($entriesTable)');
    final bool hasColumn = columns.any(
      (Map<String, Object?> c) => c['name'] == 'credit_limit_after',
    );
    if (!hasColumn) {
      await db.execute(
        'ALTER TABLE $entriesTable ADD COLUMN credit_limit_after REAL',
      );
    }
    final List<Map<String, Object?>> cards = await db.query(
      accountsTable,
      columns: <String>['id', 'credit_limit'],
      where: "kind = 'credit'",
    );
    for (final Map<String, Object?> card in cards) {
      final double? limit = (card['credit_limit'] as num?)?.toDouble();
      if (limit == null) continue;
      await db.rawUpdate(
        'UPDATE $entriesTable SET credit_limit_after = ? '
        'WHERE account_id = ? AND credit_limit_after IS NULL',
        <Object?>[limit, card['id']],
      );
    }
  }

  @override
  String get name => 'account';

  /// 新建 / 升级共用，幂等：CREATE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS。
  /// 不自己开事务 —— DatabaseService._onCreate 已把模块列表包在事务里，
  /// sqflite 不支持嵌套 transaction。
  @override
  Future<void> onCreate(DatabaseExecutor db) async {
    // ── ① 账户主表：一张表装三类账户 ────────────────────────────────
    await db.execute(accountsDdlFor(accountsTable));

    await createIndexes(db, accountsTable);

    // ── ② 受限账户 ↔ 支出分类绑定（3.5 多对多，软约束）────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $bindingsTable (
        account_id   INTEGER NOT NULL,
        category_id  INTEGER NOT NULL,
        PRIMARY KEY (account_id, category_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_bindings_category
        ON $bindingsTable (category_id, account_id)
    ''');

    // ── ③ 账户出入流水（10.3 每账户一本账）───────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $entriesTable (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id                  TEXT    NOT NULL DEFAULT 'default',
        account_id               INTEGER NOT NULL,
        direction                TEXT    NOT NULL CHECK (direction IN ('in','out')),
        amount                   REAL    NOT NULL CHECK (amount > 0),
        balance_after            REAL    NOT NULL,
        -- 逐笔时点快照：这笔发生**之后**该卡的总额度。
        -- 可用额度 = credit_limit_after - balance_after，与 balance_after
        -- 在同一个事务里由 AccountEntryDao.append 写下，因此调额后回看
        -- 旧流水仍精确（不依赖「当前额度」）。储蓄类恒为 NULL。
        credit_limit_after       REAL    CHECK (credit_limit_after IS NULL OR
                                  credit_limit_after > 0),
        entry_type               TEXT    NOT NULL
                                 CHECK (entry_type IN ('opening','expense','income',
                                   'transfer_out','transfer_in','adjustment',
                                   'credit_spend','credit_repay')),
        occurred_at              INTEGER NOT NULL,
        counterparty_account_id  INTEGER,
        transfer_group_id        TEXT,
        category_id              INTEGER,
        payee                    TEXT    NOT NULL DEFAULT '',
        note                     TEXT    NOT NULL DEFAULT '',
        reason                   TEXT    NOT NULL DEFAULT '',
        non_binding              INTEGER NOT NULL DEFAULT 0 CHECK (non_binding IN (0,1)),
        image_ref                TEXT,
        ref_type                 TEXT,
        ref_id                   INTEGER,
        created_at               INTEGER NOT NULL,
        revision                 INTEGER NOT NULL DEFAULT 1,

        -- 3.8 余额调整必须填原因，且会在流水里留下「调整」记录。
        CHECK (entry_type <> 'adjustment' OR length(trim(reason)) > 0),
        -- 3.7 转账成对出现：两条流水用同一个 group id 配对。
        CHECK (entry_type NOT IN ('transfer_out','transfer_in')
               OR (transfer_group_id IS NOT NULL AND counterparty_account_id IS NOT NULL)),
        -- 开户初始余额是唯一允许「凭空」产生余额的动作，其余必须来自记账。
        -- 只有储蓄类账户有 opening（信用卡没有「期初已用额度」），
        -- 而储蓄类规则下 in = 累计值 +，所以这条 CHECK 在新规则下仍成立。
        CHECK (entry_type <> 'opening' OR direction = 'in')
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_account_time
        ON $entriesTable (account_id, occurred_at DESC, id DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_book_time
        ON $entriesTable (book_id, occurred_at, entry_type)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_transfer
        ON $entriesTable (transfer_group_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entries_ref
        ON $entriesTable (ref_type, ref_id)
    ''');
  }
}
