import 'package:flutter/material.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_icon_tone.dart';
import '../../../styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kBadgeSize = 40;

/// 全软件统一的图标徽章。
///
/// 鲜明档：容器改双色渐变（由 [AppIconTone] 从当前主题派生），
/// filled 锚点叠加柔和光晕；克制档自动退回淡彩 / 实色容器。
/// 浓度只由全局开关决定，调用方不感知。
///
/// 颜色不由业务决定：[tone] / [toneKey] / [index] 都只是语义输入，
/// 色对与渐变由全局层计算并校验 4.5:1，换主题色或切明暗自动重算。
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.tone,
    this.size = _kBadgeSize,
    this.iconSize,
    this.emphasis = AppIconEmphasis.tonal,
    this.toneKey,
    this.index = 0,
  });

  final IconData icon;

  /// 显式语义色（优先级最高）。一般省略，交给 toneKey / 自动派生。
  final Color? tone;

  /// 语义标识，走 [AppIconTone.forMenuKey] 的全局映射。
  final String? toneKey;

  /// 列表序号：鲜明档下无显式语义的项按它铺 12 色相环。
  final int index;

  final double size;
  final double? iconSize;

  /// 默认 tonal（中频锚点）；空状态、确认弹层用 filled。
  final AppIconEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final iconTone = AppIconTone.of(context);
    final base = tone ??
        (toneKey != null
            ? iconTone.forMenuKey(toneKey, index: index)
            : iconTone.forIcon(icon));
    final pair = iconTone.resolve(base, emphasis);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: AppDecorations.iconBadge(
          context,
          pair.container,
          gradient: pair.gradient,
          glow: iconTone.isVivid && emphasis != AppIconEmphasis.standard,
        ),
        child: Icon(
          icon,
          size: iconSize ?? AppIconSize.badge,
          color: pair.foreground,
        ),
      ),
    );
  }
}
