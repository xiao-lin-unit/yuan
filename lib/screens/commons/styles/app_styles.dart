import 'package:flutter/material.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 对应 styles.css 的 :root 变量与公共样式。
///
/// 旧版卡片装饰只有 `BoxShadow(color: colorScheme.surface)`：
/// 阴影颜色等于页面背景色，等于没有阴影；而且没给 color，卡片本体是透明的，
/// 于是「卡片」和页面底色完全一样，层次全丢。现在按 M3 的
/// surface container 分级给底色 + 细描边 + 极轻的真实阴影。
class AppStyles {
  AppStyles._();

  // === 间距 / 圆角（与全局 token 对齐）===
  static const double pageHPadding = AppSpacing.md;
  static const double sectionGap = AppSpacing.md;
  static const double cardRadius = AppRadius.card;
  static const double itemRadius = AppRadius.item;

  // === 文字排版（不写 color，交给 DefaultTextStyle 继承主题色）===
  static const TextStyle userNameStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle userSubStyle = TextStyle(
    fontSize: 12,
    height: 1.4,
  );
  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle menuTextStyle = TextStyle(
    fontSize: 15,
    height: 1.4,
  );
  static const TextStyle menuSubStyle = TextStyle(
    fontSize: 12,
    height: 1.4,
  );
  static const TextStyle menuArrowStyle = TextStyle(fontSize: 20);
  static const TextStyle aboutTextStyle = TextStyle(fontSize: 14, height: 1.4);

  /// 卡片：surfaceContainer 底色 + outlineVariant 细描边 + 轻阴影。
  /// 暗色下阴影几乎看不见，层次主要靠底色与描边（M3 tonal elevation）。
  static BoxDecoration cardDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    final dark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      color: t.card,
      borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
      border: Border.all(
        color: t.divider.withValues(alpha: dark ? 0.35 : 0.6),
        width: 1,
      ),
      boxShadow: dark
          ? null
          : <BoxShadow>[
              BoxShadow(
                color: t.shadow.withValues(alpha: 0.08),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
    );
  }

  /// 列表项：比卡片低半档，避免整页都是同色块
  static BoxDecoration itemDecoration(BuildContext context) {
    final t = context.tokens;
    return BoxDecoration(
      color: t.card,
      borderRadius: const BorderRadius.all(Radius.circular(itemRadius)),
      border: Border.all(
        color: t.divider.withValues(alpha: 0.5),
        width: 1,
      ),
    );
  }
}
