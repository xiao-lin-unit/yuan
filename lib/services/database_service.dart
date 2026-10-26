import '../models/account.dart';
import '../models/asset.dart';
import '../models/category.dart';
import '../models/liability.dart';
import '../models/transaction.dart';
import '../models/money.dart';

/// 数据库服务。统一 SQLite 本地存储，数据不出设备。
/// 所有表含 createdAt/updatedAt/deleted 公共字段，软删除。
///
/// 注：正式运行需 sqflite 包。此处为与 UI 层解耦的纯 Dart 逻辑层，
/// 实际打开/执行由 sqflite 完成。当前文件保持不依赖 sqflite，便于单元测试。
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  // ---------- 建表语句 ----------
  static const List<String> createTables = [
    '''CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        balance REAL DEFAULT 0,
        total_limit REAL DEFAULT 0,
        used_limit REAL DEFAULT 0,
        bill_day INTEGER,
        payment_day INTEGER,
        is_liquid INTEGER DEFAULT 1,
        count_in_total INTEGER DEFAULT 1,
        linked_account_id TEXT,
        allowed_categories TEXT DEFAULT '[]',
        remark TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS expense_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        is_system INTEGER DEFAULT 1,
        hidden INTEGER DEFAULT 0,
        necessity TEXT DEFAULT 'flexible',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS income_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        is_system INTEGER DEFAULT 1,
        hidden INTEGER DEFAULT 0,
        stability TEXT DEFAULT 'occasional',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        account_id TEXT NOT NULL,
        to_account_id TEXT,
        counterparty TEXT,
        remark TEXT,
        image_paths TEXT DEFAULT '[]',
        is_reimbursable INTEGER DEFAULT 0,
        is_taxable INTEGER DEFAULT 0,
        tags TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS account_flows (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        flow_type TEXT NOT NULL,
        related_record_id TEXT,
        related_record_type TEXT,
        amount_cents INTEGER NOT NULL,
        balance_after_cents INTEGER NOT NULL,
        occurred_at TEXT NOT NULL,
        remark TEXT,
        created_at TEXT NOT NULL)''',

    '''CREATE TABLE IF NOT EXISTS assets_normal (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sub_type TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        linked_account_id TEXT,
        calc_type TEXT DEFAULT 'none',
        annual_yield_rate REAL DEFAULT 0,
        count_in_total INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS assets_stock (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        buy_price REAL NOT NULL,
        buy_quantity INTEGER NOT NULL,
        current_price REAL DEFAULT 0,
        linked_account_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS assets_fund (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        confirm_nav REAL NOT NULL,
        shares REAL NOT NULL,
        current_nav REAL DEFAULT 0,
        has_lock_period INTEGER DEFAULT 0,
        lock_end_date TEXT,
        linked_account_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS asset_trade_records (
        id TEXT PRIMARY KEY,
        asset_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        traded_at TEXT NOT NULL,
        price REAL NOT NULL,
        quantity REAL NOT NULL,
        amount_cents INTEGER NOT NULL,
        remark TEXT,
        created_at TEXT NOT NULL)''',

    '''CREATE TABLE IF NOT EXISTS liabilities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        liability_type TEXT NOT NULL,
        remaining_principal_cents INTEGER NOT NULL,
        is_interest_bearing INTEGER DEFAULT 1,
        annual_interest_rate REAL DEFAULT 0,
        borrow_date TEXT NOT NULL,
        due_date TEXT,
        repayment_method TEXT DEFAULT 'flexible',
        period_payment_cents INTEGER DEFAULT 0,
        paid_periods INTEGER DEFAULT 0,
        total_periods INTEGER,
        linked_account_id TEXT,
        remark TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted INTEGER DEFAULT 0)''',

    '''CREATE TABLE IF NOT EXISTS repayment_schedules (
        id TEXT PRIMARY KEY,
        liability_id TEXT NOT NULL,
        period_number INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        principal_cents INTEGER NOT NULL,
        interest_cents INTEGER NOT NULL,
        total_payment_cents INTEGER NOT NULL,
        status TEXT DEFAULT 'pending',
        paid_at TEXT)''',

    '''CREATE TABLE IF NOT EXISTS repayment_records (
        id TEXT PRIMARY KEY,
        liability_id TEXT NOT NULL,
        repaid_at TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        from_account_id TEXT,
        remark TEXT,
        created_at TEXT NOT NULL)''',

    '''CREATE TABLE IF NOT EXISTS knowledge_articles (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category_tags TEXT DEFAULT '[]',
        is_builtin INTEGER DEFAULT 0,
        is_favorited INTEGER DEFAULT 0,
        read_progress INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL)''',

    '''CREATE TABLE IF NOT EXISTS sandbox_simulations (
        id TEXT PRIMARY KEY,
        name TEXT,
        scenarios TEXT NOT NULL,
        result_summary TEXT,
        remark TEXT,
        created_at TEXT NOT NULL)''',
  ];

  /// 初始化内置分类数据（首次启动时调用一次）
  static List<String> get initialCategoryInserts {
    final List<String> sqls = [];
    for (final c in defaultExpenseCategories) {
      sqls.add('''INSERT OR IGNORE INTO expense_categories (id,name,icon,is_system,necessity,created_at,updated_at)
        VALUES ('${c.id}','${c.name}','${c.icon}',1,'${c.necessity?.name ?? 'flexible'}','now','now')''');
    }
    for (final c in defaultIncomeCategories) {
      sqls.add('''INSERT OR IGNORE INTO income_categories (id,name,icon,is_system,stability,created_at,updated_at)
        VALUES ('${c.id}','${c.name}','${c.icon}',1,'${c.stability?.name ?? 'occasional'}','now','now')''');
    }
    return sqls;
  }

  // ---------- 数据完整性校验（财务专家视角） ----------

  /// 恒等式校验：期末余额 = 期初 + 流入 - 流出 + 调整
  /// 对每个账户遍历流水，检查余额是否自洽。
  static bool verifyAccountBalance(Account account, List<AccountFlow> flows) {
    int running = 0;
    final sorted = [...flows]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    for (final f in sorted) {
      switch (f.flowType) {
        case FlowType.inflow:
        case FlowType.adjustmentUp:
          running += f.amountCents;
          break;
        case FlowType.outflow:
        case FlowType.adjustmentDown:
          running -= f.amountCents;
          break;
      }
      if (running != f.balanceAfterCents) return false;
    }
    return true;
  }

  /// 信用卡已用额度与对应负债剩余本金应一致
  static bool verifyCreditSync(Account credit, Liability liability) {
    final a = (credit.usedLimit * 100).round();
    final b = liability.remainingPrincipal.cents;
    return a == b;
  }

  /// 转账守恒：转出 = 转入，且合计不变
  static bool verifyTransfer(Money outAmount, Money inAmount) {
    return outAmount.cents == inAmount.cents;
  }

  /// 受限账户用途校验：该账户能否用于此支出分类
  static bool isExpenseAllowed(Account account, String categoryId) {
    if (account.isLiquid) return true;
    if (account.allowedExpenseCategoryIds.isEmpty) return false;
    return account.allowedExpenseCategoryIds.contains(categoryId);
  }

  /// 资产总额口径
  static Money totalAssets({
    required List<Account> accounts,
    required List<Asset> normalAssets,
    required List<StockAsset> stocks,
    required List<FundAsset> funds,
  }) {
    int cents = 0;
    for (final a in accounts) {
      if (a.countInTotal) cents += (a.balance * 100).round();
    }
    for (final a in normalAssets) {
      if (a.countInTotal) cents += a.amount.cents;
    }
    for (final s in stocks) cents += (s.marketValue * 100).round();
    for (final f in funds) cents += (f.marketValue * 100).round();
    return Money.fromCents(cents);
  }

  /// 总负债
  static Money totalLiabilities(List<Liability> liabilities) {
    int cents = 0;
    for (final l in liabilities) {
      cents += l.remainingPrincipal.cents;
    }
    return Money.fromCents(cents);
  }
}

/// 账户流水记录（出入账）
class AccountFlow {
  final String id;
  final String accountId;
  final FlowType flowType;
  final String? relatedRecordId;
  final String? relatedRecordType;
  final int amountCents;
  final int balanceAfterCents;
  final DateTime occurredAt;
  final String? remark;
  final DateTime createdAt;

  const AccountFlow({
    required this.id,
    required this.accountId,
    required this.flowType,
    this.relatedRecordId,
    this.relatedRecordType,
    required this.amountCents,
    required this.balanceAfterCents,
    required this.occurredAt,
    this.remark,
    required this.createdAt,
  });
}

enum FlowType { inflow, outflow, adjustmentUp, adjustmentDown }
