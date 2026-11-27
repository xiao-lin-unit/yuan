import 'package:material_ui/material_ui.dart';

import 'app_stroke.dart';
import 'color_math.dart';

/// 8pt 间距网格
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 圆角尺度：同一层级只用同一档。整体比 M3 默认放宽一档，
/// 卡片与列表项更接近 squircle，少一点「规整方框」的观感。
abstract final class AppRadius {
  static const double small = 10;
  static const double item = 14;
  static const double card = 20;
  static const double sheet = 24;
  static const double dialog = 28;
}

/// 动效时长（M3 短/中/长）
abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration long = Duration(milliseconds: 300);
}

/// 状态层透明度：hover / pressed / focus / disabled / 描边 / 提示文字
/// 全部集中在这里，禁止组件里再写 0.35 / 0.38 / 0.6 这类魔法小数。
abstract final class AppOpacity {
  static const double hover = 0.04;
  static const double pressed = 0.08;
  static const double selected = 0.10;
  static const double disabled = 0.38;
  static const double disabledContainer = 0.12;
  /// 划分性描边的不透明度。一屏十几个列表项若都带可见描边，
  /// 就会变成「圆角表格」；再压一半，只留贴近才察觉的一道暗示。
  static const double outline = 0.16;
  static const double outlineDark = 0.14;
  static const double hint = 0.7;
  static const double scrim = 0.4;
}

/// 强调表面的配色旋钮（本轮配色的**唯一可调处**）。
///
/// 【为什么集中在这里】配色要在你的掌控里：觉得 tint 太重 / 太轻，
/// 只改 [surfaceTint] 一个数，组件、页面、ThemeData 一个字都不用动；
/// 设成 0 就完全回到改造前的中性底，不需要回滚补丁。
abstract final class AppColorEmphasis {
  /// 中性容器（card / field）掺主色的比例。0.045 是「贴近才察觉」的量，
  /// 目的是让底色参与分层，不是把卡片染色 —— 满屏主色会失去留白与呼吸。
  /// tint 源取 cs.primary（已由 seed 派生），换主题 / 切亮暗自动跟随。
  static const double surfaceTint = 0.045;

  /// 强调表面上的大数字至少与底色差 3:1（WCAG AA 大字号门槛）。
  static const double accentMinContrast = 3.0;
}

/// 组件尺寸阶梯：Material 组件的固定尺寸统一放这里，
/// 避免 32 / 40 / 48 / 56 / 304 这类数字散落在各个 ThemeData 工厂里。
///
/// 判定：只定义「跨多个组件复用」的尺度；只属于某个组件的尺寸
/// 仍留在组件文件顶部的 `_k*` 私有常量区。
abstract final class AppComponentSize {
  static const double chipHeight = 32;
  static const double chipAvatar = 24;
  static const double chipDeleteIcon = 18;

  static const double tabBarHeight = 48;
  static const double tabIndicatorHeight = 3;

  static const double segmentedButtonHeight = 40;

  static const double fabSize = 56;
  static const double fabSmallSize = 40;
  static const double fabExtendedHeight = 56;

  static const double drawerWidth = 304;
  static const double popupMenuMinWidth = 224;

  /// 侧边导航：折叠态只放图标，展开态放图标 + 常驻文字。
  static const double railWidth = 80;
  static const double railExtendedWidth = 256;

  static const double badgeSmallSize = 6;
  static const double badgeLargeSize = 16;
  static const double linearProgressHeight = 4;

  static const double calendarMarkerSize = 6;
}

/// 阴影：亮色用更散更淡的真实阴影，暗色以 tonal elevation（容器色差）为主。
/// 列表项去掉描边后，「浮起感」主要靠这层阴影，不能像原来那样又近又实。
abstract final class AppElevation {
  static const double cardBlur = 18;
  static const double sheetBlur = 24;
  static const double cardAlpha = 0.05;
  static const double sheetAlpha = 0.10;
  static const Offset cardOffset = Offset(0, 4);
  static const Offset sheetOffset = Offset(0, -4);
}

/// 图标尺寸阶梯：同一层级只用同一档。
/// 整体收小一档：列表里的图标是「引导」不是「主角」，20~22dp 会把
/// 一行 16px 文字压下去。large 保留 24 给底导 / FAB / AppBar 这类
/// 需要独立可点的位置；empty 也收一档，空状态锚点不再喧宾夺主。
abstract final class AppIconSize {
  static const double small = 14;
  static const double medium = 18;
  static const double large = 24;
  static const double badge = 18;
  static const double empty = 28;
}

/// 描边宽度：常规 0.6dp 发丝线，强调 1.5dp。
///
/// 旧版 1dp / 2dp 在高分屏上等于 2~4 个物理像素，加上中灰实色，
/// 全屏卡片、列表、输入框都被框出很深的分界。現在按「划分是暗示
/// 而不是墙」处理：细到只有贴近内容时才察觉，聚焦 / 选中仍保留
/// 可辨识的强调宽度。所有 Divider thickness 也走这里，一处生效。
abstract final class AppBorder {
  static const double thin = 0.6;
  static const double focused = 1.5;
}

/// 窗口尺寸档位（Material 3 自适应断点）。
///
/// 【这是本任务引入的**动态布局**，把工作逻辑写清楚，别靠猜】
///
/// 为什么需要动态：同一份代码要跑在手机 / 平板竖屏 / 平板横屏 /
/// 桌面窗口 / Web 上，宽度是运行时才有的，构造期定不死。
/// 判定只发生在一处（[AppLayout.windowSizeOf]），结果只驱动两件事：
///   ① AppShell 用底部 NavigationBar 还是侧边 NavigationRail；
///   ② AppPageScaffold 的内容列最大宽度。
/// 除此之外没有任何组件读它，不扩散到业务页面。
///
/// 分步工作逻辑：
///   1. AppShell 的 LayoutBuilder 拿到 `constraints.maxWidth`（整屏宽）；
///   2. 调 [windowSizeOf] 得到档位；
///   3. compact → 底导 + maxContentWidth(640)；
///      medium  → 折叠式 rail + 640；
///      expanded → 展开式 rail + expandedContentWidth(840)；
///   4. 宽度 < 0 / 无穷大时按 compact 处理（边界见函数注释）。
///
/// 阈值取 M3 标准的 600 / 840，是「大众选择」而非拍脑袋：
/// 600 以下手机，600~840 平板竖屏 / 折叠屏展开，840 以上平板横屏 / 桌面。
/// 想调形态只需改这两个常量，五个页面零改动。
enum AppWindowSize {
  compact,
  medium,
  expanded,
}

/// 页面级布局节奏：统一所有页面的留白与最小高度。
/// 16dp 上下留白 + 16dp 分区间距在中文界面里偏挤，整体放宽一档，
/// 让「标题 → 摘要卡 → 列表」之间真正有呼吸；底导同步收矮一点。
abstract final class AppLayout {
  static const double pageTop = 24;
  static const double pageBottom = 40;
  static const double sectionGap = 24;
  static const double sectionHeaderTop = 20;
  static const double sectionHeaderBottom = 12;
  static const double navigationBarHeight = 64;
  static const double fieldMinHeight = 50;
  static const double listItemMinHeight = 56;
  static const double formRowMinHeight = 48;

  /// 窄屏 / 中屏内容列上限。手机（<600）时 640 不生效，等于不限宽。
  static const double maxContentWidth = 640;

  /// 宽屏内容列上限：比窄屏宽一档，但仍是「居中一列」而不是铺满，
  /// 避免 1200dp 桌面窗口里一行文字拉到 2 米长。
  static const double expandedContentWidth = 840;

  // ── 断点 ──────────────────────────────────────────────────────
  /// < 600 → compact；600..839 → medium；>= 840 → expanded。
  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 840;

  /// >= 600 就从底导切到侧边 rail（medium 折叠 / expanded 展开）。
  static const double railMinWidth = compactMaxWidth;

  /// 按可用宽度判档位。
  ///
  /// 边界行为（明确写清，免得以后猜）：
  ///   · 非有限值（infinity / NaN，出现在无约束的测试 widget 里）→ compact；
  ///   · 负数 / 0（窗口被压到极小）→ compact；
  ///   · 恰好 600 → medium，恰好 840 → expanded（左闭右开，无重叠）。
  static AppWindowSize windowSizeOf(double width) {
    if (!width.isFinite || width < compactMaxWidth) {
      return AppWindowSize.compact;
    }
    if (width < mediumMaxWidth) return AppWindowSize.medium;
    return AppWindowSize.expanded;
  }

  /// 该档位下页面内容列的最大宽度。只有 AppPageScaffold 调用。
  static double contentMaxWidthFor(AppWindowSize size) => switch (size) {
        AppWindowSize.compact => maxContentWidth,
        AppWindowSize.medium => maxContentWidth,
        AppWindowSize.expanded => expandedContentWidth,
      };

  /// 该档位是否用侧边 NavigationRail（否则用底部 NavigationBar）。
  static bool useNavigationRail(AppWindowSize size) =>
      size != AppWindowSize.compact;

  /// 该档位的 rail 是否展开显示文字（只有 expanded 展开）。
  static bool isRailExtended(AppWindowSize size) =>
      size == AppWindowSize.expanded;
}

/// 最小可点击区域（Material 无障碍 48dp，WCAG 2.2 AAA 44px）
const double kMinTapTarget = 48.0;

/// 挂载到 ThemeData.extensions 的设计令牌。
///
/// 自定义 Container / 阴影 / 语义色不再各写一遍 Theme.of(context).colorScheme.xxx，
/// 统一从这里取；主题色一换，所有派生色同步重算。
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  /// 记账语义色：收入 / 支出 / 提醒 / 信息，已 harmonize 到当前 seed
  final Color income;
  final Color onIncome;
  final Color expense;
  final Color onExpense;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;

  /// 容器层级：M3 surface container 五档里挑出常用的三档
  final Color card;
  final Color field;
  final Color sheet;
  final Color divider;
  final Color shadow;

  /// 强调表面三件套：只给「一张主色 hero」用，其余卡片仍是中性卡。
  /// surfaceEmphasis 取 primaryContainer 淡彩底；onEmphasis 取
  /// onPrimaryContainer（**不是硬写白**）；accentOnEmphasis 取 primary
  /// 并校对比度。三者都进 copyWith / lerp，主题切换动画不跳色。
  final Color surfaceEmphasis;
  final Color onEmphasis;
  final Color accentOnEmphasis;

  final double radiusCard;
  final double radiusItem;
  final double radiusField;
  final double radiusSheet;
  final double tapTarget;

  const AppThemeTokens({
    required this.income,
    required this.onIncome,
    required this.expense,
    required this.onExpense,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.card,
    required this.field,
    required this.sheet,
    required this.divider,
    required this.shadow,
    required this.surfaceEmphasis,
    required this.onEmphasis,
    required this.accentOnEmphasis,
    this.radiusCard = AppRadius.card,
    this.radiusItem = AppRadius.item,
    this.radiusField = AppRadius.item,
    this.radiusSheet = AppRadius.sheet,
    this.tapTarget = kMinTapTarget,
  });

  factory AppThemeTokens.fromScheme(ColorScheme cs, Color seed) {
    final dark = cs.brightness == Brightness.dark;

    Color semantic(Color base) => ColorMath.toneFor(
          ColorMath.harmonize(base, seed),
          cs.brightness,
        );

    final income = semantic(const Color(0xFF2E7D32));
    final expense = semantic(const Color(0xFFC62828));
    final warning = semantic(const Color(0xFFB26A00));
    final info = semantic(const Color(0xFF1565C0));

    // ── 强调表面三件套（本轮配色试点唯一一处新增取色）──────────────
    // 强调表面不再用 cs.primary 实色：整屏一块高饱和主色 + 白字是最像
    // 「后台模板」的观感。改用 primaryContainer 淡彩底 + 深色字，
    // 大数字仍取主色并校到 3:1。三件套都进 copyWith / lerp，
    // 换主题 / 切明暗不会跳色。
    final Color emphasis = cs.primaryContainer;
    final Color onEmphasis =
        ColorMath.ensureContrast(cs.onPrimaryContainer, emphasis);
    final Color accentOnEmphasis = ColorMath.ensureContrast(
      cs.primary,
      emphasis,
      minimum: AppColorEmphasis.accentMinContrast,
    );

    // 中性表面掺一点主色：整屏不再零彩度，但仍保持「中性卡」而不是主色卡。
    // 只在这里算一次，card / field 共用；sheet 玻璃层、语义色、金额色
    // 刻意不染（那三类不能带主色偏向）。只有两处调用且只是一行插值，
    // 不再往 ColorMath 抽一层函数，少一次跳转。
    Color tinted(Color neutral) => Color.lerp(
          neutral,
          cs.primary,
          AppColorEmphasis.surfaceTint,
        ) ??
        neutral;

    return AppThemeTokens(
      income: income,
      onIncome: ColorMath.ensureContrast(ColorMath.onColorFor(income), income),
      expense: expense,
      onExpense:
          ColorMath.ensureContrast(ColorMath.onColorFor(expense), expense),
      warning: warning,
      onWarning:
          ColorMath.ensureContrast(ColorMath.onColorFor(warning), warning),
      info: info,
      onInfo: ColorMath.ensureContrast(ColorMath.onColorFor(info), info),
      // 暗色下容器往上抬一档，避免「深灰卡片压在深灰背景上」没有层次；
      // 再掺一点主色 tint，让中性底色参与分层（强度见 AppColorEmphasis）。
      card: tinted(dark ? cs.surfaceContainerHigh : cs.surfaceContainerLow),
      field: tinted(cs.surfaceContainerHighest),
      // Sheet 玻璃层不染主色，保持中性。
      sheet: dark ? cs.surfaceContainer : cs.surfaceContainerLow,
      // 划分线不再用 M3 outlineVariant 实色（亮色偏深、暗色成深沟），
      // 统一走 AppStroke：往背景掺一点 onSurface 的中性色。
      divider: AppStroke.colorFor(cs),
      shadow: cs.shadow,
      surfaceEmphasis: emphasis,
      onEmphasis: onEmphasis,
      accentOnEmphasis: accentOnEmphasis,
    );
  }

  @override
  AppThemeTokens copyWith({
    Color? income,
    Color? onIncome,
    Color? expense,
    Color? onExpense,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? card,
    Color? field,
    Color? sheet,
    Color? divider,
    Color? shadow,
    Color? surfaceEmphasis,
    Color? onEmphasis,
    Color? accentOnEmphasis,
    double? radiusCard,
    double? radiusItem,
    double? radiusField,
    double? radiusSheet,
    double? tapTarget,
  }) {
    return AppThemeTokens(
      income: income ?? this.income,
      onIncome: onIncome ?? this.onIncome,
      expense: expense ?? this.expense,
      onExpense: onExpense ?? this.onExpense,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      card: card ?? this.card,
      field: field ?? this.field,
      sheet: sheet ?? this.sheet,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
      surfaceEmphasis: surfaceEmphasis ?? this.surfaceEmphasis,
      onEmphasis: onEmphasis ?? this.onEmphasis,
      accentOnEmphasis: accentOnEmphasis ?? this.accentOnEmphasis,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusItem: radiusItem ?? this.radiusItem,
      radiusField: radiusField ?? this.radiusField,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      tapTarget: tapTarget ?? this.tapTarget,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    double d(double a, double b) => a + (b - a) * t;
    return AppThemeTokens(
      income: c(income, other.income),
      onIncome: c(onIncome, other.onIncome),
      expense: c(expense, other.expense),
      onExpense: c(onExpense, other.onExpense),
      warning: c(warning, other.warning),
      onWarning: c(onWarning, other.onWarning),
      info: c(info, other.info),
      onInfo: c(onInfo, other.onInfo),
      card: c(card, other.card),
      field: c(field, other.field),
      sheet: c(sheet, other.sheet),
      divider: c(divider, other.divider),
      shadow: c(shadow, other.shadow),
      surfaceEmphasis: c(surfaceEmphasis, other.surfaceEmphasis),
      onEmphasis: c(onEmphasis, other.onEmphasis),
      accentOnEmphasis: c(accentOnEmphasis, other.accentOnEmphasis),
      radiusCard: d(radiusCard, other.radiusCard),
      radiusItem: d(radiusItem, other.radiusItem),
      radiusField: d(radiusField, other.radiusField),
      radiusSheet: d(radiusSheet, other.radiusSheet),
      tapTarget: d(tapTarget, other.tapTarget),
    );
  }
}

extension AppThemeTokensX on BuildContext {
  /// 业务代码统一用 `context.tokens.card` 之类，不再直接拼 colorScheme
  AppThemeTokens get tokens =>
      Theme.of(this).extension<AppThemeTokens>() ??
      AppThemeTokens.fromScheme(
        Theme.of(this).colorScheme,
        Theme.of(this).colorScheme.primary,
      );
}
