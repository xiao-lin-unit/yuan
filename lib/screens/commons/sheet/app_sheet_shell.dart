import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 6 张原型共用的 Sheet 外壳。
///
/// 统一了：28dp 顶部大圆角、近白/深灰磨砂玻璃背景、极细高光描边、
/// 向上柔光阴影、顶部居中拖拽把手、底部 home indicator、24dp 内容留白、
/// 90% 屏高上限。
///
/// 键盘策略：**外壳不抬 Sheet、不猜键盘高度**。
///
/// 避让由 `router_shell.dart` 的 `Scaffold(resizeToAvoidBottomInset: true)`
/// 统一完成：body（含 go_router 嵌套 Navigator 的 Overlay）会缩到键盘
/// 上方，Sheet 的 LayoutBuilder 拿到的可用高度天然就是「键盘上方高度」，
/// viewport 底部即键盘上沿 —— 最下方内容滑到底自然可见。
///
/// 前几轮在弹层内部反复加 `bottom padding = viewInsets.bottom` 都无效，
/// 根因是那个开关设成了 false：Scaffold 用
/// `MediaQuery.removeViewInsets` 把 body 子树的 viewInsets 清零，
/// 弹层读到的键盘高度恒为 0，且 Overlay 不缩小、键盘直接盖住下半屏。
///
/// 外壳只保留两件事：`Align` 把 tight 约束转 loose（让限高生效）、
/// 滚动内容底部一个固定小安全距；聚焦输入框的自动滚动由
/// `TextField.scrollPadding` 在 `sheet_inputs.dart` 里负责。
///
/// 顶部恒为 `0.1 × 可用高度 > 0`，不会贴到设备顶端；无键盘时
/// 可用高度 = 全屏，六个 Sheet 外观与原来完全一致。
///
/// 与已有的 `CommonBottomSheet` **并存，不修改它**：那个组件是
/// `DraggableScrollableSheet` + 标题栏 + 确认按钮，业务里
/// `edit_profile_sheet.dart` 正在用；本外壳面向原型里那种「内容即主体」的
/// 半屏弹层。后续若要统一，只需让 CommonBottomSheet 内部改用本外壳即可。
class AppSheetShell extends StatelessWidget {
  const AppSheetShell({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.centeredHeader = false,
    this.showGrabber = true,
    this.showHomeIndicator = true,
    this.scrollable = true,
    this.maxHeightFactor = AppSheetSize.maxSheetHeightFactor,
    this.contentPadding,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool centeredHeader;
  final bool showGrabber;
  final bool showHomeIndicator;
  final bool scrollable;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? contentPadding;

  /// 快捷弹出。返回值由内容组件通过 `Navigator.pop(context, value)` 给出。
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    bool centeredHeader = false,
    bool showGrabber = true,
    bool showHomeIndicator = true,
    bool scrollable = true,
    bool barrierDismissible = true,
  }) {
    final p = SheetPalette.of(context);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: p.scrimColor,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      // 这里**不读 viewInsets、不加任何 bottom padding、不做动画位移**。
      //
      // AndroidManifest 是 adjustResize：键盘弹出时 Flutter view 本身
      // 已被缩到键盘上方，showModalBottomSheet 的 route 铺在这个已缩小
      // 的 view 里，Sheet 底部自然就贴在键盘上沿。再手动加一次
      // bottom padding 等于把键盘高度扣两遍 —— 前几轮「灰色间隙 +
      // 顶部被推到状态栏」就是这么来的。
      //
      // 只保留 Align：它把框架可能给出的 tight 高度约束转成 loose，
      // 让外壳里的 ConstrainedBox 限高真正生效（不改位置，只改约束）。
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: AppSheetShell(
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: trailing,
          centeredHeader: centeredHeader,
          showGrabber: showGrabber,
          showHomeIndicator: showHomeIndicator,
          scrollable: scrollable,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final bool hasHeader = title != null || leading != null || trailing != null;

    // Sheet 的位置与键盘完全解耦：底部始终对齐 view 底部，
    // 高度只由「view 实际可用高度 × factor」决定（adjustResize 下这个
    // 值已经是键盘上方高度）。顶部恒为 0.1 × available > 0。
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double available = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final double maxHeight = available * maxHeightFactor;

          // 键盘避让由外层 Scaffold 的 resizeToAvoidBottomInset:true 完成：
          // route 的 Overlay 已缩到键盘上方，viewport 底部即键盘上沿，
          // 滚动内容「滑到底」时最后一项本来就可见 —— 不需要再按
          // viewInsets 的高度补一段 padding（那会让底部空出整块键盘高度）。
          //
          // 这里只加一个固定小安全距，兼容输入法工具栏比 viewInsets
          // 略高的情况；聚焦输入框的自动滚动由 TextField.scrollPadding
          // 负责（见 sheet_inputs.dart）。
          final bool keyboardVisible =
              MediaQuery.viewInsetsOf(context).bottom > 0;
          final EdgeInsetsGeometry basePadding = contentPadding ??
              const EdgeInsets.fromLTRB(
                AppSheetSize.horizontalPadding,
                0,
                AppSheetSize.horizontalPadding,
                AppSheetSize.bottomPadding,
              );
          final EdgeInsetsGeometry effectivePadding = keyboardVisible
              ? basePadding.add(
                  const EdgeInsets.only(
                    bottom: AppSheetSize.keyboardScrollSafety,
                  ),
                )
              : basePadding;

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSheetRadius.modal),
              ),
              child: BackdropFilter(
                filter: p.glassFilter,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.glassColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSheetRadius.modal),
                    ),
                    border: Border.all(
                      color: p.glassBorder,
                      width: AppBorder.thin,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: p.tokens.shadow.withValues(
                          alpha: AppElevation.sheetAlpha,
                        ),
                        blurRadius: AppElevation.sheetBlur,
                        offset: AppElevation.sheetOffset,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (showGrabber)
                        const Padding(
                          padding: EdgeInsets.only(
                            top: AppSheetSize.topPadding,
                            bottom: AppSpacing.xs,
                          ),
                          child: SheetGrabber(),
                        ),
                      if (hasHeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSheetSize.horizontalPadding,
                            AppSpacing.xs,
                            AppSheetSize.horizontalPadding,
                            AppSpacing.md,
                          ),
                          child: SheetHeader(
                            title: title ?? '',
                            subtitle: subtitle,
                            leading: leading,
                            trailing: trailing,
                            centered: centeredHeader,
                          ),
                        ),
                      Flexible(
                        child: scrollable
                            ? SingleChildScrollView(
                                padding: effectivePadding,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: child,
                              )
                            : Padding(
                                padding: effectivePadding,
                                child: child,
                              ),
                      ),
                      if (showHomeIndicator)
                        const Padding(
                          padding: EdgeInsets.only(
                            top: AppSpacing.xs,
                            bottom: AppSpacing.sm,
                          ),
                          child: SheetHomeIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
