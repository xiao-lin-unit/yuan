import 'package:flutter/material.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_icon_tone.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kTrailingGap = 6;
const double _kTrailingIconSize = 18;
const double _kTrailingBadgeSize = 28;

/// 公共分组标题：统一所有分区的上下留白与文字层级。
///
/// 尾图标以前固定 `onSurfaceVariant` 灰，是「素」的来源之一。
/// - 克制档：换成语义色单色图标（standard 档，不铺底）；
/// - 鲜明档：换成 28dp 彩色渐变圆底 + 自动反色图标，与菜单徽章
///   同一套色对，三个分区标题各得一色。
/// 色值全部从 ColorScheme / AppThemeTokens 派生，换主题自动重算。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.toneKey,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget? trailing;

  /// 右侧文字动作（功能页的「显示已隐藏」「全部 ›」等）。
  /// 与 [trailing] 图标可并存；两者都不传时就是纯标题行。
  /// 这是构造期传入的静态数据，组件不持有任何状态。
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 可选语义标识；不传时按 [title] 自动映射。
  final String? toneKey;

  @override
  Widget build(BuildContext context) {
    final iconTone = AppIconTone.of(context);
    final base = toneKey != null
        ? iconTone.forMenuKey(toneKey)
        : iconTone.forSectionTitle(title);
    final emphasis = iconTone.isVivid
        ? AppIconEmphasis.tonal
        : AppIconEmphasis.standard;
    final pair = iconTone.resolve(base, emphasis);

    Widget? trailingWidget;
    if (trailing != null) {
      final Widget iconWidget = IconTheme(
        data: IconThemeData(
          size: _kTrailingIconSize,
          color: pair.foreground,
        ),
        child: trailing!,
      );
      trailingWidget = iconTone.isVivid
          ? Container(
              width: _kTrailingBadgeSize,
              height: _kTrailingBadgeSize,
              alignment: Alignment.center,
              decoration: AppDecorations.iconBadge(
                context,
                pair.container,
                gradient: pair.gradient,
              ),
              child: iconWidget,
            )
          : iconWidget;
    }

    Widget? actionWidget;
    if (actionLabel != null && onAction != null) {
      actionWidget = TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
        child: Text(
          actionLabel!,
          style: context.appText.menuSubtitle.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

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
          if (trailingWidget != null) ...[
            const SizedBox(width: _kTrailingGap),
            trailingWidget,
          ],
          if (actionWidget != null)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: actionWidget,
              ),
            ),
        ],
      ),
    );
  }
}
