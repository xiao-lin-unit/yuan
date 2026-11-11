import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 全软件**唯一**的 Sheet 外壳。
///
/// ## 契约：壳 / 内容严格分离
///
/// ```
/// AppSheetShell.show(
///   context,
///   header: SheetHeader(title: '主题颜色'),   ← 静态、固定在顶端
///   child:  SelectSheetContent(...),          ← 任意 Widget，可滚动
/// )
///        │
///        ├── 壳只管：28dp 圆角、磨砂玻璃、极细描边、柔光阴影、
///        │          拖拽把手、home indicator、内容留白、滚动、
///        │          90% 屏高上限、键盘避让、barrier、关闭手势
///        │
///        └── child 只管：里面长什么样、有哪些控件、业务数据
///                       （contents/select、contents/form、… 或任意 Widget）
/// ```
///
/// ## 固定头部 = 布局，不是机制
///
/// `header` 是一个**构造期传入的静态 Widget 槽位**（就像
/// `Scaffold(appBar:)`）。壳的 Column 顺序就是规格说明：
///
/// ```
/// Column(
///   if (showGrabber)      SheetGrabber          ← 固定
///   if (header != null)   Padding(child: header) ← 固定（★）
///   Flexible( SingleChildScrollView(child) )     ← 只有这里滚
///   if (showHomeIndicator) SheetHomeIndicator   ← 固定
/// )
/// ```
///
/// 没有 ValueNotifier / InheritedWidget 提升 / postFrame 回调 /
/// 运行时注册。header 在第 1 帧就完整存在，看 Column 就知道它固定。
/// 壳不认识 header 里是什么（通常是 `SheetHeader`），只决定摆在哪。
///
/// `header` 与 `child` 都**允许为空**：空壳也是同一个壳。
/// 改「固定 / 不固定」「固定区留白」「要不要加分隔线」→ 只动本文件；
/// 改标题栏外观 → 只动 `SheetHeader` 零件；6 种内容零改动。
///
/// `contents/` 下的 `XxxSheetContent` 是「内容填充物」，不是 Sheet 组件：
/// 它们都是纯 `Column`，不套外壳、不调 `showModalBottomSheet`、
/// 不直接 `Navigator.pop`（统一走 [SheetActions.close]）。
class AppSheetShell extends StatelessWidget {
  const AppSheetShell({
    super.key,
    this.header,
    this.child,
    this.showGrabber = true,
    this.showHomeIndicator = true,
    this.scrollable = true,
    this.maxHeightFactor = AppSheetSize.maxSheetHeightFactor,
    this.contentPadding,
  });

  /// 固定在顶端、不随内容滚动的头部（静态 Widget 槽位）。
  /// `null` = 不显示。壳不读取、不解释它的类型。
  final Widget? header;

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
    Widget? header,
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
          header: header,
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

    // SheetScope 是壳给内容的唯一「我在 Sheet 内」标记（能力探测，
    // 工作逻辑见 sheet_primitives.dart 顶部注释）；内容组件只通过
    // SheetActions.close 请求关闭，不碰 Navigator。
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
                        // ★ 静态固定头部：构造期传入，放在 Flexible（滚动区）
                        //   之前，所以永远不会被内容滚动带走。Column 的
                        //   children 顺序本身就是规格，不需要任何注册机制。
                        //
                        //   下方留白取 AppSheetSize.sectionGap，等于内容组件
                        //   原来「SheetHeader 之后紧跟的 SizedBox」；那句已从
                        //   4 个内容组件里删掉，因此视觉间距保持不变。
                        if (header != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSheetSize.horizontalPadding,
                              AppSpacing.xs,
                              AppSheetSize.horizontalPadding,
                              AppSheetSize.sectionGap,
                            ),
                            child: header!,
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
