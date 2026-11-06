import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

abstract class AppTheme {

  static ThemeData light(Color seed) => _build(ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ));
  static ThemeData dark(Color seed) => _build(ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  ));

  static ThemeData _build(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // 关键：页面底色走 surface，暗色下自动变深灰
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      fontFamily: defaultFont,

      /// ===== 文本 =====
      textTheme: ThemeSetting.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),

      primaryTextTheme: ThemeSetting.textTheme.apply(
        bodyColor: colorScheme.onPrimary,
        displayColor: colorScheme.onPrimary,
      ),

      /// ===== AppBar =====
      appBarTheme: ThemeSetting.appBarTheme,

      /// ===== 底部 NavigationBar（M3）=====
      navigationBarTheme: ThemeSetting.navigationBarThemeData,

      /// ===== 按钮 =====
      elevatedButtonTheme: ThemeSetting.elevatedButtonTheme,

      textButtonTheme: ThemeSetting.textButtonTheme,

      outlinedButtonTheme: ThemeSetting.outlinedButtonTheme,

      /// ===== 输入框 =====
      inputDecorationTheme: ThemeSetting.inputDecorationTheme,

      /// ===== 卡片 =====
      cardTheme: ThemeSetting.cardTheme.copyWith(color: isDark ? colorScheme.surfaceContainerHigh : Colors.white),

      /// ===== 列表 =====
      listTileTheme: ThemeSetting.listTileTheme,

      /// ===== 图标 =====
      iconTheme: ThemeSetting.iconTheme,

      /// ===== Divider =====
      dividerTheme: ThemeSetting.dividerTheme,

      /// ===== BottomSheet =====
      bottomSheetTheme: ThemeSetting.bottomSheetTheme.copyWith(backgroundColor: colorScheme.surfaceContainerLow),

      /// ===== Dialog =====
      dialogTheme: ThemeSetting.dialogTheme,

      /// ===== SnackBar =====
      snackBarTheme: ThemeSetting.snackBarTheme,

      /// ===== Switch / Checkbox / Radio =====
      switchTheme: ThemeSetting.switchTheme,

      checkboxTheme: ThemeSetting.checkboxTheme,

      radioTheme: ThemeSetting.radioTheme,

      /// ===== Tooltip =====
      tooltipTheme: ThemeSetting.tooltipTheme,

      /// ===== 滑动条 =====
      sliderTheme: ThemeSetting.sliderTheme,

      /// ===== 进度条 =====
      progressIndicatorTheme: ThemeSetting.progressIndicatorTheme,

      /// ===== 效果 =====
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      pageTransitionsTheme: ThemeSetting.pageTransitionsTheme,
    );
  }
}

class ThemeController extends ChangeNotifier {
  static const _kMode = 'theme_mode';
  static const _kSeed = 'theme_seed';

  ThemeMode _mode = defaultMode;
  Color _seed = defaultColor;

  ThemeMode get mode => _mode;
  Color get seed => _seed;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _mode = ThemeMode.values[p.getInt(_kMode) ?? ThemeMode.system.index];
    final v = p.getInt(_kSeed);
    if (v != null) _seed = Color(v);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMode, m.index);
  }

  Future<void> setSeed(Color c) async {
    if (_seed == c) return;
    _seed = c;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSeed, c.toARGB32());
  }
}
