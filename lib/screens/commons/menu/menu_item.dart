import 'package:flutter/material.dart';
import 'package:yuan/styles/theme_tokens.dart';

import '../styles/app_styles.dart';

/// 列表项数据模型：新增功能只需在分区组件的数据数组里加一条
class MenuItemData {
  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? key;

  const MenuItemData({
    required this.emoji,
    required this.title,
    this.subtitle,
    this.onTap,
    this.key,
  });
}

/// 公共单项组件：emoji + 标题 + 副标题 + 箭头
class MenuItem extends StatelessWidget {
  final MenuItemData data;

  const MenuItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppStyles.itemRadius),
          onTap: data.onTap,
          child: Container(
            // 最小 56dp 高：点击热区达标，视觉也更舒展
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: AppStyles.itemDecoration(context),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(data.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: AppStyles.menuTextStyle.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      if (data.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          data.subtitle!,
                          style: AppStyles.menuSubStyle.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
