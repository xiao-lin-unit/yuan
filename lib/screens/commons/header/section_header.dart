import 'package:flutter/material.dart';

import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kTrailingGap = 6;
const double _kTrailingIconSize = 18;

/// 公共分组标题：统一所有分区的上下留白与文字层级。
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppLayout.sectionHeaderTop,
        AppSpacing.md,
        AppLayout.sectionHeaderBottom,
      ),
      child: Row(
        children: [
          Text(title, style: context.appText.sectionHeader),
          if (trailing != null) ...[
            const SizedBox(width: _kTrailingGap),
            IconTheme(
              data: IconThemeData(
                size: _kTrailingIconSize,
                color: cs.onSurfaceVariant,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
