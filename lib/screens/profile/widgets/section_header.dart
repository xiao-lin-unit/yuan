import 'package:flutter/material.dart';
import 'profile_styles.dart';

/// 公共分组标题（对应 .section-header）
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileStyles.pageHPadding, 18, ProfileStyles.pageHPadding, 10,
      ),
      child: Text(title, style: ProfileStyles.sectionHeaderStyle),
    );
  }
}
