import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;  // ← 加这个
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yuan/settings.dart';
import 'database/database_shell.dart';  
import 'dart:io';
import 'router/router_shell.dart';
import 'theme.dart';


class YuanApp extends StatelessWidget {
  final ThemeController theme;
  const YuanApp({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: theme,
      child: Consumer<ThemeController>(
        builder: (context, t, _) => MaterialApp.router(
          title: '裕安',
          theme: AppTheme.light(defaultColor),
          darkTheme: AppTheme.dark(defaultColor),
          themeMode: t.mode,
          routerConfig: appRouter,
        )
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  DatabaseService().database.then((_) {
    debugPrint('✅ 数据库就绪');
  }).catchError((e) {
    debugPrint('❌ 数据库初始化失败: $e');
  });
  final theme = ThemeController();
  await theme.load();
  runApp(YuanApp(theme: theme,));
}

