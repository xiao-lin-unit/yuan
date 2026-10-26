import '../../models/account.dart';

/// 账户数据访问对象。
///
/// 提供对 accounts 表的增删改查。
/// 与 UI 层完全解耦，只暴露领域模型 [Account]。
class AccountDao {
  /// 全部账户（不含已删除/已归档）
  Future<List<Account>> list() async {
    await Future<void>.delayed(Duration.zero);
    return seedAccounts;
  }

  /// 按类型筛选
  Future<List<Account>> listByCategory(AccountCategory category) async {
    final all = await list();
    return all.where((a) => a.category == category).toList();
  }

  /// 流动资金账户
  Future<List<Account>> listLiquid() =>
      listByCategory(AccountCategory.liquid);

  /// 信用卡账户
  Future<List<Account>> listCredit() =>
      listByCategory(AccountCategory.credit);

  /// 其他资金账户（含受限账户）
  Future<List<Account>> listOther() =>
      listByCategory(AccountCategory.other);

  /// 按 id 查询
  Future<Account?> getById(String id) async {
    final all = await list();
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 插入账户
  Future<Account> insert(Account account) async {
    await Future<void>.delayed(Duration.zero);
    return account;
  }

  /// 更新账户（含余额变更、受限用途变更）
  Future<Account> update(Account account) async {
    await Future<void>.delayed(Duration.zero);
    return account;
  }

  /// 调整余额（余额调整操作）
  /// 返回调整后的账户
  Future<Account> adjustBalance(Account account, double newBalance) async {
    await Future<void>.delayed(Duration.zero);
    return account.copyWith(balance: newBalance);
  }

  /// 归档账户（软删除）
  Future<void> archive(String id) async {
    await Future<void>.delayed(Duration.zero);
  }

  /// 获取受限账户列表（非流动资金且不可改）
  Future<List<Account>> listRestricted() async {
    final all = await list();
    return all.where((a) => a.isRestricted).toList();
  }

  /// 校验某账户是否可用于某支出分类
  Future<bool> isAllowedForCategory(String accountId, String categoryId) async {
    final acc = await getById(accountId);
    if (acc == null) return false;
    if (acc.isLiquid) return true;
    if (acc.allowedExpenseCategoryIds.isEmpty) return false;
    return acc.allowedExpenseCategoryIds.contains(categoryId);
  }
}

/// 种子数据：模拟数据库中的初始记录。
/// 真实环境下由 sqflite 从本地 SQLite 读取。
List<Account> seedAccounts = [
  Account(
    id: 'acc_savings_1',
    name: '招商银行储蓄卡',
    type: AccountType.savings,
    category: AccountCategory.liquid,
    balance: 5800,
    isLiquid: true,
    linkedAccountId: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 10, 26),
  ),
  Account(
    id: 'acc_wechat_1',
    name: '微信零钱',
    type: AccountType.wechat,
    category: AccountCategory.liquid,
    balance: 2150,
    isLiquid: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 10, 26),
  ),
  Account(
    id: 'acc_cash_1',
    name: '现金',
    type: AccountType.cash,
    category: AccountCategory.liquid,
    balance: 300,
    isLiquid: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 10, 26),
  ),
  Account(
    id: 'acc_credit_1',
    name: '招商信用卡',
    type: AccountType.creditCard,
    category: AccountCategory.credit,
    balance: 0,
    totalLimit: 10000,
    usedLimit: 6800,
    billDay: 5,
    paymentDay: 25,
    isLiquid: true,
    linkedAccountId: 'acc_savings_1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 10, 26),
  ),
  Account(
    id: 'acc_social_1',
    name: '医保账户',
    type: AccountType.socialSecurity,
    category: AccountCategory.other,
    balance: 1200,
    isLiquid: false,
    allowedExpenseCategoryIds: {'medical'},
    remark: '仅限医疗相关支出',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 10, 26),
  ),
  Account(
    id: 'acc_fund_1',
    name: '公积金',
    type: AccountType.housingFund,
    category: AccountCategory.other,
    balance: 28000,
    isLiquid: false,
    allowedExpenseCategoryIds: {'housing'},
    remark: '仅限租房/装修/买房相关支出',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 10, 26),
  ),
];
