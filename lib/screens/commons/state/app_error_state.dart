import 'package:flutter/material.dart';

import '../../../styles/app_typography.dart';
import '../../../styles/sheet_tokens.dart';
import '../../../styles/theme_tokens.dart';
import '../icon/app_icon_badge.dart';
import '../icons/app_icons.dart';
import 'app_state_frame.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kIllustrationSize = AppSheetSize.iconBadgeSize;

/// 全软件统一的**错误态**。
///
/// 与 [AppEmptyState] / [AppLoadingState] 共用 [AppStateFrame]，
/// 结构同为「徽章 → 标题 → 说明 → 可选操作」，所以三态切换时
/// 位置、留白、列宽都不跳动。
///
/// 徽章用 filled 档并把 `colorScheme.error` 作为语义色传入：
/// 错误态必须是红的，这个红来自当前主题（换主题色 / 切明暗自动重算），
/// 不写死 hex；其余 16–24px 功能图标仍保持单色。
///
/// ── 静态优先 ───────────────────────────────────────────────────
/// 无状态、无 Future、无监听。它只负责「画一个错误态」；
/// 错误从哪来、重试做什么、什么时候切回内容，全部由使用方决定。
/// [details] 是给开发看原始错误信息的入口，生产环境传 null 即可，
/// 组件不会自己去捕获或格式化异常。
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    this.description,
    this.details,
    this.icon = AppIcons.error,
    this.retryLabel = '重试',
    this.onRetry,
  });

  final String title;
  final String? description;

  /// 原始错误详情（开发排查用）。最多显示 3 行，超出省略。
  final String? details;

  final IconData icon;
  final String retryLabel;

  /// 非空时渲染「重试」按钮；为 null 时错误态就是纯说明。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = context.appText;
    final cs = Theme.of(context).colorScheme;
    return AppStateFrame(
      children: <Widget>[
        AppIconBadge(
          icon: icon,
          tone: cs.error,
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
        if (details != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            details!,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.caption,
          ),
        ],
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ],
    );
  }
}
