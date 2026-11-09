import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database/database_shell.dart';
import 'router/router_shell.dart';
import 'theme.dart';
import 'components.dart';


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
            theme: AppTheme.light(t.seed),
            darkTheme: AppTheme.dark(t.seed),
            themeMode: t.mode,
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
  List<ChangeNotifierProvider> svc = Services.initServices(db);

  runApp(YuanApp(theme: themeController, svc: svc));
}

