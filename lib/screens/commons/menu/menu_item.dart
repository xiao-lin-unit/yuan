import 'package:flutter/material.dart';
import '../icons/app_icons.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_styles.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../icon/app_icon_badge.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kEmojiSize = 22;
const double _kChevronSize = 20;
const double _kIconBoxWidth = 40;
const double _kSubtitleGap = 2;

/// 列表项数据模型：新增功能只需在分区组件的数据数组里加一条。
///
/// [icon] 优先于 [emoji]：矢量图标受主题色与尺寸令牌控制，跨平台一致；
/// emoji 仅作为兼容回退保留，等所有分区补齐 icon 后可移除该字段。
class MenuItemData {
  final String? emoji;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? key;

  const MenuItemData({
    this.emoji,
    this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.key,
  });
}

/// 公共单项组件：图标徽章 + 标题 + 副标题 + 箭头。
/// 容器装饰、文字角色、间距、热区全部取自全局样式层。
class MenuItem extends StatelessWidget {
  final MenuItemData data;

  const MenuItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.appText;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppStyles.itemRadius),
          onTap: data.onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppLayout.listItemMinHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: AppDecorations.item(context),
            child: Row(
              children: [
                SizedBox(
                  width: _kIconBoxWidth,
                  child: data.icon != null
                      ? AppIconBadge(
                          icon: data.icon!,
                          // key 是业务语义标识（knowledge / export / trash…），
                          // 颜色由全局 AppIconTone 映射，业务层不用传 Color。
                          toneKey: data.key,
                        )
                      : Text(
                          data.emoji ?? '',
                          style: const TextStyle(fontSize: _kEmojiSize),
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.title, style: text.menuTitle),
                      if (data.subtitle != null) ...[
                        const SizedBox(height: _kSubtitleGap),
                        Text(data.subtitle!, style: text.menuSubtitle),
                      ],
                    ],
                  ),
                ),
                Icon(
                  AppIcons.chevronRight,
                  size: _kChevronSize,
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
