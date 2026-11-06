import 'package:flutter/material.dart';
import 'package:path/path.dart';
import '../../settings.dart';

/// 对应 styles.css 的 :root 变量与公共样式
class AppStyles {

  // === 间距 / 圆角 ===
  static const double pageHPadding = 16;
  static const double sectionGap = 16;
  static const double cardRadius = 16;
  static const double itemRadius = 12;

  // === 文字样式 ===
  static const TextStyle userNameStyle = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600,
  );
  static const TextStyle userSubStyle = TextStyle(fontSize: 12);
  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
  );
  static const TextStyle menuTextStyle = TextStyle(fontSize: 15);
  static const TextStyle menuSubStyle = TextStyle(fontSize: 12);
  static const TextStyle menuArrowStyle = TextStyle(fontSize: 20);
  static const TextStyle aboutTextStyle = TextStyle(fontSize: 14);

  // === 卡片装饰（对应 .user-card） ===
  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
      boxShadow: [
        BoxShadow(color: Theme
            .of(context)
            .colorScheme
            .surface, offset: const Offset(0, 1), blurRadius: 4),
      ],
    );
  }

  // === 列表项装饰（对应 .menu-item / 账户卡片阴影） ===
  static BoxDecoration itemDecoration(BuildContext context) {
    return BoxDecoration(
      borderRadius: const BorderRadius.all(Radius.circular(itemRadius)),
      boxShadow: [
        BoxShadow(color: Theme
            .of(context)
            .colorScheme
            .surface, offset: const Offset(0, 1), blurRadius: 3),
      ],
    );
  }
}
