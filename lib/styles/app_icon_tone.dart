import 'package:flutter/material.dart';

import 'color_math.dart';
import 'theme_tokens.dart';

/// 全软件图标浓度。
///
/// 只改 [AppIconTone.intensity] 一处即可整体在「克制 / 鲜明」间切换，
/// 所有组件自动跟随，不需要回到业务页面改任何一个参数。
/// 当前为 **鲜明档**：12 色相环铺到菜单 / 分区 / 底导，容器改双色渐变 +
/// 光晕，接近分类网格的观感，但 16–24px 高频功能图标仍保持单色。
enum AppIconIntensity { restrained, vivid }

/// 图标的**强调档位**，对应 Material 3 icon button 的 standard / tonal / filled。
enum AppIconEmphasis { standard, tonal, filled }

/// 全软件**唯一的图标色彩层**。
///
/// 职责：「语义 → 色 → duotone/渐变 色对」。
/// - 所有色值来自 [AppThemeTokens] / [ColorScheme]，且经 harmonize 到 seed，
///   换主题色 / 切明暗时自动重算，组件里不留任何固定 hex；
/// - 每个色对都用 [ColorMath.ensureContrast] 校验到 4.5:1。小图标有色像素
///   占比低、抗锯齿吃掉边缘，实践上比 WCAG 非文本 3:1 更严；
/// - 语义色不随浓度漂移：回收站永远是支出红、外观永远是琥珀，
///   否则颜色会失去表意能力。
class AppIconTone {
  AppIconTone._(this.cs, this.tokens, this.brightness);

  final ColorScheme cs;
  final AppThemeTokens tokens;
  final Brightness brightness;

  // ── 全局浓度开关（一处切换，全软件同步）──────────────────────
  static const AppIconIntensity intensity = AppIconIntensity.restrained;

  static AppIconTone of(BuildContext context) {
    final theme = Theme.of(context);
    return AppIconTone._(theme.colorScheme, context.tokens, theme.brightness);
  }

  bool get isVivid => intensity == AppIconIntensity.vivid;
  bool get isDark => brightness == Brightness.dark;

  // ── 语义色（全部已 harmonize 到当前 seed）────────────────────
  Color get brand => cs.primary;
  Color get tertiary => cs.tertiary;
  Color get info => tokens.info;
  Color get warning => tokens.warning;
  Color get danger => tokens.expense;
  Color get success => tokens.income;

  /// 提高饱和度但不改色相，用于鲜明档。无彩色（灰）跳过。
  Color _boost(Color c) {
    final hsl = HSLColor.fromColor(c);
    if (hsl.saturation < 0.05) return c;
    return hsl.withSaturation((hsl.saturation * 1.25).clamp(0.62, 0.86)).toColor();
  }

  /// 12 色相环：与 `SheetPalette.categoryTone` 同一套算法（从 seed 起
  /// 每 34°），所以菜单 / 分区 / 底导 / 分类网格属于同一种视觉语言。
  /// 鲜明档把饱和度提到 0.72，明度按明暗取 0.68 / 0.44。
  Color forIndex(int index) {
    final h = HSLColor.fromColor(cs.primary);
    final i = ((index % 12) + 12) % 12;
    return h
        .withHue((h.hue + i * 34.0) % 360)
        .withSaturation(isVivid ? 0.72 : 0.62)
        .withLightness(isDark ? 0.68 : (isVivid ? 0.44 : 0.46))
        .toColor();
  }

  /// 无显式语义时按 IconData 码点稳定派生（四个占位页各得一色）。
  Color forIcon(IconData icon) => forIndex(icon.codePoint % 12);

  /// 菜单项按业务 key 取色，[index] 用于鲜明档铺 12 色环。
  ///
  /// 克制档：8 个 key 映射到 6 组语义色；
  /// 鲜明档：危险 / 警告 / 信息 / 成功这类**语义色保持不漂移**，
  /// 其余项按列表序号铺色环 —— 一屏内颜色明显更多，但回收站不会变绿。
  Color forMenuKey(String? key, {int index = 0}) {
    final restrained = switch (key) {
      'knowledge' || 'about' => info,
      'export' || 'manage' => tertiary,
      'import' || 'color' || 'function' => brand,
      'appearance' => warning,
      'category' => success,
      'trash' => danger,
      _ => brand,
    };
    if (!isVivid) return restrained;

    // 语义色不能随浓度漂移，只提高饱和；其余项铺色环。
    final semantic = switch (key) {
      'knowledge' || 'about' || 'appearance' || 'category' || 'trash' => true,
      _ => false,
    };
    return semantic ? _boost(restrained) : forIndex(index);
  }

  /// 分区标题尾图标：鲜明档按标题稳定映射到色环（与菜单错开 3 格）。
  Color forSectionTitle(String title) {
    if (isVivid) {
      final hash = title.codeUnits.fold<int>(0, (a, b) => a + b);
      return forIndex(hash % 12 + 3);
    }
    return switch (title) {
      '关于' => info,
      '管理' => tertiary,
      _ => brand,
    };
  }

  /// 底导 5 个 tab 各取色环上间隔较大、辨识度高的 5 格。
  Color forTab(int index) {
    if (isVivid) {
      return switch (index) {
        0 => forIndex(0),  // 记账
        1 => forIndex(3),  // 资债
        2 => forIndex(6),  // 账户
        3 => forIndex(9),  // 分析
        4 => forIndex(11), // 我的
        _ => forIndex(index),
      };
    }
    return switch (index) {
      0 => success,
      1 => warning,
      2 => info,
      3 => tertiary,
      4 => brand,
      _ => brand,
    };
  }

  // ── 色对 ────────────────────────────────────────────────────
  /// 返回「容器色 + 前景色 + 可选渐变」，容器与前景永远满足 4.5:1。
  ///
  /// 克制档：standard 透明单色 / tonal 淡彩容器 / filled 实色；
  /// 鲜明档：standard 提高饱和但**仍不加容器**（高频功能图标），
  /// tonal / filled 改双色线性渐变，由组件叠加柔和光晕。
  ({Color container, Color foreground, Gradient? gradient}) resolve(
    Color tone,
    AppIconEmphasis emphasis,
  ) {
    return switch (emphasis) {
      AppIconEmphasis.standard => _standardPair(tone),
      AppIconEmphasis.tonal =>
        isVivid ? _vividTonalPair(tone) : _tonalPair(tone),
      AppIconEmphasis.filled =>
        isVivid ? _vividFilledPair(tone) : _filledPair(tone),
    };
  }

  ({Color container, Color foreground, Gradient? gradient}) _standardPair(
    Color tone,
  ) =>
      (
        container: Colors.transparent,
        foreground: ColorMath.ensureContrast(
          isVivid ? _boost(tone) : tone,
          cs.surface,
        ),
        gradient: null,
      );

  ({Color container, Color foreground, Gradient? gradient}) _tonalPair(
    Color tone,
  ) {
    final base = ColorMath.toneFor(tone, brightness);
    final hsl = HSLColor.fromColor(base);
    final container = hsl
        .withLightness(isDark ? 0.24 : 0.90)
        .withSaturation((hsl.saturation * 0.55).clamp(0.25, 0.60))
        .toColor();
    return (
      container: container,
      foreground: ColorMath.ensureContrast(base, container),
      gradient: null,
    );
  }

  ({Color container, Color foreground, Gradient? gradient}) _filledPair(
    Color tone,
  ) {
    final container = ColorMath.toneFor(tone, brightness);
    return (
      container: container,
      foreground: ColorMath.ensureContrast(
        ColorMath.onColorFor(container),
        container,
      ),
      gradient: null,
    );
  }

  /// 渐变两端明度只差 0.08，保证同一个前景色在两端都可读。
  Gradient _gradient(Color a, Color b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[a, b],
      );

  Color _onGradient(Color a, Color b) {
    var fg = ColorMath.onColorFor(a);
    fg = ColorMath.ensureContrast(fg, a);
    return ColorMath.ensureContrast(fg, b);
  }

  ({Color container, Color foreground, Gradient? gradient}) _vividTonalPair(
    Color tone,
  ) {
    final hsl = HSLColor.fromColor(_boost(ColorMath.toneFor(tone, brightness)));
    final a = hsl
        .withSaturation(0.70)
        .withLightness(isDark ? 0.40 : 0.50)
        .toColor();
    final b = hsl
        .withHue((hsl.hue + 20) % 360)
        .withSaturation(0.74)
        .withLightness(isDark ? 0.48 : 0.58)
        .toColor();
    return (
      container: a,
      foreground: _onGradient(a, b),
      gradient: _gradient(a, b),
    );
  }

  ({Color container, Color foreground, Gradient? gradient}) _vividFilledPair(
    Color tone,
  ) {
    final hsl = HSLColor.fromColor(_boost(ColorMath.toneFor(tone, brightness)));
    final a = hsl
        .withSaturation(0.82)
        .withLightness(isDark ? 0.44 : 0.44)
        .toColor();
    final b = hsl
        .withHue((hsl.hue + 26) % 360)
        .withSaturation(0.82)
        .withLightness(isDark ? 0.52 : 0.53)
        .toColor();
    return (
      container: a,
      foreground: _onGradient(a, b),
      gradient: _gradient(a, b),
    );
  }
}
