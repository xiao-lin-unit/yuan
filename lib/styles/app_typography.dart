import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// 全局排版的**唯一来源**。
///
/// 旧版有两套互相打架的定义：`ThemeSetting.textTheme`（15 档）和
/// `AppStyles.userNameStyle / menuTextStyle / ...`（7 个手写 TextStyle），
/// 字号 12/14/15/17/20 散落各处，行高也不一致。
///
/// 现在：
/// - [textTheme] 负责 Material 组件的 15 档排版（供 ThemeData 使用）；
/// - 下面这些 `const TextStyle` 是**语义角色**（不含颜色），业务组件不许再写
///   `TextStyle(fontSize: ...)`，一律从这里取；
/// - 颜色由 [AppText] 按当前 ColorScheme 注入，用 `context.appText.xxx` 读取。
///
/// 规则：这里只出现「全软件通用」的角色名，不出现任何组件名或页面名。
abstract final class AppTypography {
  // ── 系统字体缩放的夹取范围 ──────────────────────────────────
  /// 为什么需要：Android 14+ / iOS 允许系统把字号放大到 200%~300%，
  /// 而项目里的 48dp 热区、56dp 行高、72dp 底导、640/840 限宽、Sheet
  /// 0.9 屏高全是固定 dp。不夹取会让文字溢出按钮、Sheet 内容被裁。
  ///
  /// 取 0.9~1.3 是「尊重用户设置但不破坏布局」的折中：
  /// 低于 0.9 的小字不再缩小（可读性），高于 1.3 的大字由布局自身
  /// 的滚动/换行承担，而不是无限放大把容器撑爆。
  /// 唯一消费点：lib/app_root.dart 的 MediaQuery 覆盖。
  static const double minTextScaleFactor = 0.9;
  static const double maxTextScaleFactor = 1.3;

  static const TextTheme textTheme = TextTheme(
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
    labelSmall: labelSmall,
  );

  // ── 语义角色（无颜色）─────────────────────────────────────────
  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,
  );
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle userName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle userSub = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle menuTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static const TextStyle menuSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle emptyTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle emptyDescription = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle labelSmall = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.27
  );

  // ── Sheet 语义角色（无颜色，颜色由 SheetText 注入）────────────
  static const TextStyle sheetTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.30,
  );
  static const TextStyle sheetSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.50,
  );
  static const TextStyle sheetCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.40,
  );
  static const TextStyle metricLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );
  static const TextStyle metricValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.20,
  );
  static const TextStyle metricUnit = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.40,
  );
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.40,
  );
  static const TextStyle optionLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.40,
  );
  static const TextStyle confirmTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );
  static const TextStyle confirmBody = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.60,
  );
  static const TextStyle mediaTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.30,
  );
  static const TextStyle mediaSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );
  static const TextStyle categoryLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.40,
  );
  static const TextStyle chipLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.40,
  );
  static const TextStyle trendLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.40,
  );
}

/// 把语义角色配上当前主题的文字色。
///
/// 组件里写 `context.appText.menuSubtitle` 即可，不再到处
/// `AppStyles.menuSubStyle.copyWith(color: cs.onSurfaceVariant)`。
class AppText {
  AppText(this.cs);

  final ColorScheme cs;

  TextStyle get pageTitle =>
      AppTypography.pageTitle.copyWith(color: cs.onSurface);
  TextStyle get sectionHeader =>
      AppTypography.sectionHeader.copyWith(color: cs.onSurface);
  TextStyle get userName =>
      AppTypography.userName.copyWith(color: cs.onSurface);
  TextStyle get userSub =>
      AppTypography.userSub.copyWith(color: cs.onSurfaceVariant);
  TextStyle get menuTitle =>
      AppTypography.menuTitle.copyWith(color: cs.onSurface);
  TextStyle get menuSubtitle =>
      AppTypography.menuSubtitle.copyWith(color: cs.onSurfaceVariant);
  TextStyle get body =>
      AppTypography.body.copyWith(color: cs.onSurface);
  TextStyle get caption =>
      AppTypography.caption.copyWith(color: cs.onSurfaceVariant);
  TextStyle get emptyTitle =>
      AppTypography.emptyTitle.copyWith(color: cs.onSurface);
  TextStyle get emptyDescription =>
      AppTypography.emptyDescription.copyWith(color: cs.onSurfaceVariant);
  TextStyle get hint => AppTypography.body.copyWith(
        color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.hint),
      );
  TextStyle get disabled => AppTypography.body.copyWith(
        color: cs.onSurface.withValues(alpha: AppOpacity.disabled),
      );
  TextStyle get onPrimary =>
      AppTypography.body.copyWith(color: cs.onPrimary);
}

extension AppTextX on BuildContext {
  AppText get appText => AppText(Theme.of(this).colorScheme);
}
