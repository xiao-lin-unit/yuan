import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/styles/app_stroke.dart';
import 'package:yuan/styles/app_typography.dart';
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
    'green': '原谅绿',
    'violet': '韵味紫',
    'rose': '姨妈红',
    'pink': '猛男粉',
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

  /// 全局排版唯一来源，见 AppTypography。此处不再重复定义 15 档字号。
  static TextTheme get textTheme => AppTypography.textTheme;


  static AppBarTheme appBarTheme(ColorScheme cs) => AppBarTheme(
    backgroundColor: cs.surface,
    foregroundColor: cs.onSurface,
    surfaceTintColor: cs.surfaceTint,
    shadowColor: cs.shadow,
    elevation: 0,
    scrolledUnderElevation: 2,
    centerTitle: false,
    titleTextStyle: textTheme.titleLarge?.copyWith(color: cs.onSurface),
    iconTheme: IconThemeData(color: cs.onSurfaceVariant, size: AppIconSize.large),
  );

  static NavigationBarThemeData navigationBarTheme(ColorScheme cs) =>
      NavigationBarThemeData(
        backgroundColor: cs.surfaceContainer,
        surfaceTintColor: cs.surfaceTint,
        // M3 底导靠 tonal elevation 分层，硬阴影 elevation:2 会在暗色下发灰
        elevation: 0,
        height: AppLayout.navigationBarHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: cs.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppIconSize.large,
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

  /// 侧边导航（宽屏断点新增控件）。
  ///
  /// 与 [navigationBarTheme] 同一套取色与圆角，避免「手机底导」和
  /// 「平板 rail」选中态两种长相：底色 surfaceContainer、指示容器
  /// secondaryContainer、圆角 Stadium、未选中 onSurfaceVariant。
  /// 换主题色 / 切明暗时由 ThemeData 一处重算，AppShell 不写任何 Color。
  static NavigationRailThemeData navigationRailTheme(
          ColorScheme cs, AppThemeTokens t) =>
      NavigationRailThemeData(
        backgroundColor: cs.surfaceContainer,
        elevation: 0,
        indicatorColor: cs.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(
          size: AppIconSize.large,
          color: cs.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(
          size: AppIconSize.large,
          color: cs.onSurfaceVariant,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        // labelType 刻意不在这里定：它由 AppShell 按档位显式传
        // （medium=selected / expanded=extended 时不传），避免 theme 默认值
        // 与运行时形态打架。分组本项目不用，groupAlignment 留统一档位。
        groupAlignment: -1,
        minWidth: AppComponentSize.railWidth,
        minExtendedWidth: AppComponentSize.railExtendedWidth,
        useIndicator: true,
      );

  static ElevatedButtonThemeData elevatedButtonTheme(
          ColorScheme cs, AppThemeTokens t) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.onSurface.withValues(alpha: AppOpacity.disabledContainer),
          disabledForegroundColor: cs.onSurface.withValues(alpha: AppOpacity.disabled),
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
          disabledForegroundColor: cs.onSurface.withValues(alpha: AppOpacity.disabled),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        ),
      );

  static OutlinedButtonThemeData outlinedButtonTheme(
          ColorScheme cs, AppThemeTokens t) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: AppStroke.sideFor(cs),
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
  ///  label / hint / icon = onSurfaceVariant，聚焦指示线 = primary(1.5dp)，
  ///  未聚焦指示线 = AppStroke 低对比中性色(0.6dp)，容器高 56dp，左右 16dp。
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
      hoverColor: cs.primary.withValues(alpha: AppOpacity.hover),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      constraints: const BoxConstraints(minHeight: AppLayout.fieldMinHeight),
      isDense: false,
      alignLabelWithHint: true,
      // 未聚焦指示线以前用 onSurfaceVariant（接近正文色），在 filled
      // 容器底边画出一圈深色墙；改走 AppStroke 的低对比中性色。
      // 聚焦 / 错误仍用语义实色 + 稍宽，保证功能可辨识。
      border: line(AppStroke.colorFor(cs), AppBorder.thin),
      enabledBorder: line(AppStroke.colorFor(cs), AppBorder.thin),
      focusedBorder: line(cs.primary, AppBorder.focused),
      errorBorder: line(cs.error, AppStroke.emphasisWidth),
      focusedErrorBorder: line(cs.error, AppBorder.focused),
      disabledBorder: line(cs.onSurface.withValues(alpha: AppOpacity.disabledContainer), AppBorder.thin),
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
      IconThemeData(size: AppIconSize.large, color: cs.onSurfaceVariant);

  static DividerThemeData dividerTheme(AppThemeTokens t) => DividerThemeData(
    color: t.divider,
    thickness: AppBorder.thin,
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
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    margin: const EdgeInsets.all(AppSpacing.xs),
  );


  // ════════════════════════════════════════════════════════════════
  // 第二批组件主题
  //
  // 覆盖：Chip / TabBar / FloatingActionButton / Drawer / DatePicker /
  //       PopupMenu / SegmentedButton，顺手补 Badge / ProgressIndicator。
  //
  // 三条统一规则（与全局设计系统对齐）：
  //  1. 圆角只取 AppRadius（small / item / card / sheet / dialog），不写魔法数；
  //  2. 间距只取 AppSpacing（8pt 网格）与 kMinTapTarget（48dp 热区）；
  //  3. 选中态统一用 cs.secondaryContainer / cs.onSecondaryContainer 或
  //     cs.primary / cs.onPrimary，状态层透明度统一取 AppOpacity。
  //
  // 这些控件此前走 Flutter M3 默认值，虽然跟随 colorScheme，但圆角档位、
  // 内边距、选中态容器色与项目里其它组件（卡片 / 列表 / 按钮）并不一致。
  // 现在全部从同一套令牌派生，换主题色或切明暗时一处重算、全软件同步。
  // ════════════════════════════════════════════════════════════════

  /// 状态色解析器：所有 `WidgetStateProperty<Color?>` 字段共用一套优先级，
  /// 避免 Chip / DatePicker / SegmentedButton 各自写一遍判断顺序。
  static WidgetStateProperty<Color?> _stateColor({
    required Color base,
    required Color selected,
    required Color disabled,
    Color? hovered,
    Color? pressed,
  }) =>
      WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) return disabled;
        if (states.contains(WidgetState.selected)) return selected;
        if (states.contains(WidgetState.pressed)) {
          return pressed ?? hovered ?? base;
        }
        if (states.contains(WidgetState.hovered)) return hovered ?? base;
        return base;
      });

  /// 状态层（ripple / overlay）统一解析器：hover 4% / pressed 8% / selected 10%。
  static WidgetStateProperty<Color?> _overlayColor(ColorScheme cs) =>
      WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return cs.primary.withValues(alpha: AppOpacity.selected);
        }
        if (states.contains(WidgetState.pressed)) {
          return cs.primary.withValues(alpha: AppOpacity.pressed);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return cs.primary.withValues(alpha: AppOpacity.hover);
        }
        return null;
      });

  /// Chip：选中态 = secondaryContainer，描边 = divider，圆角 = small。
  static ChipThemeData chipTheme(ColorScheme cs, AppThemeTokens t) {
    final base = cs.surfaceContainerLow;
    final selected = cs.secondaryContainer;
    final disabled =
        cs.onSurface.withValues(alpha: AppOpacity.disabledContainer);
    return ChipThemeData(
      // color 是 3.47 起的状态色真源；刻意不再同时写
      // backgroundColor / selectedColor / disabledColor，避免两套规则打架。
      color: _stateColor(
        base: base,
        selected: selected,
        disabled: disabled,
      ),
      deleteIconColor: cs.onSurfaceVariant,
      checkmarkColor: cs.onSecondaryContainer,
      showCheckmark: true,
      side: BorderSide(
        color: t.divider.withValues(alpha: AppOpacity.outline),
        width: AppBorder.thin,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      labelStyle: textTheme.labelLarge?.copyWith(color: cs.onSurface),
      secondaryLabelStyle:
          textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      iconTheme: IconThemeData(
        size: AppIconSize.small,
        color: cs.onSurfaceVariant,
      ),
      elevation: 0,
      pressElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: cs.shadow,
      avatarBoxConstraints: const BoxConstraints.tightFor(
        width: AppComponentSize.chipAvatar,
        height: AppComponentSize.chipAvatar,
      ),
      deleteIconBoxConstraints: const BoxConstraints.tightFor(
        width: AppComponentSize.chipDeleteIcon,
        height: AppComponentSize.chipDeleteIcon,
      ),
    );
  }

  /// TabBar：3dp 主色下划线（带圆角）、分隔线 1dp、标签左右 16dp。
  static TabBarThemeData tabBarTheme(ColorScheme cs, AppThemeTokens t) =>
      TabBarThemeData(
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: cs.primary,
            width: AppComponentSize.tabIndicatorHeight,
          ),
          borderRadius:
              BorderRadius.circular(AppComponentSize.tabIndicatorHeight),
        ),
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: t.divider,
        dividerHeight: AppBorder.thin,
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        labelPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        overlayColor: _overlayColor(cs),
        splashFactory: InkRipple.splashFactory,
        splashBorderRadius: BorderRadius.circular(AppRadius.small),
      );

  /// FAB：主容器色 + card 档圆角，靠 tonal 分层而非硬阴影。
  static FloatingActionButtonThemeData floatingActionButtonTheme(
          ColorScheme cs) =>
      FloatingActionButtonThemeData(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        focusColor:
            cs.onPrimaryContainer.withValues(alpha: AppOpacity.hover),
        hoverColor:
            cs.onPrimaryContainer.withValues(alpha: AppOpacity.hover),
        splashColor:
            cs.onPrimaryContainer.withValues(alpha: AppOpacity.pressed),
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 2,
        disabledElevation: 0,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        iconSize: AppIconSize.large,
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        extendedIconLabelSpacing: AppSpacing.xs,
        extendedTextStyle: textTheme.labelLarge,
        sizeConstraints: const BoxConstraints.tightFor(
          width: AppComponentSize.fabSize,
          height: AppComponentSize.fabSize,
        ),
        smallSizeConstraints: const BoxConstraints.tightFor(
          width: AppComponentSize.fabSmallSize,
          height: AppComponentSize.fabSmallSize,
        ),
        extendedSizeConstraints: const BoxConstraints.tightFor(
          height: AppComponentSize.fabExtendedHeight,
        ),
        enableFeedback: true,
      );

  /// Drawer：start / end 两侧方向相反的圆角，宽度统一 304dp。
  static DrawerThemeData drawerTheme(ColorScheme cs, AppThemeTokens t) =>
      DrawerThemeData(
        backgroundColor: t.sheet,
        scrimColor: cs.scrim.withValues(alpha: AppOpacity.scrim),
        surfaceTintColor: Colors.transparent,
        shadowColor: cs.shadow,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadius.card),
          ),
        ),
        endShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(AppRadius.card),
          ),
        ),
        width: AppComponentSize.drawerWidth,
        clipBehavior: Clip.antiAlias,
      );

  /// DatePicker：dialog 档圆角，日期格 small 档圆角，
  /// 选中 / 今天 / 禁用 / 区间四套状态色全部走 _stateColor 与 _overlayColor。
  static DatePickerThemeData datePickerTheme(
      ColorScheme cs, AppThemeTokens t) {
    final dialogShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.dialog),
    );
    final cellShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
    );
    final disabled =
        cs.onSurface.withValues(alpha: AppOpacity.disabled);
    final dayForeground =
        WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return disabled;
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    });
    final dayBackground =
        WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) return cs.primary;
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return cs.primary.withValues(alpha: AppOpacity.hover);
      }
      return null;
    });
    final yearForeground =
        WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return disabled;
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    });
    final yearBackground =
        WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? cs.primary : null);
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: cs.primary,
      disabledForegroundColor: disabled,
      textStyle: textTheme.labelLarge,
      minimumSize: const Size(kMinTapTarget, kMinTapTarget),
    );

    return DatePickerThemeData(
      backgroundColor: t.sheet,
      surfaceTintColor: Colors.transparent,
      shadowColor: cs.shadow,
      elevation: 3,
      shape: dialogShape,
      headerBackgroundColor: cs.surfaceContainerHigh,
      headerForegroundColor: cs.onSurfaceVariant,
      headerHeadlineStyle:
          textTheme.headlineSmall?.copyWith(color: cs.onSurface),
      headerHelpStyle:
          textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      weekdayStyle:
          textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      dayStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
      dayForegroundColor: dayForeground,
      dayBackgroundColor: dayBackground,
      dayOverlayColor: _overlayColor(cs),
      dayShape: WidgetStateProperty.all<OutlinedBorder?>(cellShape),
      todayForegroundColor:
          WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) =>
              states.contains(WidgetState.selected)
                  ? cs.onPrimary
                  : cs.primary),
      todayBackgroundColor:
          WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? cs.primary : null),
      todayBorder:
          BorderSide(color: cs.primary, width: AppStroke.emphasisWidth),
      yearStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
      yearForegroundColor: yearForeground,
      yearBackgroundColor: yearBackground,
      yearOverlayColor: _overlayColor(cs),
      yearShape: WidgetStateProperty.all<OutlinedBorder?>(cellShape),
      rangePickerBackgroundColor: t.sheet,
      rangePickerShape: dialogShape,
      rangePickerHeaderBackgroundColor: cs.surfaceContainerHigh,
      rangePickerHeaderForegroundColor: cs.onSurfaceVariant,
      rangeSelectionBackgroundColor: cs.primaryContainer,
      rangeSelectionOverlayColor: _overlayColor(cs),
      dividerColor: t.divider,
      cancelButtonStyle: buttonStyle,
      confirmButtonStyle: buttonStyle,
      toggleButtonTextStyle:
          textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
      subHeaderForegroundColor: cs.onSurfaceVariant,
    );
  }

  /// PopupMenu：item 档圆角、8dp 垂直内边距，悬停/聚焦文字转主色。
  static PopupMenuThemeData popupMenuTheme(
          ColorScheme cs, AppThemeTokens t) =>
      PopupMenuThemeData(
        color: t.sheet,
        surfaceTintColor: Colors.transparent,
        shadowColor: cs.shadow,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.item),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        textStyle: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
        labelTextStyle:
            WidgetStateProperty.resolveWith<TextStyle?>((Set<WidgetState> states) {
          final base = textTheme.bodyLarge ?? const TextStyle();
          if (states.contains(WidgetState.disabled)) {
            return base.copyWith(
                color: cs.onSurface.withValues(alpha: AppOpacity.disabled));
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return base.copyWith(color: cs.primary);
          }
          return base.copyWith(color: cs.onSurface);
        }),
        iconColor: cs.onSurfaceVariant,
        iconSize: AppIconSize.large,
        enableFeedback: true,
      );

  /// SegmentedButton：选中态 = secondaryContainer，描边 = divider，
  /// 圆角 = small，最小高度 40dp 且保留 48dp 热区。
  static SegmentedButtonThemeData segmentedButtonTheme(
          ColorScheme cs, AppThemeTokens t) =>
      SegmentedButtonThemeData(
        selectedIcon: const Icon(AppIcons.check, size: AppIconSize.medium),
        style: ButtonStyle(
          backgroundColor: _stateColor(
            base: cs.surfaceContainerLow,
            selected: cs.secondaryContainer,
            disabled:
                cs.onSurface.withValues(alpha: AppOpacity.disabledContainer),
          ),
          foregroundColor: _stateColor(
            base: cs.onSurfaceVariant,
            selected: cs.onSecondaryContainer,
            disabled:
                cs.onSurface.withValues(alpha: AppOpacity.disabled),
          ),
          iconColor: _stateColor(
            base: cs.onSurfaceVariant,
            selected: cs.onSecondaryContainer,
            disabled:
                cs.onSurface.withValues(alpha: AppOpacity.disabled),
          ),
          overlayColor: _overlayColor(cs),
          side: WidgetStateProperty.resolveWith<BorderSide?>(
            (Set<WidgetState> states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? Colors.transparent
                  : t.divider,
              width: AppBorder.thin,
            ),
          ),
          shape: WidgetStateProperty.all<OutlinedBorder?>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
          padding: WidgetStateProperty.all<EdgeInsetsGeometry?>(
            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          minimumSize: WidgetStateProperty.all<Size?>(
            const Size(kMinTapTarget, AppComponentSize.segmentedButtonHeight),
          ),
          textStyle: WidgetStateProperty.all<TextStyle?>(
            textTheme.labelLarge,
          ),
          elevation: WidgetStateProperty.all<double?>(0),
        ),
      );

  /// Badge：与 SnackBar / 错误态同色系，尺寸走 8pt 网格。
  static BadgeThemeData badgeTheme(ColorScheme cs) => BadgeThemeData(
        backgroundColor: cs.error,
        textColor: cs.onError,
        smallSize: AppComponentSize.badgeSmallSize,
        largeSize: AppComponentSize.badgeLargeSize,
        textStyle: textTheme.labelSmall?.copyWith(color: cs.onError),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      );

  /// ProgressIndicator：轨道用 surfaceContainerHighest，圆角 = small。
  static ProgressIndicatorThemeData progressIndicatorTheme(ColorScheme cs) =>
      ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        circularTrackColor: cs.surfaceContainerHighest,
        refreshBackgroundColor: cs.surface,
        linearMinHeight: AppComponentSize.linearProgressHeight,
        borderRadius: BorderRadius.circular(AppRadius.small),
        stopIndicatorColor: cs.primary,
      );

  static PageTransitionsTheme get pageTransitionsTheme => PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
