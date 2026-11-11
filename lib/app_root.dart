import 'package:flutter/material.dart';

import 'styles/app_typography.dart';

/// 全软件**唯一**的全局装配点，挂在 `MaterialApp.router.builder`。
///
/// ── 为什么要有这一层 ───────────────────────────────────────────
/// MaterialApp 的 builder 位于「Directionality / MediaQuery / Theme 之下、
/// Router 的 Navigator 之外」，它包住整个 Navigator —— 连
/// `showModalBottomSheet` 挂到 Overlay 上的 route 也在覆盖面内。
/// 这是唯一能「一处改、五个页面 + 六张 Sheet 全同步」的位置。
/// 没有它，以后每个全局行为都得散到五个页面各写一遍。
///
/// ── 当前实现 ───────────────────────────────────────────────────
/// 不再是纯透传：现在包一层 `MediaQuery`，只做**系统字体缩放夹取**。
/// 其余字段（size / viewInsets / padding / platformBrightness /
/// displayFeatures）全部原样保留，工作逻辑见 [build]。
///
/// ── 哪些挂在 AppRoot，哪些挂在 MaterialApp（别混）──────────────
/// 之前写「后续任务全部插在 [build] 这一处」太笼统，纠正：
///   · 挂在 **AppRoot**（builder）：文本缩放夹取（本轮）、以后的横屏
///     displayFeatures 覆盖、全局 ScrollConfiguration —— 这些是
///     「包住 Navigator 的树」；
///   · 挂在 **MaterialApp 自身参数**：localizationsDelegates /
///     supportedLocales / themeAnimationDuration / themeAnimationCurve
///     —— 它们是 WidgetsApp 的配置，写在 builder 里会绕过框架或重复
///     建一层，位置在 lib/main.dart，不在本文件。
///
/// 所以「全局装配」= main.dart 的 MaterialApp 参数 + 本文件的
/// AppRoot 包裹层，两处都要看；读 main.dart 就能找到本文件。
///
/// ── 任务进度 ───────────────────────────────────────────────────
///   ✅ ① 断点 + 收敛嵌套 Scaffold：AppShell 是全局唯一 Scaffold，
///       AppPageScaffold 已降级为纯内容骨架（都在远端）。
///   ✅ ② 三态骨架 + 国际化 + 文本缩放夹取 + 主题过渡：本轮落地。
///       三态零件在 screens/commons/state/，本地化与错误兜底在
///       app_locale.dart / app_error_handling.dart / main.dart。
///   ⬜ ③ 横屏 / 转场 / 键盘底导 / 全局 ScrollConfiguration：
///       横屏 MediaQuery 覆盖与 ScrollBehavior 挂这里；tab 转场与
///       底导键盘策略在 router_shell.dart。不急，随功能页一起做。
///
/// ── 两条硬约束，违反会出全局 bug ───────────────────────────────
/// 1. **child 必须原样返回**（它是 GoRouter 的 Navigator）。不要在这里
///    包 Scaffold / SafeArea / **独立新建的** MediaQuery：
///      · `AppShell` 是全局唯一的 Scaffold，且必须保住
///        resizeToAvoidBottomInset: true —— 前几轮键盘修复的根开关；
///      · `AppPageScaffold` 是纯内容骨架，只保留一处 SafeArea
///        （它包页面内容，不包 Navigator 的 Overlay）。
///    重复包会造成双 Scaffold、双键盘避让 —— 之前 Sheet 被键盘顶到
///    状态栏、最下方内容被遮挡，根子就在这种重复层叠上。
///
///    ⚠️ 本轮的 `MediaQuery.copyWith(...)` 是**唯一例外**，但要讲清：
///    它不是「新建一个独立 MediaQuery」，而是取当前 MediaQueryData 的
///    副本，只改 `textScaler`，其余字段**全部原样保留**。
///    因此键盘高度不会清零、断点判定读到的宽度不变，硬约束没被破坏。
///
/// 2. **不要在这里读 Provider / 做异步**。builder 会随路由变化重建；
///    主题状态由外层 `YuanApp` 的 Consumer 提供，取 `Theme.of(context)`
///    即可；持久化写在 `main()` 的 await 链路里。
///
/// ── 静态优先（项目约定）────────────────────────────────────────
/// 本文件无状态、无 Notifier、无回调注册、无跨帧。
/// 唯一的动态处理是「读当前 MediaQuery → 夹取 textScaler → 覆盖」，
/// 工作逻辑与边界就写在 [build] 里，看不懂代码看注释即可。
class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.child});

  /// MaterialApp.router 传入的 Navigator。允许为 null（框架在某些
  /// 初始化阶段会传空），此时渲染一个 0 尺寸占位，保证树不塌。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Widget navigator = child ?? const SizedBox.shrink();

    // ── 唯一动态处理：系统字体缩放夹取 ──────────────────────────
    // 为什么动态：用户在系统设置里改字号是运行时的，构造期定不死。
    //
    // 分步工作逻辑：
    //   1. MediaQuery.maybeOf 读当前数据（可能为 null：独立预览 /
    //      某些测试环境没有 MediaQuery，此时直接返回 navigator，不覆盖）；
    //   2. textScaler.clamp 把缩放限制在 AppTypography 的 0.9~1.3；
    //      Android 14+ 的非线性缩放也会被规整成这个范围内的线性缩放；
    //   3. mq.copyWith 只替换 textScaler，其余字段全部保留；
    //   4. MediaQuery 包住 navigator（含它的 Overlay，Sheet 也生效）。
    //
    // 边界行为：
    //   · 系统字号本来就在范围内 → clamp 返回等价 scaler，覆盖无副作用；
    //   · viewInsets / size / padding 不变 → 键盘避让与断点判定不受影响；
    //   · 夹取只影响文字渲染，不改变任何 widget 的固定 dp 尺寸。
    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    if (mq == null) return navigator;

    final TextScaler clamped = mq.textScaler.clamp(
      minScaleFactor: AppTypography.minTextScaleFactor,
      maxScaleFactor: AppTypography.maxTextScaleFactor,
    );

    return MediaQuery(
      data: mq.copyWith(textScaler: clamped),
      child: navigator,
    );
  }
}
