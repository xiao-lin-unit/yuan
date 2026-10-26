import '../models/transaction.dart';
import '../models/category.dart';
import '../models/money.dart';
import '../models/account.dart';
import 'dao/transaction_dao.dart';
import 'dao/account_dao.dart';
import 'dao/expense_category_dao.dart';
import 'dao/income_category_dao.dart';
import 'result.dart';

/// 收支业务服务。
///
/// 封装记账核心业务规则：
/// - 新增支出/收入/转账时的合法性校验
/// - 受限账户用途校验
/// - 账户余额联动更新
/// - 本月收支汇总
///
/// 上层只与此服务打交道，不直接碰 DAO。
class TransactionService {
  final TransactionDao _txDao;
  final AccountDao _accountDao;
  final ExpenseCategoryDao _expenseCategoryDao;
  final IncomeCategoryDao _incomeCategoryDao;

  TransactionService({
    TransactionDao? txDao,
    AccountDao? accountDao,
    ExpenseCategoryDao? expenseCategoryDao,
    IncomeCategoryDao? incomeCategoryDao,
  })  : _txDao = txDao ?? TransactionDao(),
        _accountDao = accountDao ?? AccountDao(),
        _expenseCategoryDao = expenseCategoryDao ?? ExpenseCategoryDao(),
        _incomeCategoryDao = incomeCategoryDao ?? IncomeCategoryDao();

  /// 最近记录
  Future<List<Transaction>> recent({int limit = 20}) => _txDao.recent(limit: limit);

  /// 某账户相关流水
  Future<List<Transaction>> byAccount(String accountId) =>
      _txDao.byAccount(accountId);

  /// 本月收支汇总
  Future<(Money expense, Money income)> monthlySummary(DateTime month) =>
      _txDao.monthlySummary(month);

  /// 支出分类列表
  Future<List<Category>> expenseCategories({bool includeHidden = false}) =>
      _expenseCategoryDao.list(includeHidden: includeHidden);

  /// 收入分类列表
  Future<List<Category>> incomeCategories({bool includeHidden = false}) =>
      _incomeCategoryDao.list(includeHidden: includeHidden);

  /// 新增一条支出。
  ///
  /// 业务校验：
  /// 1. 金额须为正数
  /// 2. 若为受限账户，校验用途白名单
  /// 3. 余额不足时给出警告（不强制拦截，用户可能有信用额度）
  /// 4. 校验通过后更新账户余额
  Future<Result<Transaction>> addExpense({
    required String categoryId,
    required DateTime occurredAt,
    required Money amount,
    required String accountId,
    String? counterparty,
    String? remark,
    List<String>? imagePaths,
  }) async {
    if (amount.isZero) return const Err('金额不能为零');
    if (amount.isNegative) return const Err('金额不能为负数');

    // 受限账户用途校验
    final acc = await _accountDao.getById(accountId);
    if (acc == null) return const Err('账户不存在');
    if (acc.isRestricted) {
      final ok = await _accountDao.isAllowedForCategory(accountId, categoryId);
      if (!ok) {
        return Err('${acc.name} 仅限用于：${acc.remark ?? "绑定的支出分类"}');
      }
    }

    // 余额预警（不拦截）
    if (acc.category != AccountCategory.credit && amount.yuan > acc.balance) {
      // 这里只是校验，实际提示由 UI 层决定是否阻断
    }

    final tx = Transaction(
      id: _newId(),
      type: TxType.expense,
      categoryId: categoryId,
      occurredAt: occurredAt,
      amount: amount,
      accountId: accountId,
      counterparty: counterparty,
      remark: remark,
      imagePaths: imagePaths,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _txDao.insert(tx);
    return result.andThen<Transaction>((saved) async {
      // 联动更新账户余额
      final updated = acc.copyWith(balance: acc.balance - amount.yuan);
      await _accountDao.update(updated);
      return Ok(saved);
    }.call);
  }

  /// 新增一条收入。
  Future<Result<Transaction>> addIncome({
    required String categoryId,
    required DateTime occurredAt,
    required Money amount,
    required String accountId,
    String? counterparty,
    String? remark,
  }) async {
    if (amount.isZero) return const Err('金额不能为零');
    if (amount.isNegative) return const Err('金额不能为负数');

    final acc = await _accountDao.getById(accountId);
    if (acc == null) return const Err('账户不存在');

    final tx = Transaction(
      id: _newId(),
      type: TxType.income,
      categoryId: categoryId,
      occurredAt: occurredAt,
      amount: amount,
      accountId: accountId,
      counterparty: counterparty,
      remark: remark,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _txDao.insert(tx);
    return result.andThen<Transaction>((saved) async {
      final updated = acc.copyWith(balance: acc.balance + amount.yuan);
      await _accountDao.update(updated);
      return Ok(saved);
    }.call);
  }

  /// 新增一条转账。
  /// 不产生收支，不影响本月结余，两侧账户余额联动。
  Future<Result<Transaction>> addTransfer({
    required Money amount,
    required String fromAccountId,
    required String toAccountId,
    String? remark,
  }) async {
    if (amount.isZero) return const Err('转账金额不能为零');
    if (amount.isNegative) return const Err('转账金额不能为负数');
    if (fromAccountId == toAccountId) {
      return const Err('转入账户不能与转出账户相同');
    }

    final from = await _accountDao.getById(fromAccountId);
    final to = await _accountDao.getById(toAccountId);
    if (from == null) return const Err('转出账户不存在');
    if (to == null) return const Err('转入账户不存在');

    // 余额校验
    if (from.category == AccountCategory.credit) {
      if (amount.yuan > from.availableLimit) {
        return Err('超出可用额度 ¥${from.availableLimit.toStringAsFixed(2)}');
      }
    } else {
      if (amount.yuan > from.balance) {
        return Err('余额不足，当前 ¥${from.balance.toStringAsFixed(2)}');
      }
    }

    final tx = Transaction(
      id: _newId(),
      type: TxType.transfer,
      categoryId: 'other',
      occurredAt: DateTime.now(),
      amount: amount,
      accountId: fromAccountId,
      toAccountId: toAccountId,
      remark: remark,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _txDao.insert(tx);
    return result.andThen<Transaction>((saved) async {
      // 转出账户减，转入账户加
      final fromUpdated = from.copyWith(balance: from.balance - amount.yuan);
      final toUpdated = to.copyWith(balance: to.balance + amount.yuan);
      await _accountDao.update(fromUpdated);
      await _accountDao.update(toUpdated);
      return Ok(saved);
    }.call);
  }

  /// 按分类统计本月支出占比
  Future<List<(Category, Money, double)>> expenseByCategory(DateTime month) async {
    final cats = await _expenseCategoryDao.listVisible();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final list = await _txDao.byDateRange(start, end);

    final map = <String, int>{};
    int total = 0;
    for (final t in list) {
      if (t.type != TxType.expense) continue;
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount.cents;
      total += t.amount.cents;
    }

    final result = <(Category, Money, double)>[];
    for (final c in cats) {
      final cents = map[c.id] ?? 0;
      final ratio = total == 0 ? 0.0 : cents / total;
      result.add((c, Money.fromCents(cents), ratio));
    }
    // 按金额降序
    result.sort((a, b) => b.$2.cents.compareTo(a.$2.cents));
    return result;
  }

  String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return 'tx_$t';
  }
}
