import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/money.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';
import 'account_detail_screen.dart';
import 'account_operations.dart';

/// 账户模块。展示三类账户 + 账户操作区。
/// 转账、余额调整、归档均在此处。
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late Future<_AccountViewData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次进入页面刷新（处理从详情页返回后的数据变化）
    _reload();
  }

  void _reload() {
    _future = _loadData();
  }

  Future<_AccountViewData> _loadData() async {
    final s = Services.instance;
    final accounts = await s.account.all();
    final liquid = await s.account.totalLiquid();
    final overview = await s.summary.overview();

    final liquidList = <Account>[];
    final creditList = <Account>[];
    final otherList = <Account>[];
    for (final a in accounts) {
      switch (a.category) {
        case AccountCategory.liquid:
          liquidList.add(a);
          break;
        case AccountCategory.credit:
          creditList.add(a);
          break;
        case AccountCategory.other:
          otherList.add(a);
          break;
      }
    }

    return _AccountViewData(
      totalAssets: overview.totalAssets,
      liquid: liquid,
      debt: overview.totalLiabilities,
      liquidList: liquidList,
      creditList: creditList,
      otherList: otherList,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_reload),
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('新建账户功能待实现')),
              );
            },
            tooltip: '新建账户',
          ),
        ],
      ),
      body: FutureBuilder<_AccountViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('加载失败'),
                  TextButton(
                    onPressed: () => setState(_reload),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 汇总
              _SummaryCard(
                totalAssets: data.totalAssets,
                liquid: data.liquid,
                debt: data.debt,
              ),
              const SizedBox(height: 20),
              // 账户操作区
              const Text('账户操作', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OpButton(
                      icon: Icons.swap_horiz,
                      label: '转账',
                      subtitle: '账户间划转',
                      color: Colors.blue,
                      onTap: () => _openOperations(context, initialTab: 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OpButton(
                      icon: Icons.tune,
                      label: '余额调整',
                      subtitle: '修正记录余额',
                      color: Colors.orange,
                      onTap: () => _openOperations(context, initialTab: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _OpButton(
                      icon: Icons.archive_outlined,
                      label: '归档账户',
                      subtitle: '不再使用的账户',
                      color: Colors.grey,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('归档账户功能待实现')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OpButton(
                      icon: Icons.lock_outline,
                      label: '受限账户用途',
                      subtitle: '绑定支出分类',
                      color: Colors.purple,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('受限账户用途管理功能待实现')),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // 流动资金账户
              _SectionHeader(
                title: '流动资金账户',
                count: data.liquidList.length,
                onManage: () {},
              ),
              ...data.liquidList.map((a) => _AccountTile(
                    account: a,
                    onTap: () => _openDetail(context, a),
                  )),
              const SizedBox(height: 20),
              // 信用卡
              _SectionHeader(
                title: '信用卡账户',
                count: data.creditList.length,
                onManage: () {},
              ),
              ...data.creditList.map((a) => _CreditTile(
                    account: a,
                    onTap: () => _openDetail(context, a),
                  )),
              const SizedBox(height: 20),
              // 其他资金账户
              _SectionHeader(
                title: '其他资金账户',
                count: data.otherList.length,
                onManage: () {},
              ),
              ...data.otherList.map((a) => _RestrictedTile(
                    account: a,
                    onTap: () => _openDetail(context, a),
                  )),
            ],
          );
        },
      ),
    );
  }

  void _openOperations(BuildContext context, {required int initialTab}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountOperationsScreen(initialTab: initialTab),
    ));
  }

  void _openDetail(BuildContext context, Account account) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountDetailScreen(account: account),
    ));
  }
}

class _AccountViewData {
  final Money totalAssets;
  final Money liquid;
  final Money debt;
  final List<Account> liquidList;
  final List<Account> creditList;
  final List<Account> otherList;
  const _AccountViewData({
    required this.totalAssets,
    required this.liquid,
    required this.debt,
    required this.liquidList,
    required this.creditList,
    required this.otherList,
  });
}

class _SummaryCard extends StatelessWidget {
  final Money totalAssets;
  final Money liquid;
  final Money debt;
  const _SummaryCard({
    required this.totalAssets,
    required this.liquid,
    required this.debt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[400]!, Colors.teal[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('总资产', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            AmountFormatter.plain(totalAssets),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: '流动资金', value: AmountFormatter.plain(liquid), flex: 1),
              Container(width: 1, height: 28, color: Colors.white38),
              _Stat(label: '总负债', value: AmountFormatter.plain(debt), flex: 1),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final int flex;
  const _Stat({required this.label, required this.value, required this.flex});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class _OpButton extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _OpButton({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onManage;
  const _SectionHeader({required this.title, required this.count, required this.onManage});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        ),
        const Spacer(),
        TextButton(onPressed: onManage, child: const Text('管理')),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;
  const _AccountTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.12),
          child: Text(_iconFor(account.type), style: const TextStyle(fontSize: 20)),
        ),
        title: Text(account.name),
        subtitle: Text(account.type.label),
        trailing: Text(
          AmountFormatter.plain(Money.fromDouble(account.balance)),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: onTap,
      ),
    );
  }

  String _iconFor(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return '🏦';
      case AccountType.cash:
        return '💵';
      case AccountType.wechat:
        return '💬';
      case AccountType.alipay:
        return '🅰️';
      default:
        return '💰';
    }
  }
}

class _CreditTile extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;
  const _CreditTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final used = account.usedLimit;
    final limit = account.totalLimit;
    final ratio = limit == 0 ? 0.0 : used / limit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.12),
          child: const Text('💳', style: TextStyle(fontSize: 20)),
        ),
        title: Text(account.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.type.label),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.grey[200],
                color: ratio > 0.8 ? Colors.red : Colors.orange,
                minHeight: 4,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('可用 ¥${account.availableLimit.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('已用 ¥${used.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RestrictedTile extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;
  const _RestrictedTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withOpacity(0.12),
          child: Text(_iconFor(account.type), style: const TextStyle(fontSize: 20)),
        ),
        title: Row(
          children: [
            Text(account.name),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('受限', style: TextStyle(fontSize: 9, color: Colors.purple)),
            ),
          ],
        ),
        subtitle: Text(account.remark ?? account.type.label),
        trailing: Text(AmountFormatter.plain(Money.fromDouble(account.balance)),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: onTap,
      ),
    );
  }

  String _iconFor(AccountType type) {
    switch (type) {
      case AccountType.socialSecurity:
        return '🏥';
      case AccountType.housingFund:
        return '🏠';
      default:
        return '🔒';
    }
  }
}
