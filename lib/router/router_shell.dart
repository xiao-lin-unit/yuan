import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../screens/commons/icons/app_icons.dart';
import '../screens/entry/entry_screen.dart';
import '../screens/ledger/ledger_screen.dart';
import '../screens/accounts/account_detail_screen.dart';
import '../screens/accounts/accounts_screen.dart';
import '../screens/analysis/analysis_screen.dart';
import '../screens/category/category_management_screen.dart';
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

/// 全软件**唯一**的 Scaffold 持有者，也是唯一的导航形态决策点。
///
/// ── 收敛嵌套 Scaffold（本任务第 2 条）───────────────────────────
/// 页面侧的 `AppPageScaffold` 已降级为纯内容骨架，不再自建 Scaffold。
/// 所以这里这一层 Scaffold 是全局唯一的一个：只有一个
/// `resizeToAvoidBottomInset`、只有一处 AppBar 归属、只有一处导航槽位。
/// 五个业务页面与 6 个预览页的构造参数一个字没改。
///
/// ── 断点（本任务第 1 条）：这是动态布局，把工作逻辑写清楚 ──────
/// 为什么动态：窗口宽度只有运行时才知道，手机 / 平板 / 桌面不能写死。
///
/// 分步工作逻辑（判定全部收在 AppLayout，本文件只负责"用结果"）：
///   1. 用 `MediaQuery.sizeOf(context).width` 读**整个 view 的宽度**；
///      刻意不用 LayoutBuilder：宽屏时本文件的 body 是
///      `Row([rail, 分隔线, Expanded(child)])`，child 拿到的约束宽度已经
///      被 rail 扣掉一截。若页面再用 LayoutBuilder 判档，就会出现
///      「导航判成 expanded、内容判成 medium」的错位。两处统一读
///      MediaQuery 就一定是同一个数。
///   2. `AppLayout.windowSizeOf(width)` → compact / medium / expanded；
///   3. `AppLayout.useNavigationRail(size)`：
///        compact  (<600) → 底部 NavigationBar，body = child；
///        medium   (600~839) → 折叠式 NavigationRail（图标 + 选中项文字）；
///        expanded (>=840) → 展开式 NavigationRail（图标 + 常驻文字）；
///      宽屏时 body = Row([rail, 1dp 分隔线, Expanded(child)])；
///   4. AppPageScaffold 用同一个 `windowSizeOf` 取内容列限宽，
///      导航与内容永远是同一档位。
///
/// 窗口 resize / 旋转 / 分屏时 MediaQuery 变化会自动触发 rebuild，
/// 无需注册监听。边界：宽度非有限值 / 极小窗口按 compact 处理。
/// 阈值 600 / 840 是 M3 标准断点，想调形态只改 AppLayout 两个常量，
/// 本文件与五个页面都不用动。
///
/// ── 一条硬约束，改动时务必保住 ─────────────────────────────────
/// `resizeToAvoidBottomInset: true` 是前几轮修好「Sheet 被键盘顶到
/// 状态栏 / 最下方内容被遮挡」的根开关。ShellRoute 在这个 Scaffold 的
/// body 里建嵌套 Navigator，showModalBottomSheet 的 route 挂在那个
/// Navigator 的 Overlay 上；设 false 会给 body 子树套
/// `MediaQuery.removeViewInsets`，Overlay 里读到的键盘高度恒为 0。
/// 换成 NavigationRail / 加断点都**不能**动这一行。
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    // 【动态布局，工作逻辑】二级页挂在「我的」分支下（/profile/category），
    // 用「精确匹配 + 前缀匹配」找出它属于哪个 tab：
    //   1. 精确命中 tab.path → 该 tab；
    //   2. 否则若 location 以 "<tab.path>/" 开头 → 仍算该 tab 的子页，
    //      底导/rail 继续高亮「我的」，不会出现「在分类管理页却高亮记账」；
    //   3. '/' 是所有路径的前缀，必须排除，只在精确匹配时算它；
    //   4. 都没命中 → 0（兜底，保持原来的行为）。
    // 只影响选中态，不影响导航形态与键盘根开关。
    final found = tabs.indexWhere((RouteNavigation t) =>
        location == t.path ||
        (t.path != '/' && location.startsWith('${t.path}/')));
    final index = found < 0 ? 0 : found;

    final iconTone = AppIconTone.of(context);
    // 鲜明档：当前 tab 的 indicator 用饱和渐变首色，选中图标用自动
    // 反色前景；未选中图标各自取色环上的语义色（不再是统一灰）。
    // 克制档自动退回单色图标 + 淡彩 indicator，同一份代码。
    // 底导与侧边 rail 共用这一份色对，两种形态长相一致。
    final pair = iconTone.resolve(
      iconTone.forTab(index),
      AppIconEmphasis.tonal,
    );

    /// 未选中图标：鲜明档每个 tab 取色环上的语义色，克制档退回单色。
    /// 抽成一个小函数，底导和 rail 不各写一遍。
    Color tabColor(int i) => iconTone
        .resolve(iconTone.forTab(i), AppIconEmphasis.standard)
        .foreground;

    // ★ 唯一的动态点：view 宽度 → 档位 → 导航形态。
    // 与 AppPageScaffold 用同一个宽度来源，详见类注释第 1 步。
    final size = AppLayout.windowSizeOf(MediaQuery.sizeOf(context).width);
    final useRail = AppLayout.useNavigationRail(size);

    final navTheme = Theme.of(context).navigationBarTheme.copyWith(
          indicatorColor: pair.container,
        );
    final railTheme = Theme.of(context).navigationRailTheme.copyWith(
          indicatorColor: pair.container,
        );

    return Scaffold(
      // 键盘避让的根开关，必须为 true。理由见类注释「硬约束」。
      resizeToAvoidBottomInset: true,
      body: useRail
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Theme(
                  data: Theme.of(context)
                      .copyWith(navigationRailTheme: railTheme),
                  child: _buildRail(
                    context: context,
                    index: index,
                    size: size,
                    tabColor: tabColor,
                    selectedColor: pair.foreground,
                  ),
                ),
                // 颜色走全局 DividerTheme（AppStroke 低对比中性色），
                // 宽度走 AppBorder.thin，不在页面里写死。
                const VerticalDivider(
                  width: 1,
                  thickness: AppBorder.thin,
                ),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: useRail
          ? null
          : Theme(
              data: Theme.of(context)
                  .copyWith(navigationBarTheme: navTheme),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(tabs[i].path),
                destinations: tabs
                    .asMap()
                    .entries
                    .map((e) {
                      final i = e.key;
                      final t = e.value;
                      return NavigationDestination(
                        icon: Icon(t.icon,
                            size: AppIconSize.large,
                            color: tabColor(i)),
                        selectedIcon: Icon(t.icon,
                            size: AppIconSize.large,
                            color: pair.foreground),
                        label: t.label,
                      );
                    })
                    .toList(),
              ),
            ),
    );
  }

  /// 侧边导航（纯静态渲染：接收已经算好的档位与颜色，自己不做判定）。
  ///
  /// medium：折叠 rail，只显示图标 + 选中项文字（labelType: selected）；
  /// expanded：展开 rail，图标与文字常驻（extended: true）。此时
  /// labelType 传 null —— 它的语义是「非展开态的文字策略」，展开态
  /// 用不上，传了也没有意义，不是因为 assert 互斥。
  /// 宽度、背景、指示容器圆角、字色全部来自全局 navigationRailTheme，
  /// 这里只覆盖「当前 tab 的 indicator 色」以对齐鲜明/克制档。
  Widget _buildRail({
    required BuildContext context,
    required int index,
    required AppWindowSize size,
    required Color Function(int) tabColor,
    required Color selectedColor,
  }) {
    final extended = AppLayout.isRailExtended(size);
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: (i) => context.go(tabs[i].path),
      extended: extended,
      // extended 为 true 时必须留 null；折叠态显示选中项文字。
      labelType: extended ? null : NavigationRailLabelType.selected,
      destinations: <NavigationRailDestination>[
        for (var i = 0; i < tabs.length; i++)
          NavigationRailDestination(
            icon: Icon(tabs[i].icon,
                size: AppIconSize.large, color: tabColor(i)),
            selectedIcon: Icon(tabs[i].icon,
                size: AppIconSize.large, color: selectedColor),
            label: Text(tabs[i].label),
          ),
      ],
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: <RouteBase>[
        ...tabs.map(
          (RouteNavigation t) => GoRoute(
            path: t.path,
            builder: (context, state) => t.widget,
          ),
        ),
        // 二级功能页：放在 ShellRoute **内部**，因此仍由 AppShell 那唯一
        // 一个 Scaffold 覆盖 —— resizeToAvoidBottomInset: true 的键盘避让
        // 对分类编辑器 Sheet 照样生效。若挂到顶层路由，编辑器弹层就
        // 失去这个根开关，会重演「键盘把 Sheet 顶到状态栏」。
        GoRoute(
          path: '/profile/category',
          builder: (context, state) => const CategoryManagementScreen(),
        ),
        // 账户明细：挂在 ShellRoute **内部**，因此仍由 AppShell 那唯一一个
        // Scaffold 覆盖 —— resizeToAvoidBottomInset: true 的键盘避让对
        // 明细页里的转账 / 余额调整 Sheet 照样生效。
        // AppShell 的前缀高亮规则（location.startsWith('/accounts/')）
        // 会自动让底导/rail 继续高亮「账户」，无需额外改动。
        GoRoute(
          path: '/accounts/detail/:id',
          builder: (context, state) => AccountDetailScreen(
            accountId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
          ),
        ),
      ],
    ),
  ],
);
