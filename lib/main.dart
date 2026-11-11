import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app_error_handling.dart';
import 'app_locale.dart';
import 'app_root.dart';
import 'components.dart';
import 'database/database_shell.dart';
import 'router/router_shell.dart';
import 'styles/theme_tokens.dart';
import 'theme.dart';


class YuanApp extends StatelessWidget {
  final ThemeController theme;
  final List<ChangeNotifierProvider> svc;
  const YuanApp({super.key, required this.theme, required this.svc});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: theme),
          ...svc,
        ],
        child: Consumer<ThemeController>(
          builder: (context, t, _) => MaterialApp.router(
            title: '裕安',
            // AppTheme 内部按 (seed, brightness, contrast) 缓存，
            // 切颜色时不会再重算整套 ColorScheme + 组件主题。
            theme: AppTheme.light(t.seed, contrast: t.contrast),
            darkTheme: AppTheme.dark(t.seed, contrast: t.contrast),
            themeMode: t.mode,

            // ── 框架级国际化 ────────────────────────────────────
            // 让 DatePicker / table_calendar / Material 内置文案（确定、
            // 取消、复制…）跟随语言；委托与语言列表收在 AppLocale 一处。
            // 不设 locale：跟随系统，系统语言不在列表里时回退到 zh_CN。
            // 业务文案目前仍是硬编码中文，见 app_locale.dart 的边界说明。
            localizationsDelegates: AppLocale.delegates,
            supportedLocales: AppLocale.supportedLocales,

            // ── 主题过渡 ────────────────────────────────────────
            // 纠正之前「硬闪」的说法：MaterialApp 内部本来就有
            // AnimatedTheme（默认 kThemeAnimationDuration=200ms、线性曲线），
            // 且 AppThemeTokens 已实现 ThemeExtension.lerp，颜色可插值。
            // 这里只是把时长收进全局令牌并换成缓动，让 8 个主题色切换
            // 与明暗切换更顺；**不**在 AppRoot 里再包一层 AnimatedTheme，
            // 否则两层动画会互相覆盖。
            themeAnimationDuration: AppMotion.long,
            themeAnimationCurve: Curves.easeInOut,

            // 全软件唯一的全局装配点：包住整个 Navigator（含 Sheet 弹层
            // 所在的 Overlay）。当前负责系统字体缩放夹取；以后的横屏 /
            // 全局 ScrollConfiguration 也挂这里。工作逻辑、两条硬约束
            // 与「哪些参数该写在 MaterialApp 而不是这里」见 app_root.dart。
            builder: (_, child) => AppRoot(child: child),
            routerConfig: appRouter,
          )
    ));

  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局错误兜底：必须在任何 runApp 之前安装一次。
  // 三类回调的完整工作逻辑与边界见 app_error_handling.dart。
  installGlobalErrorHandlers();

  // 日历中文月份 / 星期：table_calendar 内部用 intl.DateFormat，
  // 中文符号数据要显式初始化，否则即使挂了本地化委托仍显示英文。
  // 失败只影响日历文案，不阻断启动，所以单独 try 而不并入主流程。
  try {
    await initializeDateFormatting(AppLocale.dateFormattingLocale, null);
  } catch (e) {
    debugPrint('⚠️ 日期本地化数据初始化失败: $e');
  }

  // if (!kIsWeb) {
  //   if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  //     sqfliteFfiInit();
  //     databaseFactory = databaseFactoryFfi;
  //   }
  // }

  Database? db;

  try {
    db = await DatabaseService.instance.database;
    debugPrint('✅ 数据库就绪');
  } catch (e, st) {
    debugPrint('❌ 数据库初始化失败: $e');
    debugPrint(st.toString());
  }

  if (db == null) {
    // 旧版直接把 Flutter 内部的 ErrorWidget 当整页用：那是调试红屏组件，
    // 没有主题 / 本地化 / Directionality。现在走统一的三态 error 骨架。
    runStartupFailure('本地数据初始化失败，请重启应用后重试。');
    return;
  }

  final themeController = ThemeController();
  await themeController.load();

  // ✅ 等用户数据加载完再 runApp，首帧不再闪空白
  final svc = await Services.initServices(db);

  runApp(YuanApp(theme: themeController, svc: svc));
}
