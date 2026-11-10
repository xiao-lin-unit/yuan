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
/// 键盘避让**只在 [show] 的 builder 里做一次**（AnimatedPadding + Align），
/// 外壳内部不再读 viewInsets、不再加自己的 bottom padding：
/// 双重避让会让 sheet 底部与键盘之间露出一条灰色间隙，并把内容整体
/// 推到设备顶端。外壳只用 LayoutBuilder 拿到的「实际可用高度」限高。
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
      // 键盘避让的唯一入口。
      //
      // ① AnimatedPadding 用 builder 自己的 context 读 viewInsets，
      //    键盘弹出/收起时 MediaQuery 变化会触发重建，padding 带动画。
      //    它把「键盘高度」这一层留白放在 sheet 之外，sheet 底部正好
      //    贴在键盘上沿，中间不会出现原先那条透明灰色间隙。
      // ② Align 是关键：showModalBottomSheet 会把 sheet 底部对齐屏幕
      //    底部、并可能给出 tight 高度约束；Align 把它转成 loose，
      //    外壳里的 ConstrainedBox 才真正能限高。少了这一层，
      //    maxHeight 被 BoxConstraints.enforce 吃掉，sheet 会铺满
      //    「屏幕 - 键盘」的全部高度，顶部圆角被推到状态栏 —— 这正是
      //    上一轮改了 availableHeight 却仍然贴顶的原因。
      builder: (BuildContext sheetContext) => AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        duration: AppMotion.medium,
        curve: Curves.easeOut,
        child: Align(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final bool hasHeader = title != null || leading != null || trailing != null;

    // 键盘高度已由 [show] 的 AnimatedPadding 扣掉，这里拿到的
    // constraints.maxHeight 就是「键盘上方的真实可用高度」。
    // 不再自己读 viewInsets、不再加 bottom Padding —— 外壳内部再做一次
    // 避让是上一轮留下的问题：等于把同一份键盘高度算了两遍。
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double available = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final double maxHeight = available * maxHeightFactor;
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
                                padding: contentPadding ??
                                    const EdgeInsets.fromLTRB(
                                      AppSheetSize.horizontalPadding,
                                      0,
                                      AppSheetSize.horizontalPadding,
                                      AppSheetSize.bottomPadding,
                                    ),
                                child: child,
                              )
                            : Padding(
                                padding: contentPadding ??
                                    const EdgeInsets.fromLTRB(
                                      AppSheetSize.horizontalPadding,
                                      0,
                                      AppSheetSize.horizontalPadding,
                                      AppSheetSize.bottomPadding,
                                    ),
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
