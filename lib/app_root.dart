import 'package:flutter/material.dart';

/// 全软件**唯一**的全局装配点，挂在 `MaterialApp.router.builder`。
///
/// ── 为什么要有这一层 ───────────────────────────────────────────
/// MaterialApp 的 builder 位于「Directionality / MediaQuery / Theme 之下、
/// Router 的 Navigator 之外」，它包住整个 Navigator —— 连
/// `showModalBottomSheet` 挂到 Overlay 上的 route 也在覆盖面内。
/// 这是唯一能「一处改、五个页面 + 六张 Sheet 全同步」的位置。
/// 没有它，以后每个全局行为都得散到五个页面各写一遍。
///
/// ── 本轮只立闸，不改任何界面表现 ───────────────────────────────
/// 当前实现 = 把 child 原样透传。真机跑起来必须和加之前**一模一样**，
/// 这就是本轮的回归判据。立闸的目的是让后续任务有唯一落点。
///
/// 后续三个任务，按下面顺序**全部插在 [build] 这一处**，页面零改动：
///
///   ① 断点 + 收敛嵌套 Scaffold → 在 AppShell / AppPageScaffold 改，
///      但断点常量与「宽屏切 NavigationRail」的判断入口挂这里；
///   ② 三态骨架 + 国际化 → 这里包 Localizations / Directionality /
///      全局 ErrorWidget.builder 与 loading/error 兜底；
///   ③ 横屏 / 转场 / 键盘底导 / 全局 ScrollConfiguration → 这里包
///      MediaQuery 覆盖与 ScrollBehavior。
///
/// 另两项（文本缩放夹取、AnimatedTheme 主题过渡）同样挂这里，
/// 随 ②③ 一起落地，不另开入口。
///
/// ── 两条硬约束，违反会出全局 bug ───────────────────────────────
/// 1. **child 必须原样返回**（它是 GoRouter 的 Navigator）。不要在这里
///    包 Scaffold / SafeArea / 第二层 MediaQuery：
///      · `AppShell` 已经是 Scaffold（含 resizeToAvoidBottomInset: true）；
///      · 页面是 `AppPageScaffold`（自带 Scaffold + SafeArea）。
///    重复包会造成双 SafeArea、双键盘避让 —— 前几轮 Sheet 被键盘顶到
///    状态栏、内容被遮挡，根子就在这种重复层叠上。
/// 2. **不要在这里读 Provider / 做异步**。builder 会随路由变化重建；
///    主题状态由外层 `YuanApp` 的 Consumer 提供，取 `Theme.of(context)`
///    即可；持久化写在 `main()` 的 await 链路里，不在这里。
///
/// ── 静态优先（项目约定）────────────────────────────────────────
/// 本文件默认全是静态结构：无状态、无回调注册、无 Notifier、无跨帧。
/// 以后每加一处动态装配，必须紧邻写清「为什么需要 / 分步工作逻辑 /
/// 失效与边界行为」，看不懂代码看注释即可。
class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.child});

  /// MaterialApp.router 传入的 Navigator。允许为 null（框架在某些
  /// 初始化阶段会传空），此时渲染一个 0 尺寸占位，保证树不塌。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // ★ 唯一的全局装配点。后续任务在这里按顺序往外插包裹层，
    //   最内层永远保持 child 原样 —— 顺序即规格，读这一个文件
    //   就能掌控全 App 的全局行为，不用翻五个页面。
    //
    //   context 本轮不使用（build 的标准签名保留具名，方便后续直接
    //   取 Theme / MediaQuery / Localizations，不需要另建 Builder）。
    //   main.dart 的 builder 参数本轮写成 `_`，同样不取 context。
    return child ?? const SizedBox.shrink();
  }
}
