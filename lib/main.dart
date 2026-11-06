import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;  // ← 加这个
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/database_shell.dart';  
import 'dart:io';
import 'router/router_shell.dart';
import 'theme.dart';


class YuanApp extends StatelessWidget {
  const YuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '裕安',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
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

  runApp(const YuanApp());
}

