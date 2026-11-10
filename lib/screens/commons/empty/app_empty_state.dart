import 'package:flutter/material.dart';

import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../icon/app_icon_badge.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kIllustrationSize = 64;
const double _kContentMaxWidth = 280;

/// 全软件统一的空状态 / 占位态。
///
/// 旧版四个功能页都是 `Center(child: Text('xx（待实现）'))`，
/// 没有图标、没有层级、没有说明，页面之间字号还各不相同。
/// 现在所有空页面共用同一套视觉节奏：图标徽章 → 标题 → 说明 → 可选操作。
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconBadge(
                icon: icon,
                tone: tone,
                size: _kIllustrationSize,
                iconSize: AppIconSize.empty,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.emptyTitle,
              ),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: text.emptyDescription,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
