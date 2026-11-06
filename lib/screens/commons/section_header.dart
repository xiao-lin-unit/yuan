import 'package:flutter/material.dart';
import 'app_styles.dart';

/// 公共分组标题（对应 .section-header）
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.pageHPadding, 18, AppStyles.pageHPadding, 10,
      ),
      child: Text(title, style: AppStyles.sectionHeaderStyle),
    );
  }
}
