import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'settings.dart';

class AppTheme {
  static ThemeData get lightTheme {

    return ThemeData(
      useMaterial3: true,

      /// ===== 基础 =====
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      fontFamily: font,

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
      cardTheme: ThemeSetting.cardTheme,

      /// ===== 列表 =====
      listTileTheme: ThemeSetting.listTileTheme,

      /// ===== 图标 =====
      iconTheme: ThemeSetting.iconTheme,

      /// ===== Divider =====
      dividerTheme: ThemeSetting.dividerTheme,

      /// ===== BottomSheet =====
      bottomSheetTheme: ThemeSetting.bottomSheetTheme,

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