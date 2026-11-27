import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../styles/theme_tokens.dart';
import '../icons/app_icons.dart';

/// 口径 / 提示文案的**点开式**弹框。
///
/// 项目里以前把解释性说明整段常驻在数字下方、卡片底部或提示条里，
/// 既占版面又让「主角数字」和「说明」挤在同一层。现在统一收进这个小
/// ⓘ：桌面 hover / 长按走 Tooltip，点击走一个中性的小弹框。
Future<void> showInfoTipDialog(
  BuildContext context, {
  String? title,
  required String message,
}) =>
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        // 不显式写 TextStyle：AlertDialog 的背景 / 圆角 / 标题 / 正文 /
        // 按钮样式全部由全局 dialogTheme 接管，切主题自动跟随。
        return AlertDialog(
          title: title == null ? null : Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );

/// 紧跟在 label 旁的小 ⓘ 图标。
///
/// 视觉上只有 [size]（默认 14dp）一圈淡灰线，不抢文字；点击热区扩到
/// 28dp，保证手指点得到。`emphasized` 之类的强调形态刻意不做 —— 参考
/// 页面里这些图标全都同色同大小，提示不该变成视觉焦点。
class AppInfoTip extends StatelessWidget {
  const AppInfoTip({
    super.key,
    required this.message,
    this.title,
    this.size = AppIconSize.small,
  });

  /// 点开后展示的完整说明。
  final String message;

  /// 弹框标题；不传就只显示正文。
  final String? title;

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: message,
      child: IconButton(
        // 不传 IconButton 自带的 tooltip：外层 Tooltip 已经负责 hover /
        // 长按，重复包一层会出现两个浮层。
        icon: Icon(AppIcons.about, size: size, color: cs.onSurfaceVariant),
        onPressed: () => unawaited(
          showInfoTipDialog(context, title: title, message: message),
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
      ),
    );
  }
}
