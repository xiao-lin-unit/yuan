import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

/// 应用根组件
class YuanApp extends StatelessWidget {
  const YuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '元 · 记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D5B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D5B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
