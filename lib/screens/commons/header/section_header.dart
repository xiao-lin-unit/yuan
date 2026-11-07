import 'package:flutter/material.dart';

import '../styles/app_styles.dart';

/// 公共分组标题（对应 .section-header）
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.pageHPadding,
        18,
        AppStyles.pageHPadding,
        10,
      ),
      child: Row(
        children: [
          Text(title, style: AppStyles.sectionHeaderStyle),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),

    );
  }
}
