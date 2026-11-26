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
class QueryFacade {
  const QueryFacade({
    required this.entryDao,
    required this.accountDao,
    required this.uniqueness,
  });

  final AccountEntryDao entryDao;
  final AccountDao accountDao;
  final UniquenessService uniqueness;

  Future<AccountExpenseStats> expenseStats(
    DatabaseExecutor db, {
    String bookId = 'default',
    DateTime? from,
    DateTime? to,
  }) =>
      entryDao.expenseStats(db, bookId: bookId, from: from, to: to);

  Future<double> auditBalance(DatabaseExecutor db, int accountId) =>
      entryDao.auditBalance(db, accountId);

  Future<int> countEntries(DatabaseExecutor db, int accountId) =>
      accountDao.countEntries(db, accountId);

  Future<List<AccountUsage>> usageByAccount(
    DatabaseExecutor db, {
    int limit = 5,
    String? refType,
  }) =>
      entryDao.usageByAccount(db, limit: limit, refType: refType);

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

  Future<int> countForAccount(
    DatabaseExecutor db,
    int accountId, {
    AccountDirection? direction,
  }) =>
      entryDao.countForAccount(db, accountId, direction: direction);

  Future<AccountEntrySummary> summaryFor(
    DatabaseExecutor db,
    int accountId, {
    DateTime? from,
    DateTime? to,
  }) =>
      entryDao.summaryFor(db, accountId, from: from, to: to);

  /// 写侧查重真源：表单即时提示走内存快照，落库前一律再查一次。
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

  Future<bool> codeExists(
    DatabaseExecutor db,
    EntityKind kind,
    String code, {
    int? excludeId,
  }) =>
      uniqueness.codeExists(db, kind, code, excludeId: excludeId);
}
