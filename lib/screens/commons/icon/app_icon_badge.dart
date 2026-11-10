import 'package:flutter/material.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_icon_tone.dart';
import '../../../styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kBadgeSize = 40;

/// 全软件统一的图标徽章。
///
/// 美术意图：把「彩色 emoji」换成矢量图标；这一轮再把「12% 淡雾 +
/// 同色单线图标」升级成 **duotone**（容器一个色阶、图标一个色阶），
/// 让图标在列表 / 空状态 / 分区标题里真正有视觉重量。
///
/// 颜色不由调用方决定：[tone] 只接受语义色或省略；色对由
/// [AppIconTone.resolve] 按 [emphasis] 计算，全部来自当前主题的
/// ColorScheme / AppThemeTokens，且校验过 4.5:1 对比度。
/// 因此换主题色或切明暗时，所有徽章自动重算，业务层零改动。
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.tone,
    this.size = _kBadgeSize,
    this.iconSize,
    this.emphasis = AppIconEmphasis.tonal,
    this.toneKey,
  });

  final IconData icon;

  /// 显式语义色（优先级最高）。一般不用传，留给 [toneKey] / 自动派生。
  final Color? tone;

  /// 语义标识，走 [AppIconTone.forMenuKey] 的全局映射。
  final String? toneKey;

  final double size;
  final double? iconSize;

  /// 默认 tonal（中频锚点）；空状态、确认弹层这类稀疏锚点用 filled。
  final AppIconEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final iconTone = AppIconTone.of(context);
    final base = tone ??
        (toneKey != null
            ? iconTone.forMenuKey(toneKey)
            : iconTone.forIcon(icon));
    final pair = iconTone.resolve(base, emphasis);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: AppDecorations.iconBadge(context, pair.container),
        child: Icon(
          icon,
          size: iconSize ?? AppIconSize.badge,
          color: pair.foreground,
        ),
      ),
    );
  }
}
