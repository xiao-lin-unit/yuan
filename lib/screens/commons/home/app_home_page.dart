import 'package:flutter/material.dart';

import '../../../styles/theme_tokens.dart';

// ── 组件私有尺寸（只服务本文件，全部引用全局令牌）───────────────
const double _kActionRowHeight = kMinTapTarget;
const double _kActionGap = AppSpacing.xxs;

/// **Home 页**（底导 / 侧边 rail 直接打开的 5 个页面之一）的统一套用组件。
///
/// ── 为什么要单独封装，而不是复用 AppPageScaffold ──────────────────
/// `AppPageScaffold` 是「二级功能页」骨架：带 `title` + 返回箭头 + actions，
/// 适合分类管理、账户明细这类 `context.push` 进去的页面。
/// 而 Home 页本身就在底导上，**导航栏已经说明这是哪个页面**，顶上再放
/// 一行「账户 / 返回」是重复信息，还把首屏最值钱的一块让给了标题栏。
/// 所以 Home 页用本组件：
///   · 不渲染 AppBar、不渲染标题、不渲染返回按钮；
///   · 顶部只保留一个**纯动作行**（原型的「＋」），右侧对齐；
///   · 首屏第一块内容直接是大幅摘要卡（[hero]），视觉重心落在数字上。
///
/// ── 结构嵌套（与功能页共用同一套限宽 / 断点）─────────────────────
/// ```
/// AppShell（全局唯一 Scaffold + 断点导航 + 键盘根开关）
///  └ AppHomePage（页级：无标题、动作行 / 滚动内容 / 可选固定底部）
///     ├ _HomeActionRow        ← 静态，只有右侧动作，无标题无返回
///     ├ Expanded → 限宽列 → SingleChildScrollView
///     │    ├ hero             ← 顶部摘要（随内容滚动）
///     │    └ child            ← AppFunctionSection / AppStatBar / 业务列表
///     └ bottom（可选）        ← 固定，不随内容滚
/// ```
/// 二级页仍用 `AppPageScaffold`，两者只是「有没有标题栏」的差别，
/// 限宽、背景、SafeArea、固定底部槽位的规则完全一致，不写第二套数值。
///
/// ── 静态优先 ────────────────────────────────────────────────────
/// 所有内容、文案、回调构造期传入；本组件不持有任何状态、不注册监听、
/// 没有 Notifier / 跨帧回调。
///
/// 【唯一一处动态布局，工作逻辑】与 AppShell / AppPageScaffold 同源：
///   1. `MediaQuery.sizeOf(context).width` 读**整个 view 的宽度**
///      （刻意不用 LayoutBuilder：宽屏时 body 是 `Row([rail, 分隔线,
///      Expanded(页面)])`，页面局部宽度已被 rail 扣掉，用局部约束判档会
///      出现「导航 expanded、内容 medium」的错位）；
///   2. `AppLayout.windowSizeOf` → compact / medium / expanded；
///   3. `AppLayout.contentMaxWidthFor` 取内容列上限，导航与内容永远同档；
///   4. 窗口 resize / 旋转 / 分屏时 MediaQuery 自动触发 rebuild，
///      无需注册监听。非有限宽度按 compact 处理（边界见 AppLayout 注释）。
class AppHomePage extends StatelessWidget {
  const AppHomePage({
    super.key,
    required this.child,
    this.hero,
    this.actions,
    this.bottom,
    this.scrollable = true,
    this.padding,
  });

  /// 页面主体（分区、列表、说明）。
  final Widget child;

  /// 首屏摘要卡，放在滚动区最上方。为 null 时内容从顶部留白开始。
  final Widget? hero;

  /// 右上角动作（新增 / 更多）。**只放动作，不放标题与返回**。
  /// 为 null 时连动作行都不渲染，首屏完全交给 [hero]。
  final List<Widget>? actions;

  /// 固定底部区（快捷记一笔等）。位于滚动区之外，键盘弹出时随
  /// 外层唯一 Scaffold 的 resize 一起上移。
  final Widget? bottom;

  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final EdgeInsetsGeometry effectivePadding = padding ??
        const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppLayout.pageTop,
          AppSpacing.md,
          AppLayout.pageBottom,
        );

    // ★ 唯一动态点：view 宽度 → 档位 → 内容列上限（理由见类注释）。
    final AppWindowSize size =
        AppLayout.windowSizeOf(MediaQuery.sizeOf(context).width);
    final double maxWidth = AppLayout.contentMaxWidthFor(size);

    final Widget scrollBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hero != null) hero!,
        child,
      ],
    );

    final Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: scrollable
            ? SingleChildScrollView(padding: effectivePadding, child: scrollBody)
            : Padding(padding: effectivePadding, child: scrollBody),
      ),
    );

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (actions != null && actions!.isNotEmpty)
              _HomeActionRow(actions: actions!),
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

/// 纯动作行：右侧对齐，左侧**刻意留空**（不写标题、不写返回）。
/// 高度取最小热区 48dp，按钮本身由调用方用 IconButton / 全局令牌给出。
class _HomeActionRow extends StatelessWidget {
  const _HomeActionRow({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: SizedBox(
          height: _kActionRowHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (var i = 0; i < actions.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: _kActionGap),
                actions[i],
              ],
            ],
          ),
        ),
      );
}
