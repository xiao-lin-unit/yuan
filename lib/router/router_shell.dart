import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../screens/entry/entry_screen.dart';
import '../screens/ledger/ledger_screen.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/profile/profile_screen.dart';

class RouteNavigation {
  final String label;
  final String path;
  final int index;
  final Widget widget;
  final Widget icon;

  const RouteNavigation(
    this.label,
    this.path,
    this.index,
    this.widget,
    this.icon,
  );
}

/// 用矢量图标替代 emoji。
/// emoji 在不同系统/字体下字形、大小、颜色都不一致，且不吃主题的
/// iconTheme，暗色模式下尤其突兀；Material Icons 会随 NavigationBarTheme
/// 自动切换选中/未选中色，视觉更统一。
const List<RouteNavigation> tabs = [
  RouteNavigation('记账', '/', 0, EntryScreen(), Icon(Icons.edit_outlined)),
  RouteNavigation('资债', '/ledger', 1, LedgerScreen(), Icon(Icons.account_balance_outlined)),
  RouteNavigation('账户', '/accounts', 2, AccountsScreen(), Icon(Icons.account_balance_wallet_outlined)),
  RouteNavigation('分析', '/analysis', 3, AnalysisScreen(), Icon(Icons.analytics_outlined)),
  RouteNavigation('我的', '/profile', 4, ProfileScreen(), Icon(Icons.person_outline)),
];

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.indexWhere((t) => location == t.path),
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: tabs
            .map((t) => NavigationDestination(icon: t.icon, label: t.label))
            .toList(),
      ),
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: tabs
          .map((t) => GoRoute(path: t.path, builder: (context, state) => t.widget))
          .toList(),
    ),
  ],
);
