import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 6 张原型共用的 Sheet 外壳。
///
/// 统一了：28dp 顶部大圆角、近白/深灰磨砂玻璃背景、极细高光描边、
/// 向上柔光阴影、顶部居中拖拽把手、底部 home indicator、24dp 内容留白、
/// 90% 屏高上限与键盘避让。
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
      builder: (_) => AppSheetShell(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final MediaQueryData mq = MediaQuery.of(context);
    final double keyboardInset = mq.viewInsets.bottom;
    final bool hasHeader = title != null || leading != null || trailing != null;

    // 键盘弹出时，可视区只剩 size.height - keyboardInset。
    //
    // 旧版把 maxHeight 按「整屏 * 0.9」算，又用 Padding(bottom: 键盘高)
    // 把 sheet 抬到键盘上方，于是总占用 = 0.9 屏 + 键盘高，必然超出屏幕：
    // 顶部被裁到状态栏、28dp 圆角消失，看起来就是「整个 sheet 被顶到顶端」。
    //
    // Flutter 3.47 的 showModalBottomSheet 不会自动做 viewInsets 避让
    // （ModalBottomSheetRoute 里没有 AnimatedPadding），所以底部 padding
    // 必须保留、用于把 sheet 抬到键盘上方；只要同步把 maxHeight 改成
    // 「可用高度 * factor」，内容交给已有的 SingleChildScrollView 滚动即可。
    final double availableHeight =
        (mq.size.height - keyboardInset).clamp(0.0, double.infinity);
    final double maxHeight = availableHeight * maxHeightFactor;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: ConstrainedBox(
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
        ),
      ),
    );
  }
}
