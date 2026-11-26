import 'package:sqflite/sqflite.dart';

import '../../database/account/account_dao.dart';
import '../../database/account/account_entry_dao.dart';
import '../../database/account/account_record.dart';
import 'entity_registry.dart';
import 'uniqueness_service.dart';

/// 所有**需要读库**的查询的唯一功能门面。
///
/// 整改前 `AccountController.statsFor / auditBalance / countEntries /
/// frequentlyUsedAccounts`、`CategoryController.nameExists`、
/// `AccountEntryDao.expenseStats` 等散在各处，页面想知道「这个月花了
/// 多少」得先认识某个 Controller 的内存状态。
///
/// 整改后：DB 查询一律走本类，第一参数收 [DatabaseExecutor]（在事务里
/// 就自动用同一个 txn，不读未提交数据）。纯内存派生（statsFor /
/// statsOf / 还款提醒 / AzMath）保留在快照 Controller——它们不碰 DB、
/// 无副作用，换页面时直接调功能接口即可，不属于「重复实现的功能」。
/// 【所属模块】service/core · 读库查询
/// 【实现功能】所有需要读库的查询的唯一门面：统计 / 审计 / 明细分页 / 常用账户 / 条数 / 汇总 / 写侧查重。纯内存派生（statsFor / 还款提醒 / AzMath）不在本类。
/// 【使用限制】只读，不得写库；第一参数收 DatabaseExecutor，在事务里会自动用同一个 txn，避免读到未提交数据；页面不直接调 DAO。
/// 【入参与结果】构造收 entryDao / accountDao / uniqueness；方法统一收 DatabaseExecutor 作为首参，返回 Future<T> 或记录列表。
/// 【异常与调用方处理】DAO 查询异常、表未建、参数非法均原样上抛；调用方需自行 try/catch 并给页面空态 / 错误态，不得把异常吞掉后展示旧数据当新数据。
class QueryFacade {
  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】用三个无状态依赖创建查询门面。
  /// 【使用限制】必须由 components.dart 建且只建一份，注入共享的 UniquenessService；不要在页面里 new。
  /// 【入参与结果】entryDao / accountDao / uniqueness 均必填；无返回值（const 构造）。结果为可复用的 QueryFacade。
  /// 【异常与调用方处理】构造不抛异常；依赖未就绪会在查询时暴露，调用方需保证装配顺序。
  const QueryFacade({
    required this.entryDao,
    required this.accountDao,
    required this.uniqueness,
  });

  final AccountEntryDao entryDao;
  final AccountDao accountDao;
  final UniquenessService uniqueness;

  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】按《账户表结构草案》全局约定 10 算三个统计视图（生活成本 / 实际支出 / 资产抵消）。
  /// 【使用限制】只读；取数不依赖 ref_type 与记支出模块；不得用于写库前校验。
  /// 【入参与结果】db 必填；bookId / from / to 可选。返回 Future<AccountExpenseStats>，调用方必须 await 后按三个字段分别展示，三者不得相加。
  /// 【异常与调用方处理】表未建 / SQL 异常原样上抛；调用方需自行 try/catch 并显示错误态，不要回退成 0 冒充真实统计。
  Future<AccountExpenseStats> expenseStats(
    DatabaseExecutor db, {
    String bookId = 'default',
    DateTime? from,
    DateTime? to,
  }) =>
      entryDao.expenseStats(db, bookId: bookId, from: from, to: to);

  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】恒等式审计：按账户类别用对应规则重算余额，与 accounts.balance 对照。
  /// 【使用限制】只读；结果用于审计展示，不得直接写回 balance。
  /// 【入参与结果】db / accountId 必填。返回 Future<double>（应为流水推算值），调用方 await 后与账面值比较再决定提示。
  /// 【异常与调用方处理】账户不存在或 DAO 异常原样上抛；调用方需自行 try/catch，审计失败不应阻断页面其它功能。
  Future<double> auditBalance(DatabaseExecutor db, int accountId) =>
      entryDao.auditBalance(db, accountId);

  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】统计某账户的流水条数，供删除前提示。
  /// 【使用限制】只读；返回条数不是"能否删除"的判断，业务判断留在 Controller。
  /// 【入参与结果】db / accountId 必填。返回 Future<int>，调用方 await 后仅用于文案提示。
  /// 【异常与调用方处理】DAO 异常原样上抛；调用方需自行 try/catch，失败时给出保守提示而不是 0。
  Future<int> countEntries(DatabaseExecutor db, int accountId) =>
      accountDao.countEntries(db, accountId);

  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】按历史流水聚合常用 / 上次使用账户。
  /// 【使用限制】只读聚合，刻意不做缓存；refType 传 null 时查全部。
  /// 【入参与结果】db 必填；limit 默认 5、refType 可选。返回 Future<List<AccountUsage>>，第一项即上次使用账户；调用方 await 后按需展示。
  /// 【异常与调用方处理】DAO 异常原样上抛；调用方需自行 try/catch 并隐藏"常用"模块，不要展示半成品列表。
  Future<List<AccountUsage>> usageByAccount(
    DatabaseExecutor db, {
    int limit = 5,
    String? refType,
  }) =>
      entryDao.usageByAccount(db, limit: limit, refType: refType);

  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】按账户分页取流水明细（LIMIT / OFFSET），与 countForAccount 共用同一套 where。
  /// 【使用限制】只读；必须配合 countForAccount 算总页数，不要单独用来判断是否有下一页。
  /// 【入参与结果】db / accountId 必填；limit / offset / direction / from / to 可选。返回 Future<List<AccountEntryRecord>>，调用方 await 后按 occurredAt 展示。
  /// 【异常与调用方处理】DAO 异常原样上抛；调用方需自行 try/catch 并保留上一页数据（翻页场景不闪骨架）。
  Future<List<AccountEntryRecord>> listForAccount(
    DatabaseExecutor db,
    int accountId, {
    int? limit,
    int? offset,
    AccountDirection? direction,
  }) =>
      entryDao.listForAccount(
        db,
        accountId,
        limit: limit,
        offset: offset,
        direction: direction,
      );

  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】按账户与方向统计流水条数，供明细分页算总页数。
  /// 【使用限制】只读；与 listForAccount 的 where 必须同源，调用方不要另写一套筛选。
  /// 【入参与结果】db / accountId 必填；direction / from / to 可选。返回 Future<int>，调用方 await 后换算页数（0 条记 1 页）。
  /// 【异常与调用方处理】DAO 异常原样上抛；调用方需自行 try/catch 并保持 loading 态可结束。
  Future<int> countForAccount(
    DatabaseExecutor db,
    int accountId, {
    AccountDirection? direction,
  }) =>
      entryDao.countForAccount(db, accountId, direction: direction);

  /// 【所属模块】service/core · 读库查询
  /// 【实现功能】账户明细页顶部「总入账 / 总出账 / 净变动 / 当前余额」汇总。
  /// 【使用限制】只读；始终查全量，不随分页变化；不得用分页数据自行累加替代。
  /// 【入参与结果】db / accountId 必填；from / to 可选。返回 Future<AccountEntrySummary>，调用方 await 后整组展示。
  /// 【异常与调用方处理】DAO 异常原样上抛；调用方需自行 try/catch 并给汇总区错误态。
  Future<AccountEntrySummary> summaryFor(
    DatabaseExecutor db,
    int accountId, {
    DateTime? from,
    DateTime? to,
  }) =>
      entryDao.summaryFor(db, accountId, from: from, to: to);

  /// 写侧查重真源：表单即时提示走内存快照，落库前一律再查一次。
  /// 【所属模块】service/core · 读库查询（写侧查重真源）
  /// 【实现功能】在给定 executor 上查库判断名称是否重复（未软删、排除自身、分类按 kind 隔离）。
  /// 【使用限制】只读；表单即时提示走内存快照，写库前必须再经本接口或 UniquenessService.assertUnique 查一次。
  /// 【入参与结果】db / kind / name 必填；excludeId / categoryKind / bookId 可选。返回 Future<bool>，true 表示已占用。
  /// 【异常与调用方处理】不支持查重的实体抛 ArgumentError；DAO 异常原样上抛。调用方需自行 try/catch，或改用 assertUnique 让它抛人话异常。
  Future<bool> nameExists(
    DatabaseExecutor db,
    EntityKind kind,
    String name, {
    int? excludeId,
    String? categoryKind,
    String bookId = 'default',
  }) =>
      uniqueness.nameExists(
        db,
        kind,
        name,
        excludeId: excludeId,
        categoryKind: categoryKind,
        bookId: bookId,
      );

  /// 【所属模块】service/core · 读库查询（写侧查重真源）
  /// 【实现功能】在给定 executor 上查库判断投资类代码是否重复（空代码不查、软删不占位）。
  /// 【使用限制】只读；仅 supportsCode=true 的实体（asset）可调用。
  /// 【入参与结果】db / kind / code 必填；excludeId 可选。返回 Future<bool>，true 表示已登记。
  /// 【异常与调用方处理】不支持代码查重的实体抛 ArgumentError；DAO 异常原样上抛。调用方需自行 try/catch 或改用 assertUnique。
  Future<bool> codeExists(
    DatabaseExecutor db,
    EntityKind kind,
    String code, {
    int? excludeId,
  }) =>
      uniqueness.codeExists(db, kind, code, excludeId: excludeId);
}
