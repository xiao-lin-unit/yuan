import 'package:flutter/material.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kBadgeSize = 40;

/// 全软件统一的图标徽章。
///
/// 美术意图：把「彩色 emoji」换成「语义色低透明底 + 矢量图标」，
/// 让图标尺寸、色相、圆角受主题控制，跨平台字形一致；
/// 同时给列表、空状态、分区标题一个可复用的视觉锚点。
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? tone;
  final double size;
  final double? iconSize;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.tone,
    this.size = _kBadgeSize,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tone ?? cs.primary;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: AppDecorations.iconBadge(context, color),
        child: Icon(
          icon,
          size: iconSize ?? AppIconSize.badge,
          color: color,
        ),
      ),
    );
  }
}
