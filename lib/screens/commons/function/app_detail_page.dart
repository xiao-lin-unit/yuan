import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../icons/app_icons.dart';
import '../scaffold/app_page_scaffold.dart';

/// ══════════════════════════════════════════════════════════════════
/// 详情页的**外部框架**（账户 / 资产 / 负债三类明细页共用）
/// ══════════════════════════════════════════════════════════════════
/// 把「页面外壳」和「页面主体」分开：
///   · 本组件只决定**布局顺序**：固定头 → 可滚动主体 → 固定底部 → 右下角悬浮；
///   · 头是一个 Widget 槽位 [header]，主体是 [child]，两者都由使用方填充；
///   · 壳不认识余额 / 流水 / 资产 / 负债任何一种业务，不读 Controller。
///
/// 按「头 + 主体」两部分的约定，落地为两个构造期静态槽位：
///   ① header：传 [AppDetailHeader] 即可（也可传任意自定义 Widget，
///      完全由内容控制）；
///   ② child：主体内容，使用方自己写 Column / 列表 / 图表。
///
/// 【头部的返回 / 标题 / 按钮，两种控制方式都支持】
///   · 参数控制：不传 header，改传 [title] / [leading] / [actions]，
///     本组件自动构造一个 [AppDetailHeader]；
///   · 内容控制：直接传 header，[title] / [leading] / [actions] 被忽略。
/// 优先级是 `header ?? 参数构造`，构造期一次判定，没有运行时分支、
/// 没有 Notifier、没有注册 / 提升 / 跨帧回调。
///
/// 【为什么还要有这个薄封装】
/// 直接让每个详情页各写一遍 `AppPageScaffold(showAppBar:false, ...)` 也能跑，
/// 但资产 / 负债 / 账户三类页面会各自决定「头放哪、悬浮放哪」，样式一改
/// 就要改三处。这里把语义固定成 [AppDetailPage]，骨架仍复用
/// [AppPageScaffold]（全软件唯一 Scaffold 之下的内容骨架），**没有第二套壳**。
///
/// 用法（资产 / 负债详情页以后照抄这个形状即可）：
/// ```dart
/// AppDetailPage(
///   title: asset.name,                       // 或 header: AppDetailHeader(...)
///   actions: <Widget>[IconButton(...), IconButton(...)],
///   floating: AppFloatingActions(actions: <AppFloatingAction>[
///     AppFloatingAction(label: '新增', icon: AppIcons.add, onPressed: _add),
///     AppFloatingAction(label: '修改', icon: AppIcons.edit, onPressed: _edit),
///     AppFloatingAction(label: '删除', icon: AppIcons.trash, onPressed: _delete),
///   ]),
///   child: Column(children: <Widget>[
///     AppSummaryHero(...),                  // 头卡属于「主体」，各类详情页自己填
///     AppInfoGrid(...),
///     AppLedgerList(...),
///   ]),
/// )
/// ```
/// 上面 `AppFloatingActions` / `AppSummaryHero` 仅示意，见各自文件。
class AppDetailPage extends StatelessWidget {
  const AppDetailPage({
    super.key,
    required this.child,
    this.header,
    this.title,
    this.leading,
    this.actions = const <Widget>[],
    this.floating,
    this.bottom,
    this.padding,
    this.scrollable = true,
  });

  /// 主体内容：余额卡、信息网格、流水列表……完全由使用方决定。
  final Widget child;

  /// 固定头（内容控制）。传了就忽略 [title]/[leading]/[actions]。
  final Widget? header;

  /// 固定头的三个参数（参数控制）。[title] 为 null 且不传 [header] 时无顶栏。
  final String? title;
  final Widget? leading;
  final List<Widget> actions;

  /// 右下角悬浮层：位置由 [AppPageScaffold] 的 Stack 决定，组件自己不定位。
  final Widget? floating;

  /// 固定底部区（可选）。与 [floating] 不要同时传：两者都在底部，会重叠。
  final Widget? bottom;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    // 构造期一次判定：header 优先；否则用三个参数拼一个公共头组件。
    // 这不是「动态逻辑」，读构造函数就能看出最终渲染什么。
    final Widget? effectiveHeader = header ??
        (title == null
            ? null
            : AppDetailHeader(
                title: title!,
                leading: leading,
                actions: actions,
              ));

    return AppPageScaffold(
      // 顶栏统一走 header 槽位（AppDetailHeader 内部就是 AppBar），
      // 关掉 AppPageScaffold 自带的那一套，避免画两行。
      showAppBar: false,
      header: effectiveHeader,
      floating: floating,
      bottom: bottom,
      padding: padding,
      scrollable: scrollable,
      child: child,
    );
  }
}

/// 详情页固定头（返回 / 标题 / 按钮），**纯静态 StatelessWidget**。
///
/// 三个位置都能被使用方替换：
///   · [leading] 默认是 [AppDetailBackButton]，可传任意 Widget；
///   · [title] 是 String，也可传 [titleWidget] 完全自定义标题区；
///   · [actions] 是按钮列表，直接放 IconButton / 文字按钮等。
///
/// 用 [PreferredSize] 给 AppBar 一个 tight 高度：收敛嵌套 Scaffold 之后
/// AppBar 已从 `Scaffold.appBar` 槽位移到 Column 里，Column 给非 flex
/// 子节点的是无界高度约束，不包一层会被裁。原因见 AppPageScaffold 注释。
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          primary: false,
          automaticallyImplyLeading: false,
          leading: leading ?? const AppDetailBackButton(),
          title: titleWidget ?? Text(title),
          actions: actions.isEmpty ? null : actions,
        ),
      );
}

/// 默认返回按钮。用 go_router 的 `context.pop()`（同步 void，无未等待的
/// Future），与项目里其它二级页返回写法一致；使用方要换图标 / 文案 /
/// 行为，给 [AppDetailHeader.leading] 传自己的 Widget 即可。
class AppDetailBackButton extends StatelessWidget {
  const AppDetailBackButton({
    super.key,
    this.icon = AppIcons.chevronLeft,
    this.tooltip = '返回',
  });

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: () => context.pop(),
      );
}
