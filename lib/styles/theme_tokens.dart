import 'package:flutter/material.dart';

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

/// 圆角尺度：同一层级只用同一档，避免 12/16/20 混用没有规律
abstract final class AppRadius {
  static const double small = 8;
  static const double item = 12;
  static const double card = 16;
  static const double sheet = 20;
  static const double dialog = 28;
}

/// 动效时长（M3 短/中/长）
abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration long = Duration(milliseconds: 300);
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
      // 暗色下容器往上抬一档，避免「深灰卡片压在深灰背景上」没有层次
      card: dark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      field: cs.surfaceContainerHighest,
      sheet: dark ? cs.surfaceContainer : cs.surfaceContainerLow,
      divider: cs.outlineVariant,
      shadow: cs.shadow,
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
