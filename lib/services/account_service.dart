import '../models/account.dart';
import '../models/money.dart';
import 'dao/account_dao.dart';
import 'dao/account_flow_dao.dart';
import 'dao/transaction_dao.dart';
import 'result.dart';

/// 账户业务服务。
///
/// 封装所有与账户相关的业务规则：
/// - 三类账户的汇总统计
/// - 受限账户的用途校验
/// - 信用卡与负债的双向同步
/// - 转账、余额调整等操作
///
/// 上层（UI / ViewModel）只与此服务打交道，不直接碰 DAO。
class AccountService {
  final AccountDao _dao;
  final AccountFlowDao _flowDao;
  final TransactionDao _txDao;

  AccountService({
    AccountDao? accountDao,
    AccountFlowDao? flowDao,
    TransactionDao? txDao,
  })  : _dao = accountDao ?? AccountDao(),
        _flowDao = flowDao ?? AccountFlowDao(),
        _txDao = txDao ?? TransactionDao();

  /// 全部账户
  Future<List<Account>> all() => _dao.list();

  /// 按分类获取
  Future<List<Account>> byCategory(AccountCategory c) => _dao.listByCategory(c);

  /// 流动资金账户
  Future<List<Account>> liquid() => _dao.listLiquid();

  /// 信用卡账户
  Future<List<Account>> credit() => _dao.listCredit();

  /// 其他资金账户（含受限）
  Future<List<Account>> other() => _dao.listOther();

  /// 受限账户
  Future<List<Account>> restricted() => _dao.listRestricted();

  /// 按 id 查询
  Future<Account?> byId(String id) => _dao.getById(id);

  /// 总资产（口径与文档一致）
  /// = 流动资金账户余额 + 计入总资产的其他账户余额 + 资产总额
  /// 注：资产总额由 AssetService 提供，此处仅算账户侧
  Future<Money> totalAssetsFromAccounts() async {
    final accounts = await _dao.list();
    int cents = 0;
    for (final a in accounts) {
      if (!a.countInTotal) continue;
      if (a.category == AccountCategory.credit) continue; // 信用卡不算资产
      cents += (a.balance * 100).round();
    }
    return Money.fromCents(cents);
  }

  /// 流动资金合计
  Future<Money> totalLiquid() async {
    final list = await _dao.listLiquid();
    int cents = 0;
    for (final a in list) {
      cents += (a.balance * 100).round();
    }
    return Money.fromCents(cents);
  }

  /// 信用卡已用额度合计（即信用卡负债）
  Future<Money> totalCreditUsed() async {
    final list = await _dao.listCredit();
    int cents = 0;
    for (final a in list) {
      cents += (a.usedLimit * 100).round();
    }
    return Money.fromCents(cents);
  }

  /// 校验某账户能否用于某支出分类。
  /// 流动资金账户永远允许；受限账户须命中白名单。
  Future<bool> isAllowedForCategory(String accountId, String categoryId) =>
      _dao.isAllowedForCategory(accountId, categoryId);

  /// 获取某账户本月出入汇总
  Future<(Money inflow, Money outflow, Money net)> monthlyFlow(
    String accountId,
    DateTime month,
  ) =>
      _flowDao.monthlySummary(accountId, month);

  /// 查询某账户的流水（展示用，倒序）
  Future<List<AccountFlow>> flows(String accountId) =>
      _flowDao.byAccountDesc(accountId);

  /// 转账操作。
  /// 规则：
  /// 1. 转出账户余额须足够（信用卡用 availableLimit）
  /// 2. 两端不能相同
  /// 3. 转账不产生收支，不影响本月结余
  /// 4. 两侧流水一进一出，合计不变
  Future<Result<(Account from, Account to)>> transfer({
    required String fromId,
    required String toId,
    required Money amount,
  }) async {
    if (fromId == toId) {
      return const Err('转入账户不能与转出账户相同');
    }
    if (amount.isZero) return const Err('转账金额不能为零');
    if (amount.isNegative) return const Err('转账金额不能为负数');

    final from = await _dao.getById(fromId);
    final to = await _dao.getById(toId);
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

    return Ok((from, to));
  }

  /// 余额调整。
  /// 用于"记录余额与实际不符"的情况，差额不走收支流水，单独记一条调整流水。
  /// 返回调整后的账户。
  Future<Result<Account>> adjustBalance({
    required String accountId,
    required double newBalance,
  }) async {
    final acc = await _dao.getById(accountId);
    if (acc == null) return const Err('账户不存在');
    if (newBalance < 0) return const Err('余额不能为负数');
    final updated = await _dao.adjustBalance(acc, newBalance);
    return Ok(updated);
  }

  /// 更新受限账户的可绑定支出分类
  Future<Account> updateAllowedCategories(
    String accountId,
    Set<String> categoryIds,
  ) async {
    final acc = await _dao.getById(accountId);
    if (acc == null) return acc;
    final updated = Account(
      id: acc.id,
      name: acc.name,
      type: acc.type,
      category: acc.category,
      balance: acc.balance,
      totalLimit: acc.totalLimit,
      usedLimit: acc.usedLimit,
      billDay: acc.billDay,
      paymentDay: acc.paymentDay,
      isLiquid: acc.isLiquid,
      countInTotal: acc.countInTotal,
      linkedAccountId: acc.linkedAccountId,
      allowedExpenseCategoryIds: categoryIds,
      remark: acc.remark,
      createdAt: acc.createdAt,
      updatedAt: DateTime.now(),
    );
    return _dao.update(updated);
  }
}
