import 'package:flutter/material.dart';

/// 对应 styles.css 的 :root 变量与公共样式
class AppStyles {
  // === 颜色（对应 :root） ===
  static const Color bg = Color(0xFFF2F3F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF2E9D6F);
  static const Color primaryDark = Color(0xFF1F7D58);
  static const Color red = Color(0xFFE5484D);
  static const Color green = Color(0xFF2E9D6F);
  static const Color orange = Color(0xFFF5A623);
  static const Color text = Color(0xFF1C1C1E);
  static const Color textSub = Color(0xFF8E8E93);
  static const Color border = Color(0xFFE5E5EA);
  static const Color shadow = Color(0x14000000); // rgba(0,0,0,0.08)

  // === 间距 / 圆角 ===
  static const double pageHPadding = 16;
  static const double sectionGap = 16;
  static const double cardRadius = 16;
  static const double itemRadius = 12;

  // === 文字样式 ===
  static const TextStyle userNameStyle = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, color: text,
  );
  static const TextStyle userSubStyle = TextStyle(fontSize: 12, color: textSub);
  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600, color: text,
  );
  static const TextStyle menuTextStyle = TextStyle(fontSize: 15, color: text);
  static const TextStyle menuSubStyle = TextStyle(fontSize: 12, color: textSub);
  static const TextStyle menuArrowStyle = TextStyle(fontSize: 20, color: textSub);
  static const TextStyle aboutTextStyle = TextStyle(fontSize: 14, color: textSub);

  // === 卡片装饰（对应 .user-card） ===
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: white,
        borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
        boxShadow: const [
          BoxShadow(color: shadow, offset: Offset(0, 1), blurRadius: 4),
        ],
      );

  // === 列表项装饰（对应 .menu-item / 账户卡片阴影） ===
  static BoxDecoration get itemDecoration => BoxDecoration(
        color: white,
        borderRadius: const BorderRadius.all(Radius.circular(itemRadius)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 3),
        ],
      );
}
