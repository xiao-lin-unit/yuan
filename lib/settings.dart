import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 主题种子预设。
///
/// 旧版把 8 个 300 系浅色 + `black` / `black54` 混在一起当种子：
/// 无彩色种子会生成整套灰主题，浅色种子又让主色过淡、按钮白字看不清。
/// 现在统一用饱和度与明度适中的 500 系色，且每个都经过
/// ColorMath 的对比度与和谐化计算后才进入界面。
class ColorSetting {
  ColorSetting._();

  static const Map<String, Color> colors = <String, Color>{
    'blue': Color(0xFF3B82F6),
    'teal': Color(0xFF0D9488),
    'green': Color(0xFF16A34A),
    'violet': Color(0xFF7C3AED),
    'rose': Color(0xFFE11D48),
    'pink': Color(0xFFEC4899), // 兼容旧键名
    'amber': Color(0xFFD97706),
    'slate': Color(0xFF475569),
  };

  static const Map<String, String> labels = <String, String>{
    'blue': '晴空蓝',
    'teal': '青碧',
    'green': '原谅绿',// '竹绿',
    'violet': '韵味紫',// '紫藤',
    'rose': '姨妈红',// '胭脂',
    'pink': '猛男粉',// '樱粉',
    'amber': '琥珀',
    'slate': '石板灰',
  };

  /// 主题菜单里循环切换的顺序
  static const List<String> order = <String>[
    'blue',
    'teal',
    'green',
    'violet',
    'rose',
    'pink',
    'amber',
    'slate',
  ];

  static Color themeColor(String code) => colors[code] ?? colors['blue']!;

  static String labelOf(String code) => labels[code] ?? '晴空蓝';

  static String? keyOf(Color color) {
    final value = color.toARGB32();
    for (final entry in colors.entries) {
      if (entry.value.toARGB32() == value) return entry.key;
    }
    return null;
  }

  static String nextKey(String current) {
    final i = order.indexOf(current);
    return order[(i + 1) % order.length];
  }
}

/// 默认种子 / 默认外观：改成 final，禁止 UI 层再写全局变量污染默认值。
/// 旧版 `defaultColor = ...` 与 `defaultMode = ...` 被「主题/外观」菜单直接赋值，
/// 与 SharedPreferences 里持久化的值互相打架，重启后表现不一致。
final Color defaultColor = ColorSetting.themeColor('blue');
const ThemeMode defaultMode = ThemeMode.light;

/// 静态字体栈：不依赖运行时拉取 Google Fonts，避免首帧字体跳动 / 离线退化。
const String defaultFont = 'Noto Sans SC';
const List<String> defaultFontFallback = <String>[
  'PingFang SC',
  'Microsoft YaHei',
  'Noto Sans CJK SC',
  'sans-serif',
];

/// 组件主题：全部接收 [ColorScheme] 与 [AppThemeTokens]，
/// 不再出现 `Colors.white` / `BorderSide()`（默认黑色）这类写死值。
///
/// 注意：旧版给 Switch / Radio / Slider / ProgressIndicator 传了空的
/// `XxxThemeData()`，这会把 Material 3 的默认组件样式整个覆盖成空构造，
/// 等于悄悄关掉了 M3 外观。这里直接不设置这些字段，交回 Flutter 默认。
class ThemeSetting {
  ThemeSetting._();

  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, height: 1.12),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, height: 1.15),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, height: 1.22),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, height: 1.25),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.28),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.33),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.45),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.5),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.43),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.33),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.43),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.33),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.27),
  );

  static AppBarTheme appBarTheme(ColorScheme cs) => AppBarTheme(
    backgroundColor: cs.surface,
    foregroundColor: cs.onSurface,
    surfaceTintColor: cs.surfaceTint,
    shadowColor: cs.shadow,
    elevation: 0,
    scrolledUnderElevation: 2,
    centerTitle: false,
    titleTextStyle: textTheme.titleLarge?.copyWith(color: cs.onSurface),
    iconTheme: IconThemeData(color: cs.onSurfaceVariant, size: 24),
  );

  static NavigationBarThemeData navigationBarTheme(ColorScheme cs) =>
      NavigationBarThemeData(
        backgroundColor: cs.surfaceContainer,
        surfaceTintColor: cs.surfaceTint,
        // M3 底导靠 tonal elevation 分层，硬阴影 elevation:2 会在暗色下发灰
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: cs.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ) ??
              TextStyle(
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              );
        }),
      );

  static ElevatedButtonThemeData elevatedButtonTheme(
          ColorScheme cs, AppThemeTokens t) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          // 旧版 minimumSize: Size(infinity,48) 会让每个按钮都被迫撑满父宽
          minimumSize: Size(t.tapTarget, t.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusItem),
          ),
          textStyle: textTheme.labelLarge,
        ),
      );

  static TextButtonThemeData textButtonTheme(ColorScheme cs) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        ),
      );

  static OutlinedButtonThemeData outlinedButtonTheme(
          ColorScheme cs, AppThemeTokens t) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusItem),
          ),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        ),
      );

  /// ===== 输入框（本次核心修复）=====
  ///
  /// M3 filled text field 规范：
  ///  容器 = surfaceContainerHighest，输入文字 = onSurface，
  ///  label / hint / icon = onSurfaceVariant，聚焦指示线 = primary(2dp)，
  ///  未聚焦指示线 = onSurfaceVariant(1dp)，容器高 56dp，左右内边距 16dp。
  ///
  /// 旧版：`filled: true` 却不给 fillColor，`enabledBorder: BorderSide()`
  /// 是默认黑色 1px 边框，focusedBorder 也是黑；再加弹层写死白底，
  /// 于是出现「灰方块 + 黑描边贴在白纸上」的观感，暗色下更糟。
  static InputDecorationTheme inputDecorationTheme(
      ColorScheme cs, AppThemeTokens t) {
    final shape = BorderRadius.vertical(top: Radius.circular(t.radiusField));

    UnderlineInputBorder line(Color color, double width) =>
        UnderlineInputBorder(
          borderRadius: shape,
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: t.field,
      focusColor: t.field,
      hoverColor: cs.primary.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      constraints: const BoxConstraints(minHeight: 56),
      isDense: false,
      alignLabelWithHint: true,
      border: line(cs.onSurfaceVariant, 1),
      enabledBorder: line(cs.onSurfaceVariant, 1),
      focusedBorder: line(cs.primary, 2),
      errorBorder: line(cs.error, 1),
      focusedErrorBorder: line(cs.error, 2),
      disabledBorder: line(cs.onSurface.withValues(alpha: 0.12), 1),
      hintStyle: textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
      labelStyle: textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: cs.primary),
      helperStyle: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      counterStyle: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      errorStyle: textTheme.bodySmall?.copyWith(color: cs.error),
      iconColor: cs.onSurfaceVariant,
      prefixIconColor: cs.onSurfaceVariant,
      suffixIconColor: cs.onSurfaceVariant,
    );
  }

  static CardThemeData cardTheme(ColorScheme cs, AppThemeTokens t) =>
      CardThemeData(
        color: t.card,
        surfaceTintColor: cs.surfaceTint,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusCard),
        ),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      );

  static ListTileThemeData listTileTheme(ColorScheme cs, AppThemeTokens t) =>
      ListTileThemeData(
        textColor: cs.onSurface,
        iconColor: cs.onSurfaceVariant,
        minVerticalPadding: AppSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusItem),
        ),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle:
            textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );

  static IconThemeData iconTheme(ColorScheme cs) =>
      IconThemeData(size: 24, color: cs.onSurfaceVariant);

  static DividerThemeData dividerTheme(AppThemeTokens t) => DividerThemeData(
    color: t.divider,
    thickness: 1,
    space: 1,
  );

  static BottomSheetThemeData bottomSheetTheme(
          ColorScheme cs, AppThemeTokens t) =>
      BottomSheetThemeData(
        backgroundColor: t.sheet,
        surfaceTintColor: cs.surfaceTint,
        elevation: 1,
        modalElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(t.radiusSheet),
          ),
        ),
      );

  static DialogThemeData dialogTheme(ColorScheme cs) => DialogThemeData(
    backgroundColor: cs.surfaceContainerHigh,
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.dialog),
    ),
    titleTextStyle: textTheme.headlineSmall?.copyWith(color: cs.onSurface),
    contentTextStyle:
        textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
  );

  static SnackBarThemeData snackBarTheme(ColorScheme cs) => SnackBarThemeData(
    backgroundColor: cs.inverseSurface,
    contentTextStyle:
        textTheme.bodyMedium?.copyWith(color: cs.onInverseSurface),
    actionTextColor: cs.inversePrimary,
    behavior: SnackBarBehavior.floating,
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.item),
    ),
  );

  static TooltipThemeData tooltipTheme(ColorScheme cs) => TooltipThemeData(
    textStyle: textTheme.bodySmall?.copyWith(color: cs.onInverseSurface),
    decoration: BoxDecoration(
      color: cs.inverseSurface,
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    margin: const EdgeInsets.all(AppSpacing.xs),
  );

  static PageTransitionsTheme get pageTransitionsTheme => PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
