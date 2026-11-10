import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../screens/commons/icons/app_icons.dart';
import '../screens/entry/entry_screen.dart';
import '../screens/ledger/ledger_screen.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../styles/app_icon_tone.dart';
import '../styles/theme_tokens.dart';

class RouteNavigation {
  final String label;
  final String path;
  final int index;
  final Widget widget;

  /// 直接存 IconData：鲜明档下由 AppShell 按 tab 语义给未选中/选中
  /// 两种状态分别上色，不需要在路由表写死任何 Color。
  final IconData icon;

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
  RouteNavigation('记账', '/', 0, EntryScreen(), AppIcons.entry),
  RouteNavigation('资债', '/ledger', 1, LedgerScreen(), AppIcons.ledger),
  RouteNavigation('账户', '/accounts', 2, AccountsScreen(), AppIcons.accounts),
  RouteNavigation('分析', '/analysis', 3, AnalysisScreen(), AppIcons.analysis),
  RouteNavigation('我的', '/profile', 4, ProfileScreen(), AppIcons.profile),
];

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final found = tabs.indexWhere((t) => location == t.path);
    final index = found < 0 ? 0 : found;

    final iconTone = AppIconTone.of(context);
    // 鲜明档：当前 tab 的 indicator 用饱和渐变首色，选中图标用自动
    // 反色前景；未选中图标各自取色环上的语义色（不再是统一灰）。
    // 克制档自动退回单色图标 + 淡彩 indicator，同一份代码。
    final pair = iconTone.resolve(
      iconTone.forTab(index),
      AppIconEmphasis.tonal,
    );
    final navTheme = Theme.of(context).navigationBarTheme.copyWith(
          indicatorColor: pair.container,
        );

    return Scaffold(
      // 键盘避让的根开关，必须为 true。
      //
      // go_router 的 ShellRoute 会在 Scaffold.body 内建一个嵌套 Navigator，
      // showModalBottomSheet 的 route 就挂在这个 Navigator 的 Overlay 上。
      // 设 false 时 Scaffold 会给 body 子树套
      // `MediaQuery.removeViewInsets(removeBottom: true)`：
      //   ① route 里 MediaQuery.viewInsets.bottom 恒为 0，Sheet 内部所有
      //      键盘补偿都读到 0（前几轮怎么改都无效的根因）；
      //   ② Overlay 不随键盘缩小，铺满整屏，键盘直接盖住 Sheet 下半部分。
      //
      // 设 true 后：body（含 Overlay）自动缩到键盘上方，Sheet 的可用高度
      // 与 viewport 底部天然就是键盘上沿；viewInsets 也保留真实值。
      // 全局一处生效，所有 Sheet / 页面统一，不需要在弹层里猜键盘高度。
      resizeToAvoidBottomInset: true,
      body: child,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(navigationBarTheme: navTheme),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(tabs[i].path),
          destinations: tabs
              .asMap()
              .entries
              .map((e) {
                final i = e.key;
                final t = e.value;
                final tabColor = iconTone
                    .resolve(iconTone.forTab(i), AppIconEmphasis.standard)
                    .foreground;
                return NavigationDestination(
                  icon: Icon(t.icon,
                      size: AppIconSize.large, color: tabColor),
                  selectedIcon: Icon(t.icon,
                      size: AppIconSize.large, color: pair.foreground),
                  label: t.label,
                );
              })
              .toList(),
        ),
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
