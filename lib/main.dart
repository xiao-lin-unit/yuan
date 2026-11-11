import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'app_root.dart';
import 'components.dart';
import 'database/database_shell.dart';
import 'router/router_shell.dart';
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
            // 全软件唯一的全局装配点：包住整个 Navigator（含 Sheet 弹层
            // 所在的 Overlay）。后续断点 / 三态骨架 / 国际化 / 横屏 /
            // 文本缩放 / 主题过渡全部挂这里，五个页面零改动。
            // 本轮只立闸：AppRoot 把 child 原样透传，界面与之前完全一致。
            // 工作逻辑与两条硬约束见 lib/app_root.dart 顶部注释。
            builder: (_, child) => AppRoot(child: child),
            routerConfig: appRouter,
          )
    ));

  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    runApp(ErrorWidget("软件初始化失败"));
    return;
  }

  final themeController = ThemeController();
  await themeController.load();

  // ✅ 等用户数据加载完再 runApp，首帧不再闪空白
  final svc = await Services.initServices(db);

  runApp(YuanApp(theme: themeController, svc: svc));
}
