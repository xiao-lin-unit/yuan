import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/account/account_dao.dart';
import '../database/account/account_entry_dao.dart';
import '../database/account/account_record.dart';
import '../database/account/credit_card_rule.dart';

/// 账户模块的**共享账本**（ChangeNotifier，由 Services.initServices 装配）。
///
/// ══════════════════════════════════════════════════════════════════
/// 【职责边界：查询留在这里，资金更新拆给两个业务 Controller】
/// ══════════════════════════════════════════════════════════════════
/// 三类账户要在同一个首页分组显示、名称唯一索引跨类生效，所以「账户
/// 快照 / 明细 / 统计 / 绑定查询 / 重名校验」必须只有一份真源，就是本类。
///
/// 凡是涉及资金方向与累计值的写操作，一律不在这里：
///   · 流动资金账户 + 其他资金账户（都是储蓄类型卡）
///       → SavingsAccountController（save / transfer / adjustBalance / setBindings）
///   · 信用卡账户
///       → CreditCardAccountController（save / spend / repay / adjustUsedAmount /
///         setCreditLimit）
/// 两个处理器各自持有自己的事务与规则（[AccountBalanceRule]），互不调用、
/// 互不复用实现；写完之后统一调本类的 [refresh] 重读快照并通知页面。
/// 本类保留的是**不含资金口径**的通用记录维护：归档 / 恢复 / 排序 /
/// 回收站删除，这些动作只改标记，不写流水、不动 balance。
///
/// 【动态逻辑说明，按项目约定写清】
/// 为什么动态：账户列表、余额、流水会随用户操作变化，构造期定不死。
/// 这里用最朴素的 ChangeNotifier，与 CategoryController 同一套：
///   1. `_all` 是数据库里未删账户在内存里的一份只读快照；
///   2. 写操作由业务处理器 **先 await 落库（事务）→ 再 refresh() 重读 →
///      notifyListeners()**（10.8 即时保存；失败时内存保持旧值）；
///   3. 页面用 `context.watch<AccountController>()` 读，不另存一份列表。
/// 没有 Notifier 嵌套、没有跨帧注册、没有隐藏双模式。
///
/// 【准确性铁律 10.9】账户累计值只允许 AccountEntryDao.append 写，
/// 本类不 UPDATE balance，也不决定任何流水的方向或规则。
class AccountController extends ChangeNotifier {
  AccountController(this.db, this.dao, this.entryDao);

  final Database db;
  final AccountDao dao;
  final AccountEntryDao entryDao;

  List<AccountRecord> _all = <AccountRecord>[];
  final Map<int, Set<int>> _bindings = <int, Set<int>>{};

  /// 信用卡章程的内存快照（v8，key = account_id）。
  /// 【为什么也放进共享账本】它是**只读查询数据**，与账户快照同源、同
  /// 生命周期：写章程后由 CreditCardAccountController.saveRules 调
  /// [refresh] → [load] 一起重读，页面 build 里可同步取用，不需要
  /// FutureBuilder，也不引入第二份状态。没填过章程的卡不在表里，
  /// [cardRulesOf] 返回 [CreditCardRule.empty]。
  final Map<int, CreditCardRule> _cardRules = <int, CreditCardRule>{};

  // 明细页的**当前页**快照（真分页：内存里永远只有 pageSize 条）。
  List<AccountEntryRecord> _detailEntries = <AccountEntryRecord>[];
  AccountEntrySummary? _detailSummary;
  int? _detailAccountId;
  bool _detailLoading = false;

  // ── 分页状态（唯一真源在共享账本，页面不持有副本）──────────────
  static const int _detailPageSize = 10; // 每页 10 条
  int _detailPage = 1;                   // 1-based
  int _detailTotal = 0;                  // 当前筛选的总条数
  int _detailPageCount = 0;              // 总页数，0 = 无记录
  AccountDirection? _detailDirection;    // null = 全部 / 出账 / 入账
  int _detailTotalAll = 0;
  int _detailTotalInbound = 0;
  int _detailTotalOutbound = 0;
  int _detailRequest = 0;                // 竞态保护，见 loadDetail 注释

  /// 内存快照（只读）。页面不要修改它。
  List<AccountRecord> get all => List<AccountRecord>.unmodifiable(_all);

  bool get detailLoading => _detailLoading;
  int? get detailAccountId => _detailAccountId;

  /// **当前页**的流水（最多 10 条），不是该账户的全部流水。
  List<AccountEntryRecord> get detailEntries =>
      List<AccountEntryRecord>.unmodifiable(_detailEntries);

  /// 三格统计仍是**全量汇总**：不随分页、也不随方向标签变化。
  /// 统计跟着标签缩水容易被误读成「钱变少了」，这条口径写死在这里。
  AccountEntrySummary? get detailSummary => _detailSummary;

  int get detailPage => _detailPage;
  int get detailPageSize => _detailPageSize;
  int get detailTotal => _detailTotal;
  int get detailPageCount => _detailPageCount;
  AccountDirection? get detailDirection => _detailDirection;
  int get detailTotalAll => _detailTotalAll;
  int get detailTotalInbound => _detailTotalInbound;
  int get detailTotalOutbound => _detailTotalOutbound;

  Future<void> load() async {
    // 必须把归档账户也读进来：3.7「想恢复随时恢复」、10.7「所有操作
    // 可逆」。若这里过滤掉 archived，归档后账户会从内存里彻底消失，
    // 页面上没有任何入口能恢复，等于把数据藏丢了。
    _all = await dao.listAll(db, includeArchived: true);
    _bindings.clear();
    for (final AccountRecord r in _all) {
      final int? id = r.id;
      if (id == null) continue;
      _bindings[id] = (await dao.bindingsFor(db, id))
          .map((AccountCategoryBinding b) => b.categoryId)
          .toSet();
    }
    // 章程只有「有卡才有」的几行，一次读全比逐卡查更简单；
    // CreditCardRuleDao 无状态，直接 new（与 AccountEntryDao.summaryFor
    // 里 AccountDao().byId(...) 同一套用法），不用改装配参数。
    _cardRules
      ..clear()
      ..addAll(await CreditCardRuleDao().all(db));
    notifyListeners();
  }

  /// 明细页**按页**加载：COUNT 算总页数 → LIMIT/OFFSET 只取当前 10 条。
  /// 页面 initState / 换账户时调用；翻页与切标签走 [goToDetailPage] /
  /// [setDetailDirection]，它们复用本方法。
  ///
  /// 【为什么同步段不调 notifyListeners —— 必读，删掉那行不是漏写】
  /// initState 在**第一帧 build 之前**执行；async 方法会一路同步执行到
  /// 第一个 await，所以 loading 标记与 accountId 在 build 开始前就已设好：
  /// 第一次 build 用 `context.watch` 读到的就是 loading=true，直接显示
  /// AppLoadingState —— 开头那次通知本来就是冗余的。
  /// 更关键的是：在 initState 的调用栈里 notifyListeners() 会让 Provider 的
  /// _InheritedProviderScope 在 build 阶段 markNeedsBuild，Flutter 直接抛
  /// 「setState() or markNeedsBuild() called during build」（点任意账户必现）。
  /// 因此只保留 finally 里那一次：它发生在 await 之后，已离开 build 阶段。
  ///
  /// 【翻页 / 切标签为什么传 showLoading: false】那两次是用户点击触发，
  /// 已不在 build 阶段；不置 loading 就不会把整页（含统计卡）闪成骨架，
  /// 而是沿用上一页数据直到新页到达，手感更顺。
  ///
  /// 【竞态保护，4 步】连续快点「下一页」或翻页中切账户时：
  ///   ① 每次调用先 `++_detailRequest` 拿到自己的序号；
  ///   ② 读库回来后若序号已不是最新，直接丢弃结果、也不通知；
  ///   ③ 只有最新一次请求才写状态并 notifyListeners()；
  ///   ④ 于是不会出现「第 2 页的旧响应盖掉第 3 页」。
  ///
  /// 【边界】page 超出总页数（例如删除流水后）会夹到最后一页；无记录时
  /// 总页数为 0、当前页记 1，页面显示空态。`summaryFor` 始终查全量。
  Future<void> loadDetail(
    int accountId, {
    int page = 1,
    AccountDirection? direction,
    bool showLoading = true,
  }) async {
    final int req = ++_detailRequest;
    if (showLoading) _detailLoading = true;
    _detailAccountId = accountId;
    _detailDirection = direction;
    try {
      final int total = await entryDao.countForAccount(
        db,
        accountId,
        direction: direction,
      );
      final int pages =
          total == 0 ? 0 : (total + _detailPageSize - 1) ~/ _detailPageSize;
      // 不用 num.clamp：它的静态返回类型是 num，赋给 int 需要 toInt()，
      // 显式三段判断最直接，也避免依赖 SDK 版本对 clamp 的窄化。
      final int safePage = pages == 0
          ? 1
          : (page < 1 ? 1 : (page > pages ? pages : page));
      final List<AccountEntryRecord> rows = await entryDao.listForAccount(
        db,
        accountId,
        limit: _detailPageSize,
        offset: (safePage - 1) * _detailPageSize,
        direction: direction,
      );
      // 三个标签条数：本地 SQLite 的 COUNT 成本可忽略，每次都查，
      // 换来「不做缓存失效」——写操作后 refresh 自然同步，不会脏。
      final int all = await entryDao.countForAccount(db, accountId);
      final int inbound = await entryDao.countForAccount(
        db,
        accountId,
        direction: AccountDirection.inbound,
      );
      final AccountEntrySummary summary =
          await entryDao.summaryFor(db, accountId);
      if (req != _detailRequest) return; // 旧请求：丢弃，finally 也不通知
      _detailEntries = rows;
      _detailSummary = summary;
      _detailPage = safePage;
      _detailTotal = total;
      _detailPageCount = pages;
      _detailTotalAll = all;
      _detailTotalInbound = inbound;
      _detailTotalOutbound = all - inbound;
    } finally {
      if (req == _detailRequest) {
        _detailLoading = false;
        notifyListeners();
      }
    }
  }

  /// 翻页 / 跳页。由分页条的按钮点击调用，不在 build 阶段。
  Future<void> goToDetailPage(int page) {
    final int? id = _detailAccountId;
    if (id == null) return Future<void>.value();
    return loadDetail(
      id,
      page: page,
      direction: _detailDirection,
      showLoading: false,
    );
  }

  /// 切「全部 / 出账 / 入账」标签：总数与总页数按新条件重算，回到第 1 页。
  Future<void> setDetailDirection(AccountDirection? direction) {
    final int? id = _detailAccountId;
    if (id == null) return Future<void>.value();
    return loadDetail(
      id,
      page: 1,
      direction: direction,
      showLoading: false,
    );
  }

  /// 业务处理器写库成功后**统一**调用。
  ///
  /// 【工作逻辑，3 步】
  ///   1. `load()` 重读账户快照与绑定，并通知所有 watch 页面；
  ///   2. 若当前正好打开了某个账户的明细页，且它在本次受影响的账户里
  ///      （转账 / 还款会一次影响两个账户），再按**第 1 页**重新分页加载；
  ///      新流水按交易时间排在最前，回到第 1 页才能立刻看到它；
  ///      方向标签保留，不打断用户正在看的筛选；
  ///   3. 两次通知都发生在 await 之后，不在 build 阶段。
  /// 边界：[touched] 为空时只刷新列表，不动明细；刷新失败会向上抛，
  /// 让业务处理器的调用链能感知（表单据此保持打开并显示错误）。
  Future<void> refresh({Set<int> touched = const <int>{}}) async {
    await load();
    final int? openId = _detailAccountId;
    if (openId != null && touched.contains(openId)) {
      await loadDetail(
        openId,
        page: 1,
        direction: _detailDirection,
        showLoading: false,
      );
    }
  }

  /// 首页三组分区：按 kind 分组，组内保持 sort_order。
  List<AccountRecord> byKind(AccountKind kind) => _all
      .where((AccountRecord r) => r.kind == kind && !r.isDeleted && !r.archived)
      .toList(growable: false);

  List<AccountRecord> get archived => _all
      .where((AccountRecord r) => r.archived && !r.isDeleted)
      .toList(growable: false);

  Set<int> bindingsOf(int accountId) =>
      Set<int>.unmodifiable(_bindings[accountId] ?? const <int>{});

  /// 某张卡的章程；没填过返回全默认值的空章程（不返回 null）。
  CreditCardRule cardRulesOf(int accountId) =>
      _cardRules[accountId] ?? CreditCardRule.empty(accountId);

  // ══════════════════════════════════════════════════════════════════
  // 3.5 记账时的账户候补（数据能力，当前**不接 UI**）
  // ══════════════════════════════════════════════════════════════════

  /// 「记一笔支出，选了 [categoryId] 类型，能从哪些账户付」。
  ///
  /// 【工作逻辑，4 步，全部基于内存快照，同步返回、不查库】
  ///   ① 流动资金账户 + 信用卡账户：永远在候补里（3.2「能直接花」、
  ///      3.4「先用后还」，二者都不受用途绑定限制）；
  ///   ② 若**全软件一条绑定都没有** → 按 3.5「不绑定也能用」，受限账户
  ///      全部返回，用户嫌麻烦时不需要先配置；
  ///   ③ 一旦有人设过绑定，受限账户只返回「绑定了该支出类型」的那些，
  ///      社保账户恒不返回（3.5「基本无法支取」）；
  ///   ④ 已软删 / 已归档的账户一律排除。
  ///
  /// 【边界，如实写清】[categoryId] 为 null（还没选类型）时，在第 ③ 种
  /// 情况下不返回任何受限账户，避免提前把「可能被限制的钱」摆出来；
  /// 选完类型再调一次即可。破例使用受限账户的「非绑定用途」高级选项、
  /// 以及 `non_binding` 标记，随「记支出」模块开工时一并接，本轮只备
  /// 数据能力、不接 UI，也不新增任何表字段。
  List<AccountRecord> payableAccountsFor(int? categoryId) {
    final bool anyBinding =
        _bindings.values.any((Set<int> ids) => ids.isNotEmpty);
    return _all
        .where((AccountRecord r) {
          if (r.isDeleted || r.archived) return false;
          if (r.kind == AccountKind.liquid ||
              r.kind == AccountKind.credit) {
            return true;
          }
          if (!anyBinding) return true;
          if (r.type == AccountType.socialSecurity) return false;
          if (categoryId == null) return false;
          final int? id = r.id;
          return id != null &&
              (_bindings[id]?.contains(categoryId) ?? false);
        })
        .toList(growable: false);
  }

  // ══════════════════════════════════════════════════════════════════
  // 3.4 还款提醒（纯只读计算，不写库、不联网、不替银行算）
  // ══════════════════════════════════════════════════════════════════

  /// 未来 [withinDays] 天内要还款的信用卡（默认提前 3 天，3.4）。
  ///
  /// 【工作逻辑，4 步，同步纯函数】
  ///   ① 只挑未删除 / 未归档 / 已用额度 > 0 / 填了还款日的信用卡；
  ///   ② [nextDueDate] 求出**下一次**还款日（今天的还款日还没过就算今天，
  ///      已过就顺延到下月；月份没有 31 号时钳到当月最后一天）；
  ///   ③ 相差 0..[withinDays] 天就生成一条 [RepaymentReminder]，
  ///      金额取当前已用额度，来源账户名从 repay_account_id 查；
  ///   ④ 只有用户**填过日利率**才粗估「只还最低，下月约多 X 利息」，
  ///      公式 `（已用 − 最低还款）× 日利率 × 30`，界面必须标
  ///      「估算，按你填的日利率粗算，以账单为准」。
  ///
  /// 【边界】日利率没填 → 估算字段为 null，界面不显示那半句；不按章程
  /// 的计息方式 / 复利 / 容时容差精算（7.7 六种算法属负债模块）。
  /// 没有符合条件的卡返回空列表，页面直接不渲染提示条。
  List<RepaymentReminder> upcomingRepayments(
    DateTime now, {
    int withinDays = 3,
  }) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<RepaymentReminder> out = <RepaymentReminder>[];
    for (final AccountRecord r in _all) {
      if (r.kind != AccountKind.credit ||
          r.isDeleted ||
          r.archived ||
          r.balance <= 0 ||
          r.dueDay == null) {
        continue;
      }
      final DateTime due = nextDueDate(today, r.dueDay!);
      final int days = due.difference(today).inDays;
      if (days < 0 || days > withinDays) continue;
      final AccountRecord? source = r.repayAccountId == null
          ? null
          : byId(r.repayAccountId!);
      final CreditCardRule rule = cardRulesOf(r.id ?? -1);
      final double? rate = rule.dailyRate;
      final double? estimated;
      if (rate == null || rate <= 0) {
        estimated = null;
      } else {
        final double minimum = r.balance * r.minPaymentRate;
        estimated = (r.balance - minimum) * rate * 30;
      }
      out.add(
        RepaymentReminder(
          cardName: r.name,
          daysLeft: days,
          amount: r.balance,
          sourceName: source?.name ?? '未设置还款账户',
          minimumPayment: r.balance * r.minPaymentRate,
          estimatedMonthlyInterest: estimated,
        ),
      );
    }
    return List<RepaymentReminder>.unmodifiable(out);
  }

  /// 求「下一次」是几号发工资要还、账单日是哪天这类每月固定日。
  /// 月份不足 31 天时钳到当月最后一天（2 月 28/29 日），不跳到 3 月。
  static DateTime nextDueDate(DateTime today, int dayOfMonth) {
    int clamped(int year, int month) {
      final int last = DateTime(year, month + 1, 0).day;
      return dayOfMonth > last ? last : dayOfMonth;
    }

    final DateTime thisMonth = DateTime(
      today.year,
      today.month,
      clamped(today.year, today.month),
    );
    if (!thisMonth.isBefore(today)) return thisMonth;
    return DateTime(
      today.year,
      today.month + 1,
      clamped(today.year, today.month + 1),
    );
  }

  /// 首页看板（3.6）。信用卡 balance 是欠款，只进「欠银行的钱」，
  /// 绝不混进「能花的钱」——DDL 的 CHECK 也从数据层锁死了这条口径。
  ///
  /// 【动态逻辑说明】按传入的账户集合算，而不是只读全量：账户页的类型
  /// 快筛会把「当前那一类」传进来，于是顶部数字与下方列表天然同源。
  ///   ① 调用方先按筛选条件准备好 rows（**不含搜索词过滤**）；
  ///   ② 逐行按 kind 累加：liquid→可用余额、credit→已用额度、
  ///      restricted→计入资产的受限余额；
  ///   ③ 返回不可变 AccountStats，页面只显示，不自己算数字。
  /// 边界：已删除 / 已归档的行跳过（与 byKind 口径一致）。
  /// [stats] 是全量版本，供其它页面沿用。
  AccountStats statsFor(Iterable<AccountRecord> rows) {
    double spendable = 0;
    double owed = 0;
    double restricted = 0;
    int creditCount = 0;
    int count = 0;
    for (final AccountRecord r in rows) {
      if (r.isDeleted || r.archived) continue;
      count += 1;
      switch (r.kind) {
        case AccountKind.liquid:
          if (r.isLiquid) spendable += r.balance;
        case AccountKind.credit:
          owed += r.balance;
          creditCount += 1;
        case AccountKind.restricted:
          if (r.includeInNetWorth) restricted += r.balance;
      }
    }
    return AccountStats(
      spendable: spendable,
      owedToBank: owed,
      restrictedTotal: restricted,
      accountCount: count,
      creditCount: creditCount,
    );
  }

  /// 全量看板（3.6）。账户页按类型筛选时改用 [statsFor]。
  AccountStats get stats => statsFor(_all);

  /// 「真正属于你的钱」当前只算账户口径（3.6 完整公式还要加资产估值、
  /// 借出/借入，那些模块在第二阶段）。页面显示时附带一句说明，
  /// 不把一个不完整的数字伪装成最终答案。
  double get netWorthSoFar =>
      stats.spendable + stats.restrictedTotal - stats.owedToBank;

  AccountRecord? byId(int id) {
    for (final AccountRecord r in _all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 同步重名校验（给新增/编辑表单的 validator 用）。
  bool nameExists(String name, {int? excludeId}) => _all.any(
        (AccountRecord r) =>
            !r.isDeleted && r.name == name && r.id != excludeId,
      );

  // ── 通用记录维护（不含资金方向，故留在本类）─────────────────────

  /// 归档 / 恢复（3.7）：只改标记，历史流水全部保留。
  Future<void> setArchived(int id, bool archived) async {
    final AccountRecord? old = await dao.byId(db, id);
    if (old == null) return;
    final int affected = await dao.update(
      db,
      old.copyWith(
        archived: archived,
        updatedAt: DateTime.now(),
        revision: old.revision + 1,
      ),
    );
    if (affected == 0) throw StateError('归档状态写入未生效');
    await load();
  }

  /// 拖拽排序（3.7）。传**当前显示的那批** id，其余留在原槽位。
  Future<void> reorder(List<int> orderedVisibleIds) async {
    final Set<int> visible = orderedVisibleIds.toSet();
    final List<int> result = <int>[];
    int cursor = 0;
    for (final AccountRecord r in _all) {
      final int id = r.id ?? -1;
      if (visible.contains(id)) {
        if (cursor < orderedVisibleIds.length) {
          result.add(orderedVisibleIds[cursor++]);
        }
      } else {
        result.add(id);
      }
    }
    for (final int id in orderedVisibleIds) {
      if (!result.contains(id)) result.add(id);
    }
    await dao.reorder(db, result);
    await load();
  }

  /// 常用账户 / 上次使用账户的**只读**查询（详见
  /// [AccountEntryDao.usageByAccount]）。故意不是内存字段、不进
  /// notifyListeners：它是对历史流水的即时聚合，调用方按需 await 一次
  /// 即可；做成缓存反而要处理「何时失效」。
  ///
  /// 【当前状态，按静态优先约定写清】本项目还没有支出单据，
  /// `refType: 'expense'` 暂时查不到数据；本方法只是把数据能力备好，
  /// **账户首页不接「常用」UI**，等展示规则确定后再取用。
  /// 结果第一项即「上次使用账户」，不必再加第二个方法。
  Future<List<AccountUsage>> frequentlyUsedAccounts({
    int limit = 5,
    String? refType,
  }) =>
      entryDao.usageByAccount(db, limit: limit, refType: refType);

  /// 删除 = 进回收站（10.7）。先数流水给页面提示（3.8），
  /// 记录本身永不物理删除。
  Future<int> countEntries(int id) => dao.countEntries(db, id);

  Future<void> delete(int id, {String reason = '用户于账户页删除'}) async {
    final int affected = await dao.softDelete(
      db,
      id,
      at: DateTime.now(),
      reason: reason,
    );
    if (affected == 0) throw StateError('账户删除未生效');
    await load();
  }

  Future<void> restore(int id) async {
    final int affected = await dao.restore(db, id, DateTime.now());
    if (affected == 0) throw StateError('账户恢复未生效');
    await load();
  }

  Future<int> purgeExpired() async {
    final int n = await dao.purgeExpired(db, DateTime.now());
    if (n > 0) await load();
    return n;
  }

  /// 恒等式审计（10.9）。DAO 会按账户类别选对应规则，本类不判断口径。
  Future<double> auditBalance(int id) => entryDao.auditBalance(db, id);
}

/// 3.4 还款提醒的一条（纯数据，界面只显示、不计算）。
///
/// [estimatedMonthlyInterest] 为 null 表示「用户没填日利率，不算估算」，
/// 界面就只说「全额还清没有利息」，不编一个数字出来。
@immutable
class RepaymentReminder {
  const RepaymentReminder({
    required this.cardName,
    required this.daysLeft,
    required this.amount,
    required this.sourceName,
    required this.minimumPayment,
    this.estimatedMonthlyInterest,
  });

  final String cardName;
  final int daysLeft;
  final double amount;
  final String sourceName;
  final double minimumPayment;
  final double? estimatedMonthlyInterest;
}
