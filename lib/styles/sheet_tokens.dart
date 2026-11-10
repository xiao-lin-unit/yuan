import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_stroke.dart';
import 'app_typography.dart';
import 'color_math.dart';
import 'theme_tokens.dart';

/// Sheet 专用圆角档位。
///
/// 原型里的弹层比项目原有 `AppRadius.sheet(20)` 更圆、更接近 iOS sheet，
/// 但**不修改** AppRadius.sheet —— 它还被 BottomSheetTheme / AppDecorations.sheet
/// 使用，改了会把已有弹层一起改掉。这里单独开一档，只给新 Sheet 组件用。
abstract final class AppSheetRadius {
  static const double modal = 28;
  static const double tile = 20;
  static const double metricCard = 16;
  static const double pill = 28;
  static const double grabber = 2;
}

/// Sheet 专用尺寸阶梯。
///
/// 判定：只放「会被 ≥2 个 Sheet 内容组件复用」的尺度；
/// 只属于某一张图的内容（比如某个柱子的具体高度算法）留在组件私有 `_k*`。
abstract final class AppSheetSize {
  static const double grabberWidth = 36;
  static const double grabberHeight = 4;
  static const double homeIndicatorWidth = 108;
  static const double homeIndicatorHeight = 4;

  static const double horizontalPadding = 24;
  static const double topPadding = 12;
  static const double bottomPadding = 16;
  static const double sectionGap = 20;
  static const double itemGap = 12;

  static const double primaryButtonHeight = 56;
  static const double secondaryButtonHeight = 56;
  static const double buttonMinWidth = 120;

  static const double metricCardMinHeight = 104;
  static const double metricCardGap = 12;

  static const double trendHeight = 140;
  static const double trendBarWidth = 18;
  static const double trendBaselineWidth = 1;

  static const double iconBadgeSize = 72;
  static const double iconBadgeIconSize = 32;

  static const double avatarSize = 96;
  static const double avatarCameraBadge = 32;

  /// 表单行：左侧 label 固定宽度（全软件表单对齐一致）
  static const double formLabelWidth = 72;

  /// 单选行：56dp 是 M3 双行 list tile 的高度，本行只有一行 16px 文字，
  /// 用 56 会上下各留约 17dp 空白。改 48dp（= 最小点击区 kMinTapTarget）
  /// 后配合紧凑行距，留白降到约 13dp，字号不变、可点区域仍达标。
  static const double optionRowHeight = 48;
  static const double optionRadioSize = 22;

  /// 单选行「代表色」色点直径（主题色选择等）
  static const double optionSwatchSize = 20;

  static const double categoryTileSize = 76;
  static const double categoryIconSize = 30;
  static const int categoryColumns = 4;

  static const double mediaCoverSize = 76;
  static const double mediaPlayButtonSize = 64;
  static const double mediaControlIconSize = 28;
  static const double sliderThumbRadius = 8;

  static const double maxSheetHeightFactor = 0.9;
  static const double glassBlurSigma = 18;
}

/// Sheet 专用透明度 / 光晕。
///
/// 原型是「近白磨砂玻璃 + 主色渐变按钮 + 同色柔和外发光」，
/// 这些数值集中在这里，组件里禁止再写 0.35 / 0.12 / 0.94 之类魔法小数。
abstract final class AppSheetOpacity {
  static const double glassLight = 0.94;
  static const double glassDark = 0.88;
  /// 玻璃弹层 / 选项容器的描边：旧版 0.6 中灰实边，等于给容器画了一圈墙。
  static const double glassOutline = 0.22;
  static const double glowLight = 0.34;
  static const double glowDark = 0.18;
  static const double glowDangerLight = 0.30;
  static const double glowDangerDark = 0.16;
  static const double scrim = 0.42;
  static const double inactiveBar = 0.12;
  static const double chipUnselected = 0.06;
  static const double categoryTint = 0.13;
  static const double selectedRowTint = 0.55;
  static const double grabber = 0.3;
  static const double homeIndicator = 0.35;
}

/// Sheet 渐变与玻璃调色板：原型里所有「蓝紫渐变 / 光晕 / 浅紫底」的**唯一**来源。
///
/// 关键取舍：渐变不是写死 `Color(0xFF3B5BFF) → Color(0xFF7B5CFF)`，
/// 而是从当前 `ColorScheme.primary` 用 HSL 派生第二色。
/// 于是在「主题」里循环 8 个预设、或切到暗色时，6 张 Sheet 里的
/// 主按钮、高亮柱、选中分类格会一起跟着变，不需要回头改任何组件。
class SheetPalette {
  SheetPalette._(this.cs, this.tokens);

  final ColorScheme cs;
  final AppThemeTokens tokens;

  static SheetPalette of(BuildContext context) => SheetPalette._(
        Theme.of(context).colorScheme,
        context.tokens,
      );

  bool get isDark => cs.brightness == Brightness.dark;

  /// 从基色按色相 / 明度派生渐变的第二色。
  Color _shift(
    Color base, {
    required double hueDelta,
    required double lightnessDelta,
    double saturationScale = 0.92,
  }) {
    final h = HSLColor.fromColor(base);
    final next = h
        .withHue((h.hue + hueDelta) % 360)
        .withSaturation(
          (h.saturation * saturationScale).clamp(0.0, 1.0).toDouble(),
        )
        .withLightness(
          (h.lightness + (isDark ? -lightnessDelta : lightnessDelta))
              .clamp(0.18, 0.86)
              .toDouble(),
        );
    // 已直接从 primary / 语义色派生，天然同系，不需要再 harmonize
    //（二次和谐化会把危险红朝蓝色种子拉偏）。
    return next.toColor();
  }

  /// 主操作渐变：primary → 略偏紫 / 略亮的同系色。
  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          cs.primary,
          _shift(cs.primary, hueDelta: 26, lightnessDelta: 0.07),
        ],
      );

  /// 危险操作渐变：从已 harmonize 的语义「支出」红派生。
  LinearGradient get dangerGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          tokens.expense,
          _shift(tokens.expense, hueDelta: 10, lightnessDelta: 0.08),
        ],
      );

  Color get onPrimaryGradient => ColorMath.onColorFor(cs.primary);
  Color get onDangerGradient => ColorMath.onColorFor(tokens.expense);

  List<BoxShadow> get primaryGlow => <BoxShadow>[
        BoxShadow(
          color: cs.primary.withValues(
            alpha: isDark ? AppSheetOpacity.glowDark : AppSheetOpacity.glowLight,
          ),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  List<BoxShadow> get dangerGlow => <BoxShadow>[
        BoxShadow(
          color: tokens.expense.withValues(
            alpha: isDark
                ? AppSheetOpacity.glowDangerDark
                : AppSheetOpacity.glowDangerLight,
          ),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// 磨砂玻璃本体：亮色近白半透，暗色深灰半透，都带一圈极细高光描边。
  Color get glassColor => tokens.sheet.withValues(
        alpha: isDark
            ? AppSheetOpacity.glassDark
            : AppSheetOpacity.glassLight,
      );

  Color get glassBorder => AppStroke.colorFor(cs).withValues(
        alpha: AppSheetOpacity.glassOutline,
      );

  /// 选中行 / 选中 chip 的浅紫底：surface 与 primaryContainer 之间插值。
  Color get selectedTint => Color.lerp(
            cs.surface,
            cs.primaryContainer,
            AppSheetOpacity.selectedRowTint,
          ) ??
      cs.primaryContainer;

  Color get unselectedTint => cs.surfaceContainerHighest;
  Color get inactiveBar =>
      cs.onSurface.withValues(alpha: AppSheetOpacity.inactiveBar);
  Color get grabberColor =>
      cs.onSurfaceVariant.withValues(alpha: AppSheetOpacity.grabber);
  Color get homeIndicatorColor =>
      cs.onSurface.withValues(alpha: AppSheetOpacity.homeIndicator);
  Color get scrimColor =>
      cs.scrim.withValues(alpha: AppSheetOpacity.scrim);
  Color get dividerColor => tokens.divider;
  Color get mutedText => cs.onSurfaceVariant;
  Color get bodyText => cs.onSurface;

  /// 分类网格的语义色：由主色等距旋转色相派生，
  /// 12 个格子天然协调，且换主题 / 切明暗时整体平移，不写死 12 个 hex。
  Color categoryTone(int index) {
    final h = HSLColor.fromColor(cs.primary);
    return h
        .withHue((h.hue + index * 34.0) % 360)
        .withSaturation(0.62)
        .withLightness(isDark ? 0.68 : 0.46)
        .toColor();
  }

  Color categoryTileTone(int index) => categoryTone(index)
      .withValues(alpha: AppSheetOpacity.categoryTint);

  /// 玻璃模糊滤镜（供 BackdropFilter 复用，避免各组件各建一个对象）。
  ImageFilter get glassFilter => ImageFilter.blur(
        sigmaX: AppSheetSize.glassBlurSigma,
        sigmaY: AppSheetSize.glassBlurSigma,
      );
}

/// 排版便捷入口：Sheet 组件统一用 `SheetText.of(context)`，
/// 不直接写 `TextStyle(fontSize: ...)`，颜色由当前 ColorScheme 注入。
class SheetText {
  SheetText(this.cs);

  final ColorScheme cs;

  static SheetText of(BuildContext context) =>
      SheetText(Theme.of(context).colorScheme);

  TextStyle get title =>
      AppTypography.sheetTitle.copyWith(color: cs.onSurface);
  TextStyle get subtitle =>
      AppTypography.sheetSubtitle.copyWith(color: cs.onSurfaceVariant);
  TextStyle get caption =>
      AppTypography.sheetCaption.copyWith(color: cs.onSurfaceVariant);
  TextStyle get sectionLabel =>
      AppTypography.sectionLabel.copyWith(color: cs.onSurfaceVariant);
  TextStyle get metricLabel =>
      AppTypography.metricLabel.copyWith(color: cs.onSurfaceVariant);
  TextStyle get metricValue =>
      AppTypography.metricValue.copyWith(color: cs.primary);
  TextStyle get metricUnit =>
      AppTypography.metricUnit.copyWith(color: cs.onSurfaceVariant);
  TextStyle get buttonLabel =>
      AppTypography.buttonLabel.copyWith(color: cs.onPrimary);
  TextStyle get plainButtonLabel =>
      AppTypography.buttonLabel.copyWith(color: cs.onSurface);
  TextStyle get optionLabel =>
      AppTypography.optionLabel.copyWith(color: cs.onSurface);
  TextStyle get optionLabelSelected =>
      AppTypography.optionLabel.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w600,
      );
  TextStyle get confirmTitle =>
      AppTypography.confirmTitle.copyWith(color: cs.onSurface);
  TextStyle get confirmBody =>
      AppTypography.confirmBody.copyWith(color: cs.onSurfaceVariant);
  TextStyle get mediaTitle =>
      AppTypography.mediaTitle.copyWith(color: cs.onSurface);
  TextStyle get mediaSubtitle =>
      AppTypography.mediaSubtitle.copyWith(color: cs.onSurfaceVariant);
  TextStyle get categoryLabel =>
      AppTypography.categoryLabel.copyWith(color: cs.onSurface);
  TextStyle get categoryLabelSelected =>
      AppTypography.categoryLabel.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w600,
      );
  TextStyle get chipLabel =>
      AppTypography.chipLabel.copyWith(color: cs.onSurface);
  TextStyle get chipLabelSelected =>
      AppTypography.chipLabel.copyWith(color: cs.primary);
  TextStyle get trendLabel =>
      AppTypography.trendLabel.copyWith(color: cs.onSurfaceVariant);
  TextStyle get fieldLabel =>
      AppTypography.optionLabel.copyWith(color: cs.onSurface);
  TextStyle get fieldValue =>
      AppTypography.optionLabel.copyWith(color: cs.onSurfaceVariant);

  /// 单行输入专用：把 1.40 行高压到 1.0。
  ///
  /// [AppTypography.optionLabel] 的 height 1.40 是为多行 / 换行准备的，
  /// 单行 TextField 带着这段额外 leading 时，文字在自身行框里偏上，
  /// 外层再怎么居中看起来都像「顶到上边框」。单行与多行从 style 上
  /// 就分开，不再共用同一个 TextStyle。
  TextStyle get fieldLabelSingleLine =>
      AppTypography.optionLabel.copyWith(
        color: cs.onSurface,
        height: 1.0,
      );
  TextStyle get fieldValueSingleLine =>
      AppTypography.optionLabel.copyWith(
        color: cs.onSurfaceVariant,
        height: 1.0,
      );

  /// 单选行 / 紧凑列表专用：字号不变，只收行距。
  /// 配合 AppSheetSize.optionRowHeight(48) 消除「行高有余、字很小」的空。
  TextStyle get optionLabelCompact =>
      AppTypography.optionLabel.copyWith(
        color: cs.onSurface,
        height: 1.2,
      );
  TextStyle get optionLabelCompactSelected =>
      AppTypography.optionLabel.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );
}

extension SheetTextX on BuildContext {
  SheetText get sheetText => SheetText.of(this);
}
