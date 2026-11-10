import 'package:flutter/material.dart';

import '../../../../styles/app_decorations.dart';
import '../../../../styles/app_typography.dart';
import '../../../../styles/theme_tokens.dart';
import '../../../commons/header/section_header.dart';
import '../../../commons/icons/app_icons.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kRowHorizontalPadding = AppSpacing.sm;
const double _kRowVerticalPadding = AppSpacing.sm;
const double _kChevronSize = AppIconSize.medium;
const String _kSectionTitle = '关于';

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
          title: _kSectionTitle,
          trailing: Icon(AppIcons.about),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Container(
            width: double.infinity,
            decoration: AppDecorations.item(context),
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
    final appText = context.appText;
    final tokens = context.tokens;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: _kRowHorizontalPadding,
              vertical: _kRowVerticalPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: onTap == null ? appText.caption : appText.body,
                  ),
                ),
                if (onTap != null)
                  Icon(
                    AppIcons.chevronRight,
                    size: _kChevronSize,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
        Divider(
          color: tokens.divider,
          height: AppBorder.thin,
          thickness: AppBorder.thin,
        ),
      ],
    );
  }
}
