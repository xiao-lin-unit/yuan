import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../screens/commons/icons/app_icons.dart';
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

/// 图标一律取自 AppIcons（全软件唯一语义表），
/// 不再在路由层直接写 Icons.xxx 或 emoji。
const List<RouteNavigation> tabs = [
  RouteNavigation('记账', '/', 0, EntryScreen(), Icon(AppIcons.entry)),
  RouteNavigation('资债', '/ledger', 1, LedgerScreen(), Icon(AppIcons.ledger)),
  RouteNavigation('账户', '/accounts', 2, AccountsScreen(), Icon(AppIcons.accounts)),
  RouteNavigation('分析', '/analysis', 3, AnalysisScreen(), Icon(AppIcons.analysis)),
  RouteNavigation('我的', '/profile', 4, ProfileScreen(), Icon(AppIcons.profile)),
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
