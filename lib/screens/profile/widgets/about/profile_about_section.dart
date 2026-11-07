import 'package:flutter/material.dart';
import '../../../commons/header/section_header.dart';
import '../../../commons/styles/app_styles.dart';
import '../../../commons/icons/app_icons.dart';

/// ④ 关于分区（对应 .about-list）
class ProfileAboutSection extends StatelessWidget {
  final String version;
  final VoidCallback? onAboutTap;

  const ProfileAboutSection({super.key, this.version = '版本 1.0.0', this.onAboutTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '关于', trailing: Icon(
          AppIcons.about,
        )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppStyles.pageHPadding),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: AppStyles.itemDecoration(context),
            child: Column(
              children: [
                const _AboutRow(text: '版本 1.0.0'),
                _AboutRow(text: '关于本软件', onTap: onAboutTap),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _AboutRow({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(text, style: AppStyles.aboutTextStyle),
      ),
    );
  }
}
