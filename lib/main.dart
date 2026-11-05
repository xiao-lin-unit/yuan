import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;  // ← 加这个
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/database_shell.dart';  
import 'dart:io';
import 'router/router_shell.dart';
import 'settings.dart';

final colorSetting = ColorSetting.config(navbar: 'pink', text: 'black54');

class YuanApp extends StatelessWidget {
  const YuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '裕安',
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(seedColor: colorSetting.textColor),
        // 字体设置
        fontFamily: GoogleFonts.notoSansSc().fontFamily,
        // 文字主题设置
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
        // 导航栏设置
        navigationBarTheme: NavigationBarThemeData(
          height: 56, // ← 控制高度
          backgroundColor: Colors.white70, // 背景色
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected, // 标签行为，可选是否展示
          indicatorShape: const CircleBorder(side: BorderSide(width: 1.0, style: BorderStyle.none), eccentricity: 0.0), // 选中背景的形状控制
          indicatorColor: Colors.white70.withValues(alpha: 0.15), // 选中项背景颜色
          shadowColor: Colors.white70.withValues(alpha: 0.3), // 导航栏整体阴影颜色
          elevation: 2,                                      // 导航栏阴影高度

          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(
                  size: 30,
                  color: colorSetting.navbarColor,  // 选中图标颜色
                  shadows: [
                    Shadow(
                      color: colorSetting.navbarColor, // 图标阴影颜色
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ]
              );
            }
            return IconThemeData(
                size: 28,
                color: colorSetting.textColor
            );
          }),
        ),
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

