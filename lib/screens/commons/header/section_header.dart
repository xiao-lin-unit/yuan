import 'package:flutter/material.dart';
import 'package:yuan/styles/theme_tokens.dart';

import '../styles/app_styles.dart';

/// 公共分组标题
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.pageHPadding,
        18,
        AppStyles.pageHPadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppStyles.sectionHeaderStyle.copyWith(color: cs.onSurface),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            IconTheme(
              data: IconThemeData(size: 18, color: cs.onSurfaceVariant),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
