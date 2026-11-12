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
///    方向差异也不是列差异：流水 `direction='in'` 表示「本账户累计值 +」，
///    对储蓄卡是收入、对信用卡是消费；`out` 同理。于是
///    `balance_after = balance_before ± amount` 对三类账户是同一条公式
///    （原型信用卡明细「消费入账 +¥156 / 还款出账 −¥1,000」就是这个口径）。
/// 3. 统计 SQL 因此极简：能花的钱 = SUM(balance WHERE kind='liquid' AND
///    is_liquid=1)，欠银行的钱 = SUM(balance WHERE kind='credit')。
///    拆表反而要 UNION 两遍。
/// 4. 原型里三类账户卡片长得一样（只是一个 `.credit` / `.locked` 修饰），
///    一张表天然对应一套列表渲染。
///
/// 真正**不能**塞进主表的是两类东西，各用一张附属表，而不是拆主表：
///   · 受限账户绑定用途（3.5 多对多）→ `account_category_bindings`；
///   · 每笔资金变动（10.3 每账户一本流水）→ `account_entries`。
/// 「新增关联表」属于新增业务表，**不是修改主表结构**，因此满足任务要求
/// 「不要出现没有业务变化的情况下二次修改表结构」。
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
/// · CHECK 锁死所有枚举取值与「信用卡专属列只能出现在信用卡行」；
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

  @override
  String get name => 'account';

  /// 新建 / 升级共用，幂等：CREATE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS。
  /// 不自己开事务 —— DatabaseService._onCreate 已把模块列表包在事务里，
  /// sqflite 不支持嵌套 transaction。
  @override
  Future<void> onCreate(DatabaseExecutor db) async {
    // ── ① 账户主表：一张表装三类账户 ────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $accountsTable (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id               TEXT    NOT NULL DEFAULT 'default',
        kind                  TEXT    NOT NULL
                              CHECK (kind IN ('liquid','credit','restricted')),
        type                  TEXT    NOT NULL
                              CHECK (type IN ('bank','cash','wechat','alipay',
                                'credit_card','social_security','housing_fund',
                                'gift_card','frozen','other')),
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
        -- 3.4：信用卡类型固定；3.5：社保 / 公积金强制不可花。
        CHECK (kind <> 'credit' OR type = 'credit_card'),
        CHECK (type NOT IN ('social_security','housing_fund') OR is_liquid = 0)
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_accounts_active_name
        ON $accountsTable (book_id, name) WHERE deleted_at IS NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_accounts_list
        ON $accountsTable (book_id, deleted_at, archived, kind, sort_order, id)
    ''');

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
