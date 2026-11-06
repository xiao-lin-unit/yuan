import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ColorSetting {
  static final Map<String, Color> colors = {
    'blue': Color(0xFF4FC3F7),
    'red': Color(0xFFEF5350),
    'green': Color(0xFF66BB6A),
    'purple': Color(0xFFEA80FC),
    'pink': Color(0xFFFF80AB),
    'black': Colors.black,
    'orange': Color(0xFFFFD180),
    'black54': Colors.black54,
  };

  final Color _themeColor;

  ColorSetting(this._themeColor);

  static ColorSetting config({String themeColor = 'blue'}) {
    return ColorSetting(colors[themeColor]!);
  }

  Color get themeColor => _themeColor;
}

final String? font = GoogleFonts.notoSansSc().fontFamily;

final colorSetting = ColorSetting.config(themeColor: 'pink');

final colorScheme = ColorScheme.fromSeed(
  seedColor: colorSetting.themeColor,
  brightness: Brightness.dark,
);

class ThemeSetting {
  static TextTheme get textTheme => TextTheme(
    /// ===== Display（超大标题，极少用）=====
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      height: 1.15,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      height: 1.22,
    ),

    /// ===== Headline（页面级标题）=====
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.28,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.33,
    ),

    /// ===== Title（区块 / 组件标题）=====
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.45,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),

    /// ===== Body（正文）=====
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.43,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.33,
    ),

    /// ===== Label（按钮 / 标签）=====
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.43,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.33,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.27,
    ),
  );

  static AppBarTheme get appBarTheme => AppBarTheme(
    // backgroundColor: const Color(0xFFF2F3F5),
    elevation: 0,
    centerTitle: false,
    titleTextStyle: ThemeSetting.textTheme.titleLarge,
    iconTheme: IconThemeData(),
  );

  static NavigationBarThemeData get navigationBarThemeData =>
      NavigationBarThemeData(
        height: 56,
        // ← 控制高度
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // 标签行为，可选是否展示
        indicatorShape: const CircleBorder(
          side: BorderSide(width: 1.0, style: BorderStyle.none),
          eccentricity: 0.0,
        ),
        // 选中背景的形状控制
        elevation: 2,
        // 导航栏阴影高度

        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              size: 26,
              shadows: [Shadow(blurRadius: 6, offset: const Offset(0, 2))],
            );
          }
          return IconThemeData(size: 22);
        }),

        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
          }
          return TextStyle(fontSize: 12, fontWeight: FontWeight.normal);
        }),
      );

  static ElevatedButtonThemeData get elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: ThemeSetting.textTheme.labelLarge,
        ),
      );

  static TextButtonThemeData get textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(textStyle: ThemeSetting.textTheme.labelLarge),
  );

  static OutlinedButtonThemeData get outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: ThemeSetting.textTheme.labelLarge,
        ),
      );

  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    hintStyle: ThemeSetting.textTheme.bodyMedium?.copyWith(
      // color: colorScheme.onSurfaceVariant,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(width: 1.4),
    ),
  );

  /// ===== 卡片 =====
  static CardThemeData get cardTheme => CardThemeData(
    // color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );

  /// ===== 列表 =====
  static ListTileThemeData get listTileTheme => ListTileThemeData(
    // iconColor: colorScheme.onSurfaceVariant,
    // textColor: colorScheme.onSurface,
    titleTextStyle: ThemeSetting.textTheme.bodyLarge,
    subtitleTextStyle: ThemeSetting.textTheme.bodyMedium,
  );

  /// ===== 图标 =====
  static IconThemeData get iconTheme =>
      IconThemeData(size: 24);

  /// ===== Divider =====
  static DividerThemeData get dividerTheme => DividerThemeData(
    // color: colorScheme.outlineVariant,
    thickness: 1,
    space: 1,
  );

  /// ===== BottomSheet =====
  static BottomSheetThemeData get bottomSheetTheme => BottomSheetThemeData(
    // backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    // modalBarrierColor: Colors.black54,
  );

  /// ===== Dialog =====
  static DialogThemeData get dialogTheme => DialogThemeData(
    // backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: ThemeSetting.textTheme.titleLarge,
    contentTextStyle: ThemeSetting.textTheme.bodyMedium,
  );

  /// ===== SnackBar =====
  static SnackBarThemeData get snackBarTheme => SnackBarThemeData(
    // backgroundColor: colorScheme.inverseSurface,
    contentTextStyle: ThemeSetting.textTheme.bodyMedium?.copyWith(
      // color: colorScheme.onInverseSurface,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  /// ===== Switch / Checkbox / Radio =====
  static SwitchThemeData get switchTheme => SwitchThemeData(
    // thumbColor: WidgetStateProperty.resolveWith((states) {
    //   if (states.contains(WidgetState.selected)) {
    //     return colorScheme.onPrimary;
    //   }
    //   return colorScheme.outline;
    // }),
    // trackColor: WidgetStateProperty.resolveWith((states) {
    //   if (states.contains(WidgetState.selected)) {
    //     return colorScheme.primary;
    //   }
    //   return colorScheme.surfaceContainerHighest;
    // }),
  );

  static CheckboxThemeData get checkboxTheme => CheckboxThemeData(
    // fillColor: WidgetStateProperty.resolveWith((states) {
    //   if (states.contains(WidgetState.selected)) {
    //     return colorScheme.primary;
    //   }
    //   return Colors.transparent;
    // }),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );

  static RadioThemeData get radioTheme => RadioThemeData(
    // fillColor: WidgetStateProperty.resolveWith((states) {
    //   if (states.contains(WidgetState.selected)) {
    //     return colorScheme.primary;
    //   }
    //   return colorScheme.outline;
    // }),
  );

  /// ===== Tooltip =====
  static TooltipThemeData get tooltipTheme => TooltipThemeData(
    textStyle: ThemeSetting.textTheme.bodySmall,
    decoration: BoxDecoration(
      // color: colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(8),
    ),
  );

  /// ===== 滑动条 =====
  static SliderThemeData get sliderTheme => SliderThemeData(
    // activeTrackColor: colorScheme.primary,
    // inactiveTrackColor: colorScheme.surfaceContainerHighest,
    // thumbColor: colorScheme.primary,
  );

  /// ===== 进度条 =====
  static ProgressIndicatorThemeData get progressIndicatorTheme =>
      ProgressIndicatorThemeData(
        // color: colorScheme.primary,
        // linearTrackColor: colorScheme.surfaceContainerHighest,
      );

  static PageTransitionsTheme get pageTransitionsTheme => PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
