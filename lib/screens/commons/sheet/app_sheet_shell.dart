import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 全软件**唯一**的 Sheet 外壳。
///
/// ## 契约：壳 / 内容严格分离
///
/// ```
/// AppSheetShell.show(context, child: <任意 Widget>)   ← 唯一入口、唯一壳
///        │
///        ├── 壳只管：28dp 圆角、磨砂玻璃、极细描边、柔光阴影、
///        │          拖拽把手、home indicator、内容留白、滚动、
///        │          90% 屏高上限、键盘避让、barrier、关闭手势
///        │
///        └── child 只管：里面长什么样、有哪些控件、业务数据
///                       （contents/select、contents/form、… 或任意 Widget）
/// ```
///
/// 壳**不知道**有几种内容类型，也不接受 title / subtitle / 按钮 / 头部
/// 这类内容级参数 —— 标题栏、渐变按钮、关闭按钮都是 `parts/` 里的通用
/// 零件，由内容自己组装。因此：
///
/// - 改外壳样式 → 只动本文件一个文件，6 种内容全部同步；
/// - 改共享零件（标题栏 / 按钮 / 输入框 / 选项行）→ 只动 `parts/`；
/// - 改某一种内容的排版 → 只动那一个 `contents/xxx_sheet_content.dart`；
/// - 新增一种内容 → 只写一个 `contents/` 组件，壳零改动；
/// - **不塞内容也能打开**（`child` 可空）：空壳也是同一个壳，不是第二种组件。
///
/// `contents/` 下的 `XxxSheetContent` 是「内容填充物」，不是 Sheet 组件：
/// 它们都是纯 `Column`，不套外壳、不调 `showModalBottomSheet`、
/// 不直接 `Navigator.pop`（统一走 [SheetActions.close]）。
class AppSheetShell extends StatelessWidget {
  const AppSheetShell({
    super.key,
    this.child,
    this.showGrabber = true,
    this.showHomeIndicator = true,
    this.scrollable = true,
    this.maxHeightFactor = AppSheetSize.maxSheetHeightFactor,
    this.contentPadding,
  });

  /// 内容区域。**允许为空**：空壳仍然是唯一的壳，可独立打开。
  /// 壳不读取、不解释、不约束它的类型。
  final Widget? child;

  final bool showGrabber;
  final bool showHomeIndicator;
  final bool scrollable;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? contentPadding;

  /// 唯一弹出入口。
  ///
  /// 返回值由内容通过 `SheetActions.close<T>(context, value)` 回传；
  /// 内容不直接操作 Navigator，因此换个容器（页面 / 对话框 / 测试）
  /// 也能复用同一份内容组件。
  static Future<T?> show<T>(
    BuildContext context, {
    Widget? child,
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
      // 不读 viewInsets、不加 bottom padding、不做位移：键盘避让由
      // 外层 Scaffold 完成。Align 只把框架可能给出的 tight 高度约束
      // 转成 loose，让外壳里的 ConstrainedBox 限高真正生效（只改约束、
      // 不改位置），因此顶部不会贴到设备顶端。
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: AppSheetShell(
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

    // SheetScope 是壳给内容的唯一「我在 Sheet 内」标记；
    // 内容组件只通过 SheetActions.close 请求关闭，不碰 Navigator。
    return SheetScope(
      child: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double available = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final double maxHeight = available * maxHeightFactor;

            // 固定头部槽位：内容里的 SheetHeader / SheetPinned 会通过
            // SheetActions.pin 把自己提升到这里。它位于 Flexible
            // （滚动区）**之外**，所以永远不会被内容滚动带走。
            // 壳不认识 header 的类型，只负责提供一个渲染位置。
            final sheetScope = SheetScope.maybeOf(context);

            // 键盘可见时只补一个固定小安全距，兼容输入法工具栏比
            // viewInsets 略高的情况；聚焦输入框的自动滚动由
            // TextField.scrollPadding（sheet_inputs.dart）负责。
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
                        if (sheetScope != null)
                          ValueListenableBuilder<Widget?>(
                            valueListenable: sheetScope.pinnedHeader,
                            builder: (BuildContext context, Widget? header, _) {
                              if (header == null) {
                                return const SizedBox.shrink();
                              }
                              // 左右 24dp 与滚动内容对齐；下方 12dp
                              // 是固定留白，内容里原有的 sectionGap
                              // 作为首项间距，滚动后内容顶到这 12dp 处。
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSheetSize.horizontalPadding,
                                  AppSpacing.xs,
                                  AppSheetSize.horizontalPadding,
                                  AppSpacing.sm,
                                ),
                                child: header,
                              );
                            },
                          ),
                        Flexible(
                          child: scrollable
                              ? SingleChildScrollView(
                                  padding: effectivePadding,
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  child: child ?? const SizedBox.shrink(),
                                )
                              : Padding(
                                  padding: effectivePadding,
                                  child: child ?? const SizedBox.shrink(),
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
      ),
    );
  }
}
