import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// 全软件共用的**容器装饰**工厂。
///
/// 判定标准：只有被 ≥2 个不同组件使用的装饰才允许放在这里。
/// 只属于某个组件的形状（如头像的圆形占位、图片删除角标）必须留在
/// 该组件文件顶部的 `_k*` 私有常量区，不许上提到全局。
///
/// 所有颜色取自 ThemeExtension 与 ColorScheme，切换主题色 / 明暗时
/// 一处重算、全软件同步；阴影透明度、描边宽度、圆角档位也全部走令牌。
abstract final class AppDecorations {
  /// 页面级卡片：surfaceContainer 底色 + 细描边 + 轻阴影（暗色靠色差分层）
  static BoxDecoration card(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    final dark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
        color: t.divider.withValues(
          alpha: dark ? AppOpacity.outlineDark : AppOpacity.outline + 0.1,
        ),
        width: AppBorder.thin,
      ),
      boxShadow: dark
          ? null
          : <BoxShadow>[
              BoxShadow(
                color: t.shadow.withValues(alpha: AppElevation.cardAlpha),
                offset: AppElevation.cardOffset,
                blurRadius: AppElevation.cardBlur,
              ),
            ],
    );
  }

  /// 列表项 / 分区内容：比卡片低半档，只靠底色与描边，不叠阴影
  static BoxDecoration item(BuildContext context) {
    final t = context.tokens;
    return BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(AppRadius.item),
      border: Border.all(
        color: t.divider.withValues(alpha: AppOpacity.outline),
        width: AppBorder.thin,
      ),
    );
  }

  /// 弹层 / BottomSheet 容器
  static BoxDecoration sheet(BuildContext context) {
    final t = context.tokens;
    return BoxDecoration(
      color: t.sheet,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: t.shadow.withValues(alpha: AppElevation.sheetAlpha),
          blurRadius: AppElevation.sheetBlur,
          offset: AppElevation.sheetOffset,
        ),
      ],
    );
  }

  /// 表单输入框容器（M3 filled text field 的容器色）
  static BoxDecoration field(BuildContext context) {
    final t = context.tokens;
    return BoxDecoration(
      color: t.field,
      borderRadius: BorderRadius.circular(AppRadius.item),
      border: Border.all(
        color: t.divider.withValues(alpha: AppOpacity.outline),
        width: AppBorder.thin,
      ),
    );
  }

  /// 图标徽章：语义色低透明底 + 语义色图标，统一全软件图标视觉语言
  static BoxDecoration iconBadge(BuildContext context, Color tone) {
    return BoxDecoration(
      color: tone.withValues(alpha: AppOpacity.disabledContainer),
      borderRadius: BorderRadius.circular(AppRadius.small + 2),
    );
  }

  /// 纯描边（禁用态、空槽位）
  static BoxDecoration outline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.item),
      border: Border.all(
        color: cs.outlineVariant,
        width: AppBorder.thin,
      ),
    );
  }
}
