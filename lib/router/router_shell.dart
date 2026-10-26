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

const List<RouteNavigation> tabs = [
  RouteNavigation('记账', '/', 0, EntryScreen(), const Icon(Icons.edit_square)),
  RouteNavigation('资产负债', '/ledger', 1, LedgerScreen(), const Icon(Icons.account_balance_wallet)),
  RouteNavigation('账户', '/accounts', 2, AccountsScreen(), const Icon(Icons.account_balance)),
  RouteNavigation('分析', '/analysis', 3, AnalysisScreen(), const Icon(Icons.insights)),
  RouteNavigation('我的', '/profile', 4, ProfileScreen(), const Icon(Icons.person_outline)),
];

// const paths = tabs.map((t) => t.path).toList();

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    print("location: $location");
    print("context: $context");
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (i) => context.go(tabs[0].path),
        destinations: tabs.map((t) => NavigationDestination(icon: t.icon, label: t.label,)).toList(),
      ),
    );
  }
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: GlobalKey<NavigatorState>(),
      builder: (context, state, child) => AppShell(child: child),
      routes: tabs.map((t) => GoRoute(path: t.path, builder: (context, state) => t.widget)).toList(),
    ),
  ],
);
