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
  RouteNavigation('记账', '/', 0, EntryScreen(), Text('✏️', style: TextStyle(fontSize: 22))),//Icon(Icons.mode_edit_outline_outlined)),
  RouteNavigation('资债', '/ledger', 1, LedgerScreen(), Text('💰', style: TextStyle(fontSize: 22))),//Icon(Icons.currency_yen_outlined)),
  RouteNavigation('账户', '/accounts', 2, AccountsScreen(), Text('💼', style: TextStyle(fontSize: 22))),//Icon(Icons.account_balance_wallet_outlined)),
  RouteNavigation('分析', '/analysis', 3, AnalysisScreen(), Text('📊', style: TextStyle(fontSize: 22))),//Icon(Icons.analytics_outlined)),
  RouteNavigation('我的', '/profile', 4, ProfileScreen(), Text('👤', style: TextStyle(fontSize: 22))),//Icon(Icons.person_outline)),
];

// const paths = tabs.map((t) => t.path).toList();

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    debugPrint ("location: $location");
    debugPrint ("context: $context");
    
    debugPrint ("child: $child");
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: child,
      bottomNavigationBar: NavigationBar(
        // labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: tabs.indexWhere((t) => location == t.path), // 高亮当前tab
        onDestinationSelected: (i) {
          final path = tabs[i].path;
          debugPrint('tap → $path');
          context.go(path);  // ← 关键！这才是跳转
        },
        destinations: tabs.map((t) => NavigationDestination(icon: t.icon, label: t.label, )).toList(),
      ),
    );
  }
}

// final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      // navigatorKey: GlobalKey<NavigatorState>(),
      builder: (context, state, child) => AppShell(child: child),
      routes: tabs.map((t) => GoRoute(path: t.path, builder: (context, state) => t.widget)).toList(),
    ),
  ],
);
