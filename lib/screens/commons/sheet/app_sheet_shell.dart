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
/// 键盘策略：**完全不抬 Sheet**。
///
/// 前几轮一直在「用 bottom padding 把 sheet 抬到键盘上方」里打转，
/// 但「抬」这个动作本身就是把 sheet 往设备顶端推：只要 sheet 底部
/// 被移离 view 底部、而高度又按较大的可用高度算，顶部必然溢出，
/// 圆角被裁到状态栏，且底部露出 barrier 灰带。
///
/// 现在 Sheet 底部永远对齐 view 底部（`Align.bottomCenter`），
/// 位置与键盘完全无关；键盘的可见性只通过**滚动内容内部**追加一段
/// `viewInsets.bottom` 的 padding 来解决 —— 那是可滚动区域，不会
/// 改变 Sheet 自身的位置或高度。
///
/// 外壳只用 LayoutBuilder 拿到的「实际可用高度」限高，因此顶部
/// 恒为 `0.1 × 可用高度 > 0`，数学上不可能贴到设备顶端。
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

          // 键盘补偿放在「滚动内容」里，而不是 Sheet 外层：
          // 它让内容能滚出键盘遮挡区，但不会把 Sheet 自身往上推。
          // 若 adjustResize 已经缩小了 view，这段 padding 只是多出
          // 一块可滚动留白，完全无害。
          final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          final EdgeInsetsGeometry basePadding = contentPadding ??
              const EdgeInsets.fromLTRB(
                AppSheetSize.horizontalPadding,
                0,
                AppSheetSize.horizontalPadding,
                AppSheetSize.bottomPadding,
              );
          final EdgeInsetsGeometry effectivePadding = keyboardInset > 0
              ? basePadding.add(EdgeInsets.only(bottom: keyboardInset))
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
