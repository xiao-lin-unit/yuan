import 'package:flutter/material.dart';

import '../../../styles/app_icon_tone.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/sheet_tokens.dart';
import '../../../styles/theme_tokens.dart';
import '../icon/app_icon_badge.dart';
import '../state/app_state_frame.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
/// 空状态特有的徽章尺寸。居中/限宽/节奏已上提到 [AppStateFrame]，
/// 与 loading / error 两态共用，本文件不再重复定义。
const double _kIllustrationSize = AppSheetSize.iconBadgeSize;

/// 全软件统一的空状态 / 占位态。
///
/// 旧版四个功能页都是 `Center(child: Text('xx（待实现）'))`，
/// 没有图标、没有层级、没有说明，页面之间字号还各不相同。
/// 现在所有空页面共用同一套视觉节奏：图标徽章 → 标题 → 说明 → 可选操作。
/// 徽章用 filled 档（M3 里 sparingly 的最高强调档），鲜明档下是
/// 72dp 渐变实色 + 光晕，是全页唯一的彩色锚点；其余 16–24px
/// 功能图标保持单色，避免彩色铺满变成噪声。
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final Color? tone;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.appText;
    return AppStateFrame(
      children: <Widget>[
        AppIconBadge(
          icon: icon,
          tone: tone,
          // 空状态是整页唯一的视觉锚点，用 filled 实色 + 自动反色前景。
          // 不传 tone 时按图标数据稳定派生色相，四个占位页各得一色，
          // 且随主题色 / 明暗自动重算，业务层不用决定用什么颜色。
          emphasis: AppIconEmphasis.filled,
          size: _kIllustrationSize,
          iconSize: AppIconSize.empty,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.emptyTitle,
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: text.emptyDescription,
          ),
        ],
        if (action != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          action!,
        ],
      ],
    );
  }
}
