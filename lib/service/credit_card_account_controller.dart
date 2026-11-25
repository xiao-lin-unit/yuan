import 'package:sqflite/sqflite.dart';

import '../database/account/account_dao.dart';
import '../database/account/account_entry_dao.dart';
import '../database/account/account_db.dart';
import '../database/account/account_record.dart';
import '../database/account/credit_card_rule.dart';
import 'account_controller.dart';

/// 信用卡账户的业务处理器（含信用卡 / 花呗 / 借呗等信用形态）。
///
/// 【为什么单独一个 Controller】信用卡的 `balance` 记的是**已用额度**
/// （欠银行 / 平台的钱），不是「卡里有多少钱」。所以：
///   · 消费 = **出账**，已用额度 **增加**；
///   · 还款 = **入账**，已用额度 **减少**；
///   · 恒等式 `已用额度 = Σ出账 − Σ入账`，没有「期初已用额度」。
/// 规则是 [AccountBalanceRule.credit]，与储蓄类正好相反。把它和
/// SavingsAccountController 分开，是为了让每条业务规则都能在一个
/// 文件里读全，不出现「三类账户共用一条公式」的隐式假设。
///
/// 【还款 ≠ 转账，这是本类最重要的边界】转账是「钱从 A 到 B，两边都是
/// 自己的资产」；还款是「自己的钱去抵消一笔欠款」：
///   · 来源账户按 **savings** 规则扣余额；
///   · 信用卡按 **credit** 规则减已用额度；
///   · 两条流水用同一个 group 配对，但类型都是 `creditRepay`，
///     **不标** `transfer_out/in`，避免被当成普通转账计入统计；
///   · 还款金额不得超过当前已用额度（溢缴款属于另一类业务）。
///
/// 【本类还负责两件只属于信用卡的事】
///   · [repay] 的**本金 / 利息拆分**（3.7 / 7.12）：本金减欠款，利息单独
///     记成「借钱的成本」支出，两者绝不混成一条流水；
///   · [rulesFor] / [saveRules]：3.4 的卡章程十项（v8 附属表），只存不算。
///
/// 【动态逻辑说明，按项目约定写清】本类不是 ChangeNotifier：页面只 watch
/// 共享账本 [AccountController]。每个方法固定 4 步：校验 → 单事务写入
/// （append 显式传规则）→ 失败整体回滚 → `catalog.refresh` 通知页面。
class CreditCardAccountController {
  CreditCardAccountController(this.db, this.dao, this.entryDao, this.catalog);

  final Database db;
  final AccountDao dao;
  final AccountEntryDao entryDao;
  final AccountController catalog;

  static const AccountBalanceRule _rule = AccountBalanceRule.credit;

  /// 新增 / 编辑信用卡账户。
  ///
  /// 【本类别专属校验】
  ///   · [type] 必须出现在 `AccountType.allowedTypesFor(credit)` 清单里
  ///     （信用卡 / 花呗 / 借呗，不含「其他」）；
  ///   · 总额度、账单日、还款日必填且合法；
  ///   · 关联还款账户若填写，必须是流动资金账户（受限账户不能自由取钱）；
  ///   · 信用卡**不允许开户初始余额**，也不写 `opening` 流水；
  ///   · `is_liquid` / `include_in_net_worth` 恒 false（欠款不是资产）。
  /// 借呗是现金贷，放款应「流动资金账户入账 + 负债增加」两笔联动；
  /// 本轮只登记形态，不开放「借呗直接消费」，等负债模块一起做。
  Future<int> save({
    int? id,
    required AccountType type,
    required String name,
    required double creditLimit,
    required int statementDay,
    required int dueDay,
    int? repayAccountId,
    double minPaymentRate = 0.1,
    String note = '',
    String bookId = AccountDao.defaultBookId,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('账户名称不能为空');
    if (!type.supports(AccountKind.credit)) {
      throw ArgumentError('账户形态与信用卡账户不匹配');
    }
    if (creditLimit <= 0) throw ArgumentError('请填写信用卡总额度');
    if (statementDay < 1 || statementDay > 31 || dueDay < 1 || dueDay > 31) {
      throw ArgumentError('请填写账单日与还款日（1 ~ 31）');
    }
    if (minPaymentRate < 0 || minPaymentRate > 1) {
      throw ArgumentError('最低还款比例需在 0 ~ 1 之间');
    }
    if (repayAccountId != null) {
      final AccountRecord? repay = await dao.byId(db, repayAccountId);
      if (repay == null || repay.kind != AccountKind.liquid) {
        throw ArgumentError('还款账户需选择流动资金账户');
      }
    }

    final AccountRecord? old = id == null ? null : await dao.byId(db, id);
    if (old != null && old.kind != AccountKind.credit) {
      throw StateError('不能把储蓄类账户改成信用卡账户');
    }
    final DateTime now = DateTime.now();
    final AccountRecord record = AccountRecord(
      id: id,
      bookId: old?.bookId ?? bookId,
      kind: AccountKind.credit,
      type: type,
      name: name.trim(),
      // 已用额度恒由流水写；insert/update 都不覆写。
      balance: old?.balance ?? 0,
      initialBalance: 0,
      creditLimit: creditLimit,
      statementDay: statementDay,
      dueDay: dueDay,
      repayAccountId: repayAccountId,
      minPaymentRate: minPaymentRate,
      note: note,
      isLiquid: false,
      includeInNetWorth: false,
      sortOrder: old?.sortOrder ?? catalog.all.length,
      archived: old?.archived ?? false,
      deletedAt: old?.deletedAt,
      deleteReason: old?.deleteReason,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      revision: (old?.revision ?? 0) + 1,
    );

    int savedId = 0;
    await db.transaction((txn) async {
      if (id == null) {
        savedId = await dao.insert(txn, record);
        if (savedId <= 0) throw StateError('账户写入未生效');
      } else {
        final int affected = await dao.update(txn, record);
        if (affected == 0) throw StateError('账户更新未生效');
        savedId = id;
      }
    });
    await catalog.refresh(touched: <int>{savedId});
    return savedId;
  }

  /// 消费出账：direction = `out`，信用卡规则下已用额度 **+amount**。
  /// 这是「信用卡已用金额是出账金额」的写入口，不复用储蓄类的支出逻辑。
  ///
  /// 边界：金额 > 0、账户必须是信用卡。额度不足不硬拦（4.7 的口径是
  /// 提示而不是拦住），界面会显示可用额度供用户核对。
  Future<void> spend({
    required int accountId,
    required double amount,
    String note = '',
    int? categoryId,
    String payee = '',
    DateTime? occurredAt,
  }) async {
    if (amount <= 0) throw ArgumentError('消费金额必须大于 0');
    final AccountRecord? account = await dao.byId(db, accountId);
    if (account == null || account.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持消费出账');
    }
    final DateTime at = occurredAt ?? DateTime.now();
    await db.transaction((txn) async {
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: accountId,
          direction: AccountDirection.outbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.creditSpend,
          occurredAt: at,
          categoryId: categoryId,
          payee: payee,
          note: note,
          createdAt: DateTime.now(),
        ),
        rule: _rule,
      );
    });
    await catalog.refresh(touched: <int>{accountId});
  }

  /// 立即还款：**独立实现，不调用 SavingsAccountController.transfer**。
  ///
  /// 【C9-c 口径变更】还款恒定 **2 条等值流水**：还款总额
  /// `X = 本金 + 利息 + 费用综合`，来源储蓄卡一条出账、信用卡一条入账，
  /// 金额严格相等；`interest=0` 不退化。本息费在**账单出账**时由
  /// [rollStatement] 一次性记为 `debt_cost`，还款不重复记支出。
  ///
  /// ══════════════════════════════════════════════════════════════
  /// 【3.7 / 7.12 本金与利息必须分开 —— 这是正确性问题，不是文案】
  /// ══════════════════════════════════════════════════════════════
  /// [amount] 是这次从储蓄卡**一共出去的钱**（本息合计），[interest] 是
  /// 其中的利息 / 手续费。两者不能混成一条流水：
  ///   · 本金 = amount − interest：只是把现金换成「少欠一点」，
  ///     现金 −本金、欠款 −本金，正好对冲，**真正属于你的钱不变**；
  ///   · 利息 = interest：是真花掉的钱，**真正属于你的钱减少 interest**，
  ///     要单独记一条「借钱的成本」支出（4.4 默认计入「这个月一共花了多少」）。
  /// 混记会把它全当成还本金：欠款少减、支出少算，两边都错。
  ///
  /// 【工作逻辑，5 步，全部在一个事务里】
  ///   1. 校验：信用卡、来源是流动资金账户、0 ≤ interest < amount、
  ///      principal = amount − interest ≤ 当前已用额度；
  ///   2. 来源账户写 `creditRepay` 出账流水，金额 **principal**，
  ///      savings 规则 → 余额 −principal；
  ///   3. 信用卡写 `creditRepay` 入账流水，金额 **principal**，
  ///      credit 规则 → 已用额度 −principal（**只减本金**）；
  ///   4. interest > 0 时，来源账户再写一条 `expense` 出账流水，
  ///      savings 规则 → 余额 −interest，并用 `refType = 'debt_cost'`
  ///      标成「借钱的成本」：将来支出模块按 ref_type 关联到「借钱的成本」
  ///      分类，**不记第二遍**支出单据。它复用已有的 `expense` 枚举值，
  ///      DDL 的 entry_type CHECK 不用改、流水表不加列。三条共用同一个
  ///      group / counterparty 便于按组查账，但这条 `expense` 不是
  ///      transfer，不参与转账统计；
  ///   5. 成功后刷新两个账户的快照与当前明细页。
  ///
  /// 【边界】interest 默认 0 → 退化为原来的两条流水（amount 全算本金），
  /// 老调用方零改动；任一步失败整体回滚，不会出现「钱扣了、欠款没少」
  /// 或「利息记了、本金没减」。
  /// 【暂不做】7.12 的完整利息计算（全额计息 / 未还部分计息 / 复利 /
  /// 分期手续费）依赖负债模块与章程表里的规则，本方法只做**拆分入账**，
  /// 利息金额由用户按账单填写，软件不替银行算、不联网查。
  Future<void> repay({
    required int creditCardId,
    required int fromAccountId,
    required double amount,
    double interest = 0,
    String note = '',
    DateTime? occurredAt,
  }) async {
    if (amount <= 0) throw ArgumentError('还款金额必须大于 0');
    if (interest < 0) throw ArgumentError('利息金额不得为负数');
    if (interest >= amount) {
      throw ArgumentError('利息金额需小于还款金额（本金必须大于 0）');
    }
    // principal 只用于「本金不超过已用额度」的上限校验，不再拆成多条流水。
    final double principal = amount - interest;
    final AccountRecord? card = await dao.byId(db, creditCardId);
    final AccountRecord? from = await dao.byId(db, fromAccountId);
    if (card == null || card.kind != AccountKind.credit) {
      throw StateError('还款目标需为信用卡账户');
    }
    if (from == null || from.kind != AccountKind.liquid) {
      throw StateError('还款来源需为流动资金账户');
    }
    // 只对「本金」做上限校验：本息合计可以大于已用额度（差额是利息）。
    if (principal > card.balance + 0.000001) {
      throw ArgumentError('本金不能超过当前已用额度');
    }

    final DateTime at = occurredAt ?? DateTime.now();
    final String group =
        'repay_${at.microsecondsSinceEpoch}_${fromAccountId}_$creditCardId';
    await db.transaction((txn) async {
      // ① 来源账户：按本息费综合出账（C9-c）。
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: fromAccountId,
          direction: AccountDirection.outbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.creditRepay,
          occurredAt: at,
          counterpartyAccountId: creditCardId,
          transferGroupId: group,
          note: note,
          // 全局约定 11：还款类出账指债务模块还款记录；信用卡账单还款
          // 无负债侧行，ref_id 可空（未来按账单周期回填）。
          refType: 'liability_repay',
          createdAt: DateTime.now(),
        ),
        rule: AccountBalanceRule.savings,
      );
      // ② 信用卡：等值入账（已用额度减少同样的钱）。
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: creditCardId,
          direction: AccountDirection.inbound,
          amount: amount,
          balanceAfter: 0,
          entryType: AccountEntryType.creditRepay,
          occurredAt: at,
          counterpartyAccountId: fromAccountId,
          transferGroupId: group,
          note: note,
          // 配对腿共指同一条还款记录；这条只减欠款，不进统计视图。
          refType: 'liability_repay',
          createdAt: DateTime.now(),
        ),
        rule: _rule,
      );
      // ③ 已删除：息费只由 [rollStatement] 在账单出账时记一次，
      //    还款不重复记「借钱的成本」（契-12 / 硬-16）。
    });
    await catalog.refresh(touched: <int>{fromAccountId, creditCardId});
  }

  /// 已用额度校准（信用卡专属，与储蓄类的「余额调整」分开）。
  ///
  /// 【方向判断相反】`delta > 0` 表示已用额度要增加，对应**出账**；
  /// `delta < 0` 表示要减少，对应**入账**。两条判断刻意不抽公共函数，
  /// 免得以后有人「顺手复用」把两套规则又合回去。
  /// 必须填原因（DDL 对 `adjustment` 有 CHECK），差额为 0 不写流水。
  Future<void> adjustUsedAmount({
    required int accountId,
    required double actualUsed,
    required String reason,
    DateTime? occurredAt,
  }) async {
    if (reason.trim().isEmpty) throw ArgumentError('请填写校准原因');
    final AccountRecord? account = await dao.byId(db, accountId);
    if (account == null || account.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持已用额度校准');
    }
    final double delta = actualUsed - account.balance;
    if (delta == 0) return;
    final DateTime at = occurredAt ?? DateTime.now();
    await db.transaction((txn) async {
      await entryDao.append(
        txn,
        AccountEntryRecord(
          accountId: accountId,
          direction: delta > 0
              ? AccountDirection.outbound
              : AccountDirection.inbound,
          amount: delta.abs(),
          balanceAfter: 0,
          entryType: AccountEntryType.adjustment,
          occurredAt: at,
          reason: reason.trim(),
          createdAt: DateTime.now(),
        ),
        rule: _rule,
      );
    });
    await catalog.refresh(touched: <int>{accountId});
  }

  /// 调整总额度：只改属性，不动累计值、不写流水（额度不是余额）。
  Future<void> setCreditLimit(int accountId, double limit) async {
    if (limit <= 0) throw ArgumentError('信用额度必须大于 0');
    final AccountRecord? old = await dao.byId(db, accountId);
    if (old == null || old.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持调整额度');
    }
    final int affected = await dao.update(
      db,
      old.copyWith(
        creditLimit: limit,
        updatedAt: DateTime.now(),
        revision: old.revision + 1,
      ),
    );
    if (affected == 0) throw StateError('额度写入未生效');
    await catalog.refresh(touched: <int>{accountId});
  }

  /// 读取某张卡的章程（3.4 十项）。没填过返回 [CreditCardRule.empty]，
  /// 调用方不用处理 null。页面展示优先读共享账本
  /// `AccountController.cardRulesOf`（内存快照）；本方法给表单初值与
  /// 将来的负债模块用，直接查库保证拿到最新值。
  Future<CreditCardRule> rulesFor(int accountId) async {
    final CreditCardRule? rule = await CreditCardRuleDao().byId(db, accountId);
    return rule ?? CreditCardRule.empty(accountId);
  }

  /// 保存章程。**只存不算**：本方法不生成任何账单、不估算利息、不动余额。
  ///
  /// 【工作逻辑，4 步】
  ///   ① 校验账户存在且是信用卡（章程只对信用卡有意义）；
  ///   ② 强制 `rule.accountId == accountId`，避免表单传错主键；
  ///   ③ 在一个事务里 `upsert`（DAO 内部读旧 revision + 1，10.9 留痕）；
  ///   ④ `catalog.refresh` 重读账户与章程快照，通知页面重建提醒条。
  /// 【边界】账户软删后章程行保留，不物理删除（3.8 历史保留）；
  /// 写入失败事务回滚，内存快照不动。7.7 六种还款算法等负债模块开工，
  /// 现在不拿用户填的规则算「本期应还」，避免伪装成银行账单。
  Future<void> saveRules(int accountId, CreditCardRule rule) async {
    final AccountRecord? account = await dao.byId(db, accountId);
    if (account == null || account.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持填写章程');
    }
    if (rule.accountId != accountId) {
      throw ArgumentError('章程的账户编号与目标账户不一致');
    }
    await db.transaction((txn) async {
      await CreditCardRuleDao().upsert(txn, rule);
    });
    await catalog.refresh(touched: <int>{accountId});
  }

  /// 【契-13 账单出账动作】打开 / 操作时按 `last_period_key` 判跨账单日：
  /// 先归零方案 A 两列、再进新周期；同一时刻把本期息费 I+F 写成**一次**
  /// `interest + debt_cost` 出账流水（打开时只算展示值，不逐日生成流水）。
  ///
  /// 【边界，如实写明】7.7 六种计息算法归信用卡计息模块，本方法不替银行
  /// 算数：`interestAndFees` 由调用方按章程给出（当前默认 0 = 只归零、
  /// 不写流水），软件不编数、不生成假利息流水。信用卡不进负债表，
  /// 故这条流水无负债侧 `ref_id` 可对齐。
  Future<void> rollStatement(
    int creditCardId, {
    double interestAndFees = 0,
    DateTime? at,
  }) async {
    final AccountRecord? card = await dao.byId(db, creditCardId);
    if (card == null || card.kind != AccountKind.credit) {
      throw StateError('仅信用卡账户支持账单出账');
    }
    final DateTime now = at ?? DateTime.now();
    final String period =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final List<Map<String, Object?>> sub = await db.query(
      AccountDb.creditTable,
      columns: <String>['last_period_key', 'statement_day'],
      where: 'account_id = ?',
      whereArgs: <Object?>[creditCardId],
      limit: 1,
    );
    if (sub.isEmpty) return;
    if (sub.first['last_period_key'] == period) return;  // 本周期已滚动

    final int stamp = now.millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE ${AccountDb.creditTable} SET current_period_spent = ?, '
        'period_installed_amount = ?, last_period_key = ?, '
        'updated_at = ?, revision = revision + 1 WHERE account_id = ?',
        <Object?>['0', '0', period, stamp, creditCardId],
      );
      if (interestAndFees > 0) {
        await entryDao.append(
          txn,
          AccountEntryRecord(
            accountId: creditCardId,
            direction: AccountDirection.outbound,
            amount: interestAndFees,
            balanceAfter: 0,
            entryType: AccountEntryType.interest,
            occurredAt: now,
            note: '账单息费',
            refType: 'debt_cost',
            createdAt: now,
          ),
          rule: _rule,
          recordSource: 'auto',
        );
      }
    });
    await catalog.refresh(touched: <int>{creditCardId});
  }
}
