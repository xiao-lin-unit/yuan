import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有常量（只服务本文件；尺寸仍引用全局令牌）────────────
const double _kHeaderTrailingMinWidth = kMinTapTarget;
const double _kCaptionGap = AppSpacing.xs;
const double _kChangePillHeight = 32;
const double _kChangePillHPadding = 12;
const double _kCloseButtonSize = 40;

/// 顶部拖拽把手：36×4 圆角短条。
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    return Center(
      child: Container(
        width: AppSheetSize.grabberWidth,
        height: AppSheetSize.grabberHeight,
        decoration: BoxDecoration(
          color: p.grabberColor,
          borderRadius: BorderRadius.circular(AppSheetRadius.grabber),
        ),
      ),
    );
  }
}

/// 底部 home indicator：108×4 圆角条（原型里每张 sheet 都有）。
class SheetHomeIndicator extends StatelessWidget {
  const SheetHomeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    return Center(
      child: Container(
        width: AppSheetSize.homeIndicatorWidth,
        height: AppSheetSize.homeIndicatorHeight,
        decoration: BoxDecoration(
          color: p.homeIndicatorColor,
          borderRadius: BorderRadius.circular(AppSheetRadius.grabber),
        ),
      ),
    );
  }
}

/// 统一标题栏。
///
/// [centered] = true → 三栏（取消 / 标题 / 保存），标题真居中；
/// false → 标题与副标题靠左，右侧可放「详情」「关闭」等动作。
/// 两种形态在 6 张原型里都出现过，用同一个组件避免各写一套 Row。
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final text = SheetText.of(context);
    final titleWidget = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: text.title,
    );
    final subtitleWidget = subtitle == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              subtitle!,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: text.subtitle,
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null) leading!,
        Expanded(
          child: Column(
            crossAxisAlignment:
                centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              titleWidget,
              if (subtitleWidget != null) subtitleWidget,
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (centered)
          const SizedBox(width: _kHeaderTrailingMinWidth),
      ],
    );
  }
}

/// 圆形语义图标徽章（确认弹层顶部那个圆）。
class SheetIconBadge extends StatelessWidget {
  const SheetIconBadge({
    super.key,
    required this.icon,
    required this.tone,
    this.size = AppSheetSize.iconBadgeSize,
  });

  final IconData icon;
  final Color tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: AppOpacity.disabledContainer),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: AppSheetSize.iconBadgeIconSize,
        color: tone,
      ),
    );
  }
}

/// 按语义类型取徽章 / 危险按钮的底色。
Color sheetIntentTone(SheetPalette p, SheetIntent intent) {
  switch (intent) {
    case SheetIntent.danger:
      return p.tokens.expense;
    case SheetIntent.warning:
      return p.tokens.warning;
    case SheetIntent.success:
      return p.tokens.income;
    case SheetIntent.neutral:
      return p.cs.primary;
  }
}

/// 「较上周 +12%」这类趋势胶囊：浅紫底 + 主色文字。
class SheetChangePill extends StatelessWidget {
  const SheetChangePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    return Container(
      height: _kChangePillHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: _kChangePillHPadding,
      ),
      decoration: BoxDecoration(
        color: p.selectedTint,
        borderRadius: BorderRadius.circular(AppSheetRadius.pill),
        border: Border.all(
          color: p.cs.primary.withValues(alpha: AppOpacity.outline),
          width: AppBorder.thin,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: SheetText.of(context).chipLabelSelected,
      ),
    );
  }
}

/// 小灰字注释（「数据更新于今日 09:30」「此操作不可撤销」）。
class SheetCaption extends StatelessWidget {
  const SheetCaption({
    super.key,
    required this.text,
    this.centered = false,
    this.align = TextAlign.start,
  });

  final String text;
  final bool centered;

  /// 显式对齐；[centered] 为 true 时优先居中
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _kCaptionGap),
      child: Text(
        text,
        textAlign: centered ? TextAlign.center : align,
        style: SheetText.of(context).caption,
      ),
    );
  }
}

/// 分区小标题（「最近使用」「全部」+ 右侧计数）。
class SheetSectionLabel extends StatelessWidget {
  const SheetSectionLabel({
    super.key,
    required this.label,
    this.count,
  });

  final String label;
  final String? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: SheetText.of(context).sectionLabel),
        ),
        if (count != null)
          Text(count!, style: SheetText.of(context).sectionLabel),
      ],
    );
  }
}

/// 文字动作（「详情」「收起」「取消」「保存」）。
class SheetTextAction extends StatelessWidget {
  const SheetTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      child: Text(
        label,
        style: emphasized
            ? SheetText.of(context).chipLabelSelected
            : SheetText.of(context).optionLabel.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
      ),
    );
  }
}

/// 右上角圆形关闭按钮（分类选择弹层）。
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    return SizedBox(
      width: _kCloseButtonSize,
      height: _kCloseButtonSize,
      child: Material(
        color: p.unselectedTint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap ?? () => Navigator.maybePop(context),
          child: Icon(
            AppIcons.clear,
            size: AppIconSize.medium,
            color: p.mutedText,
          ),
        ),
      ),
    );
  }
}
