import 'package:flutter/material.dart';
import 'transaction/entry_screen.dart';
import 'ledger/ledger_screen.dart';
import 'accounts/accounts_screen.dart';
import 'analysis/analysis_screen.dart';
import 'profile/profile_screen.dart';

/// 首页壳：底部 5 个模块导航
/// 收支 / 资债 / 账户 / 分析 / 我的
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _tabs = <_TabSpec>[
    _TabSpec(label: '收支', icon: Icons.edit_outlined, activeIcon: Icons.edit),
    _TabSpec(label: '资债', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet),
    _TabSpec(label: '账户', icon: Icons.credit_card_outlined, activeIcon: Icons.credit_card),
    _TabSpec(label: '分析', icon: Icons.pie_chart_outline, activeIcon: Icons.pie_chart),
    _TabSpec(label: '我的', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  final _pages = const <Widget>[
    EntryScreen(),
    LedgerScreen(),
    AccountsScreen(),
    AnalysisScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabSpec({required this.label, required this.icon, required this.activeIcon});
}
