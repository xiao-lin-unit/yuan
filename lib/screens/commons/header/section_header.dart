import 'package:flutter/material.dart';

import '../../../styles/app_icon_tone.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kTrailingGap = 6;
const double _kTrailingIconSize = 18;

/// 公共分组标题：统一所有分区的上下留白与文字层级。
///
/// 尾图标以前固定 `onSurfaceVariant` 灰，是「素」的来源之一。
/// 现在按标题走全局语义映射（关于=信息蓝 / 管理=第三色 / 功能=主色），
/// 颜色取自 ColorScheme 与 AppThemeTokens，换主题自动重算；
/// 保留 [toneKey] 作为显式覆盖，业务侧默认零改动。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.toneKey,
  });

  final String title;
  final Widget? trailing;

  /// 可选语义标识；不传时按 [title] 自动映射。
  final String? toneKey;

  @override
  Widget build(BuildContext context) {
    final iconTone = AppIconTone.of(context);
    final base = toneKey != null
        ? iconTone.forMenuKey(toneKey)
        : iconTone.forSectionTitle(title);
    // 尾图标属于 16–20px 高频功能图标，用 standard 档（单色不铺底），
    // 只把灰色换成语义色，避免一屏内出现过多彩色块。
    final foreground = iconTone
        .resolve(base, AppIconEmphasis.standard)
        .foreground;

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
          if (trailing != null) ...[
            const SizedBox(width: _kTrailingGap),
            IconTheme(
              data: IconThemeData(
                size: _kTrailingIconSize,
                color: foreground,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
