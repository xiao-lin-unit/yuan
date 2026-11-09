import 'package:flutter/material.dart';
import 'package:yuan/styles/theme_tokens.dart';

import '../../../commons/header/section_header.dart';
import '../../../commons/styles/app_styles.dart';
import '../../../commons/icons/app_icons.dart';

/// ④ 关于分区
class ProfileAboutSection extends StatelessWidget {
  final String version;
  final VoidCallback? onAboutTap;

  const ProfileAboutSection({
    super.key,
    this.version = '版本 1.0.0',
    this.onAboutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '关于',
          trailing: Icon(AppIcons.about),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppStyles.pageHPadding),
          child: Container(
            width: double.infinity,
            decoration: AppStyles.itemDecoration(context),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _AboutRow(text: version),
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
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: AppStyles.aboutTextStyle.copyWith(
                      color: onTap == null
                          ? cs.onSurfaceVariant
                          : cs.onSurface,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
        Divider(color: t.divider, height: 1, thickness: 1),
      ],
    );
  }
}
