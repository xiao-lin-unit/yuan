import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 主题颜色的「计算」层。
///
/// 以前换主题色只是把 8 个硬编码常量塞进 `ColorScheme.fromSeed`，
/// 没有对比度校验、没有语义色和谐化、没有亮暗色调适配。
/// 这里把颜色运算集中成纯函数，供 AppTheme / AppThemeTokens 调用。
class ColorMath {
  ColorMath._();

  /// sRGB 相对亮度（WCAG 2.1 定义）。用 toARGB32() 取通道，
  /// 避免新旧 Flutter 里 Color.r / Color.red 类型不一致。
  static double relativeLuminance(Color color) {
    final argb = color.toARGB32();
    double linearize(int v) {
      final c = v / 255.0;
      return c <= 0.04045
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize((argb >> 16) & 0xFF);
    final g = linearize((argb >> 8) & 0xFF);
    final b = linearize(argb & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 对比度比值，范围 1..21
  static double contrastRatio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 给定背景，选黑或白作为前景，保证至少 4.5:1（WCAG AA 正文）。
  static Color onColorFor(Color background) {
    return contrastRatio(Colors.white, background) >=
            contrastRatio(Colors.black, background)
        ? Colors.white
        : Colors.black;
  }

  /// 前景不达标时，朝 [onColorFor] 插值到刚好达标，避免直接用纯黑/纯白太生硬。
  static Color ensureContrast(
    Color foreground,
    Color background, {
    double minimum = 4.5,
  }) {
    if (contrastRatio(foreground, background) >= minimum) return foreground;
    final target = onColorFor(background);
    for (var t = 0.05; t <= 1.0; t += 0.05) {
      final candidate = Color.lerp(foreground, target, t) ?? target;
      if (contrastRatio(candidate, background) >= minimum) return candidate;
    }
    return target;
  }

  /// M3 风格的颜色和谐化：把 design 色相朝 seed 色相旋转，最多 [maxDegrees]。
  /// HCT 需要额外依赖，这里用 HSL 做工程近似，效果一致且零依赖。
  static Color harmonize(Color design, Color seed, {double maxDegrees = 15}) {
    final d = HSLColor.fromColor(design);
    final s = HSLColor.fromColor(seed);
    // 无彩色（灰/黑/白）没有色相，不参与和谐化
    if (d.saturation < 0.05 || s.saturation < 0.05) return design;

    final diff = ((s.hue - d.hue + 540) % 360) - 180; // -180..180
    if (diff.abs() <= maxDegrees) return design;
    final shifted = (d.hue + (diff > 0 ? maxDegrees : -maxDegrees)) % 360;
    return d.withHue(shifted).toColor();
  }

  /// 语义色按明暗取不同明度：亮色用深 tone 配白字，暗色用浅 tone 配黑字。
  static Color toneFor(Color base, Brightness brightness) {
    final hsl = HSLColor.fromColor(base);
    final target = brightness == Brightness.dark ? 0.72 : 0.38;
    return hsl.withLightness(target).toColor();
  }

  /// 高对比度档位（0 标准 / 1 中 / 2 高）。
  /// 不重算整个色板，只把文字与描边往 onSurface 拉近。
  static ColorScheme boostContrast(ColorScheme scheme, double level) {
    if (level <= 0) return scheme;
    final t = (level / 2.0).clamp(0.0, 1.0).toDouble();

    Color pull(Color from, Color to, double amount) =>
        Color.lerp(from, to, t * amount) ?? from;

    final extreme = scheme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return scheme.copyWith(
      onSurface: pull(scheme.onSurface, extreme, 0.75),
      onSurfaceVariant: pull(scheme.onSurfaceVariant, scheme.onSurface, 0.6),
      outline: pull(scheme.outline, scheme.onSurface, 0.6),
      outlineVariant: pull(scheme.outlineVariant, scheme.onSurface, 0.4),
    );
  }
}
