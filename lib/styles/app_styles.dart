import 'package:flutter/material.dart';

import 'app_decorations.dart';
import 'app_typography.dart';
import 'theme_tokens.dart';

/// 全局样式门面（唯一允许业务层直接引用的样式入口）。
///
/// 它自己不定义任何数值：间距/圆角来自 [AppSpacing] / [AppRadius]，
/// 文字来自 [AppTypography]，容器来自 [AppDecorations]。
/// 这样「改一个圆角」只需动令牌表一处，全软件同步。
///
/// ⚠️ 分层约定
/// - `lib/styles/*`：**通用样式**，跨组件复用，禁止出现组件名/页面名；
/// - 组件文件顶部的 `_k*` 常量：**组件私有样式**，只服务该文件，
///   且只允许引用令牌或 ColorScheme，不许写死颜色与网格外数值；
/// - 组件 build 里：不许出现裸的 `fontSize:` / `Color(0xFF...)` /
///   `BorderRadius.circular(魔法数)` / `EdgeInsets.all(魔法数)`。
abstract final class AppStyles {
  // ── 间距 / 圆角（全局令牌别名）──────────────────────────────
  static const double pageHPadding = AppSpacing.md;
  static const double sectionGap = AppSpacing.md;
  static const double cardRadius = AppRadius.card;
  static const double itemRadius = AppRadius.item;

  // ── 语义文字角色（无颜色，需要颜色请用 context.appText.xxx）──
  static const TextStyle userNameStyle = AppTypography.userName;
  static const TextStyle userSubStyle = AppTypography.userSub;
  static const TextStyle sectionHeaderStyle = AppTypography.sectionHeader;
  static const TextStyle menuTextStyle = AppTypography.menuTitle;
  static const TextStyle menuSubStyle = AppTypography.menuSubtitle;
  static const TextStyle aboutTextStyle = AppTypography.body;

  // ── 容器装饰 ────────────────────────────────────────────────
  static BoxDecoration cardDecoration(BuildContext context) =>
      AppDecorations.card(context);

  static BoxDecoration itemDecoration(BuildContext context) =>
      AppDecorations.item(context);

  static BoxDecoration sheetDecoration(BuildContext context) =>
      AppDecorations.sheet(context);

  static BoxDecoration fieldDecoration(BuildContext context) =>
      AppDecorations.field(context);
}
