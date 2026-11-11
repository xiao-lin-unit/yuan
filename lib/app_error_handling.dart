import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'screens/commons/icons/app_icons.dart';
import 'screens/commons/state/app_error_state.dart';
import 'settings.dart';
import 'styles/theme_tokens.dart';
import 'theme.dart';

// ════════════════════════════════════════════════════════════════
// 全局错误兜底
//
// 之前 main() 里 `runApp(ErrorWidget("软件初始化失败"))` 有两个问题：
//   ① ErrorWidget 是 Flutter 内部「渲染异常」用的调试组件，直接当页面
//      用会显示红底调试屏，而且没有 Directionality / Material / 主题；
//   ② 没有任何错误捕获：构建期错误走默认红屏，异步未捕获错误直接交给
//      引擎，release 下用户看到的是黑屏或闪退，且没有任何线索。
//
// 本文件把「错误从哪来 → 怎么显示」收成唯一入口，main() 只调用一次。
// ════════════════════════════════════════════════════════════════

/// 安装三类全局错误处理。必须在 `WidgetsFlutterBinding.ensureInitialized()`
/// 之后、任何 `runApp` 之前调用一次。
///
/// ── 这是动态处理（全局回调注册），把工作逻辑写清楚 ──────────────
/// 为什么必须动态：错误发生在运行时、来自框架之外的任意位置，
/// 构造期无法预知，只能注册回调。
///
/// 分步工作逻辑：
///   1. `FlutterError.onError` —— 捕获框架构建/布局期错误。
///      仍调用 `FlutterError.presentError`，保证 debug 红屏与日志不丢失；
///      这里同时是**唯一的上报挂载点**，接崩溃上报只需改这一处。
///   2. `PlatformDispatcher.instance.onError` —— 捕获 root isolate 里
///      未被 Zone 接住的异步错误。记录后返回 true 表示「已处理」，
///      避免引擎走平台默认处理（通常是直接终止 / 黑屏）。
///      注意：返回 true 只保证不闪退，不保证业务状态一致；
///      严重错误后建议由使用方在页面层重置状态。
///   3. `ErrorWidget.builder` —— 只在 **release** 覆盖成友好占位。
///      debug 刻保留 Flutter 默认红屏：开发时要看到完整异常信息，
///      把它换成漂亮卡片反而会把问题藏起来。
///
/// 边界行为：
///   · 编译期错误、进程被系统杀死等严重情况**不会**触发这些回调；
///   · 三个回调都是全局单例，重复调用 install 只会覆盖，不会叠加；
///   · `_MinimalErrorWidget` 不依赖 Theme / Provider / 自定义令牌，
///     因为错误可能正好发生在主题系统里，再取 Theme.of 会二次抛错。
void installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    // 保留 Flutter 默认的控制台输出与 debug 红屏。
    FlutterError.presentError(details);
    // ★ 崩溃上报接在这里（Sentry / 自建日志等），不要散到各个页面。
    // 当前项目只做最小兜底，不接外部服务。
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('❌ 未捕获错误: $error');
    debugPrint(stack.toString());
    // 返回 true = 已处理，避免引擎直接终止；生产接上报后仍返回 true。
    return true;
  };

  if (!kDebugMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // 友好占位不带 details 原文：release 不向用户暴露堆栈与内部路径。
      return const _MinimalErrorWidget();
    };
  }
}

/// 启动阶段失败时显示的页面（数据库初始化失败等）。
///
/// 这里**不能**复用 `YuanApp`：那需要 ThemeController / Services /
/// Provider 全部就绪，而失败恰恰可能发生在它们之前。
/// 所以用最小 MaterialApp + 完整主题 + 本地化委托，直接显示
/// [AppErrorState] —— 三态骨架在「应用还没起来」时同样生效。
///
/// 刻意**不建 Scaffold**：全局「唯一 Scaffold」的纪律不能被兜底路径
/// 破坏。SafeArea + ColoredBox 已足够给错误态一个背景与安全区；
/// AppErrorState 里的文字都自带完整 TextStyle，不依赖 Scaffold 提供的
/// DefaultTextStyle。Builder 只为取当前主题的 surface 底色。
///
/// [message] 只传用户可读的友好文案，不要传原始异常字符串。
void runStartupFailure(String message) {
  runApp(
    MaterialApp(
      title: '裕安',
      theme: AppTheme.light(defaultColor),
      localizationsDelegates: AppLocale.delegates,
      supportedLocales: AppLocale.supportedLocales,
      home: SafeArea(
        child: Builder(
          builder: (BuildContext context) => ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: AppErrorState(
              title: '软件启动失败',
              description: message,
            ),
          ),
        ),
      ),
    ),
  );
}

/// release 下的极简错误占位。
///
/// ── 为什么这里故意不用设计系统 ─────────────────────────────────
/// 这是全项目**唯一**允许写死颜色/不取 `context.appText` 的地方：
/// ErrorWidget.builder 触发时，出错的可能正是 Theme / Provider /
/// AppThemeTokens 本身；再去 `Theme.of(context)` 会二次抛错，
/// 错误渲染会无限递归。所以自带 Directionality、自带一套由
/// `defaultColor` 静态生成的 ColorScheme，只依赖最基础的 widget。
///
/// 除此之外它没有任何动态逻辑：无状态、无回调、无条件分支。
class _MinimalErrorWidget extends StatelessWidget {
  const _MinimalErrorWidget();

  /// 静态生成一次，不依赖当前 Theme。种子取全局默认色（settings.dart）。
  static final ColorScheme _scheme = ColorScheme.fromSeed(
    seedColor: defaultColor,
    brightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // 自己包一层：不假设上层的 Directionality 还完好。
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: _scheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: DefaultTextStyle(
              // 不指定 fontSize：继承框架默认字号，避免写死魔法数字。
              style: TextStyle(color: _scheme.onSurface),
              textAlign: TextAlign.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    AppIcons.error,
                    size: AppIconSize.empty,
                    color: _scheme.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('界面出了点问题'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
