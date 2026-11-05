import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;  // ← 加这个
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/database_shell.dart';  
import 'dart:io';
import 'router/router_shell.dart';


class YuanApp extends StatelessWidget {
  const YuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '裕安',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        textTheme: TextTheme(
          displayLarge: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
          ),
          // ···
          titleLarge: GoogleFonts.oswald(
            fontSize: 30,
            fontStyle: FontStyle.italic,
          ),
          bodyMedium: GoogleFonts.merriweather(),
          displaySmall: GoogleFonts.pacifico(),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 56, // ← 控制高度
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          indicatorColor: Colors.teal.withValues(alpha: 0.15),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(size: 26, color: Colors.teal);
            }
            return const IconThemeData(size: 24, color: Colors.grey);
          }),
        ),
        useMaterial3: true,
      ),
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

