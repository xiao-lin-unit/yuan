import 'package:flutter/material.dart';

import '../../../styles/theme_tokens.dart';

/// 全软件统一的**页面内容骨架**（不是 Scaffold，不建第二层 Scaffold）。
///
/// ── 收敛嵌套 Scaffold：为什么改 ─────────────────────────────────
/// 改之前：`AppShell`（ShellRoute 外层）是 Scaffold，它的 `body: child`
/// 是 go_router 的嵌套 Navigator，里面每个页面又是 `AppPageScaffold`
/// （自己再建一个 Scaffold + SafeArea）。于是全局有两层 Scaffold：
///   · 外层显式 `resizeToAvoidBottomInset: true`；
///   · 内层 Scaffold 默认值也是 true，键盘弹出时再缩一次；
///   · AppBar 与 bottomNavigationBar 分属两个 Scaffold，各算各的约束。
/// 前几轮 Sheet 反复被键盘顶到状态栏 / 内容被遮挡，根子就在这种重复
/// 层叠上。现在 **AppShell 是全软件唯一的 Scaffold**，本组件只负责
/// 「内容怎么排」：限宽、留白、滚动、可选的顶部标题栏。
///
/// ── 对外 API 一个字没改 ─────────────────────────────────────────
/// [title] / [showAppBar] / [actions] / [scrollable] / [padding] 全部保留，
/// 所以五个业务页面和 6 个预览页**零改动**。内部差异：
///   · AppBar 从 `Scaffold.appBar` 槽位改成 Column 里的普通 widget，
///     并设 `primary: false`（状态栏由 SafeArea 统一处理，不重复加高）；
///   · SafeArea 保留在**这一处**：它只包页面内容，不包 Navigator 的
///     Overlay，因此不会给 Sheet 底部塞进一段系统手势条留白。
///
/// ── 一处明确的取舍，写在这里免得以后困惑 ──────────────────────
/// AppBar 不在 Scaffold.appBar 槽位后，M3 的 `scrolledUnderElevation`
/// （滚动时顶栏浮起一层 tonal 阴影）不再自动联动，因为那依赖 Scaffold
/// 的 PrimaryScrollController。当前五个页面都是占位页 / 短内容，没有
/// 长列表，观感无差异。等流水页长出长列表时，在 AppShell 统一补一个
/// 滚动通知即可，不要回到「页面各自再建 Scaffold」的老路。
///
/// ── 动态布局（按项目约定写清工作逻辑）──────────────────────────
/// 只有一处动态：`MediaQuery.sizeOf(context).width` →
/// `AppLayout.windowSizeOf` 判档位 → `AppLayout.contentMaxWidthFor`
/// 取内容列上限。
///
/// 为什么用 MediaQuery 而不是 LayoutBuilder：宽屏时 AppShell 的 body 是
/// `Row([NavigationRail, 分隔线, Expanded(页面)])`，页面拿到的约束宽度
/// 已被 rail 扣掉一截；若在这里用局部约束判档，就会出现「导航是
/// expanded、内容是 medium」的错位。两处统一读整个 view 的宽度，
/// 一定是同一个数、同一个档位。窗口 resize / 旋转 / 分屏时 MediaQuery
/// 自动触发 rebuild，不需要注册监听。
///
/// 判定函数、阈值与边界（非有限值 / 极小窗口按 compact）见
/// theme_tokens.dart 的 [AppWindowSize] 注释。除此之外本组件没有状态、
/// 没有回调注册、没有 Notifier。
class AppPageScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool scrollable;
  final bool showAppBar;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  /// 二级功能页的返回按钮（构造期静态传入，代码一眼看清去哪）。
  /// 不传时交给 AppBar 自动推断；传了就关掉自动推断，避免两个箭头。
  final Widget? leading;

  /// 固定底部区（记账页的数字键盘、明细页的悬浮操作等）。
  /// 它位于滚动区**之外**、Expanded 之后，所以长列表滚动时不动；
  /// 键盘弹出时随外层唯一 Scaffold 的 resize 一起上移。
  /// 与内容同样走 [AppLayout.contentMaxWidthFor] 限宽，宽屏不拉成两米长。
  final Widget? bottom;

  const AppPageScaffold({
    super.key,
    this.title,
    required this.child,
    this.scrollable = true,
    this.showAppBar = true,
    this.actions,
    this.padding,
    this.leading,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppLayout.pageTop,
          AppSpacing.md,
          AppLayout.pageBottom,
        );

    // ★ 唯一动态点：view 宽度 → 档位 → 内容列上限。
    final size = AppLayout.windowSizeOf(MediaQuery.sizeOf(context).width);
    final maxWidth = AppLayout.contentMaxWidthFor(size);

    final Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: scrollable
            ? SingleChildScrollView(padding: effectivePadding, child: child)
            : Padding(padding: effectivePadding, child: child),
      ),
    );

    return ColoredBox(
      // 独立预览（runApp 里直接挂本组件、外层没有 Scaffold）时
      // 仍需一个底色；在 AppShell 下与 Scaffold 背景同色，无副作用。
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showAppBar && title != null)
              // AppBar 原来挂在 Scaffold.appBar 槽位，Scaffold 会用
              // PreferredSize 给它一个 tight 高度。现在它在 Column 里，
              // Column 给非 flex 子节点的是无界高度约束，必须自己补一层
              // PreferredSize，否则顶栏高度不确定 / 被裁。
              PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AppBar(
                  title: Text(title!),
                  actions: actions,
                  leading: leading,
                  automaticallyImplyLeading: leading == null,
                  // SafeArea 已处理状态栏，AppBar 不要再自己加一段。
                  primary: false,
                ),
              ),
            Expanded(child: content),
            if (bottom != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: bottom!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
