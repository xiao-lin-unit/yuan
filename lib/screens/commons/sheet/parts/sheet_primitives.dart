import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/app_icon_tone.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 壳 / 内容之间的唯一契约 ─────────────────────────────────────
//
// 【这里只有一处"动态"逻辑，把工作逻辑写清楚，别靠猜】
//
// 内容组件（contents/*.dart）不 import、不调用 Navigator，也不
// 知道自己被放进哪种容器。它们只在"我完成了"时调 [SheetActions.close]。
//
// 为什么需要 [SheetScope]：同一个内容组件有时是 Sheet 的 child（要 pop
// 一个 route），有时被直接放进普通页面 / widget 测试（那里没有 route 可
// pop，硬弹会把页面关掉）。所以壳在 build 时注入一个 InheritedWidget
// 作为"我在 Sheet 内"的标记，close 时查一下：
//   · 查得到 → Navigator.maybePop(context, value)
//   · 查不到 → 什么都不做，由调用方自己的 onApply / onSubmit 收尾
//
// 这是能力探测（和 Theme.of / Navigator.of 同一类），**不是运行时注册**：
// 没有 ValueNotifier、没有 postFrame 回调、没有跨帧写入、没有子级提升。
// 壳不因为它而认识任何内容类型，内容也不因为它多出"两种模式"。
//
// 注意：查标记必须用「渲染时的 context」（build 里拿到的那个），
// 不能用调用方构造 Widget 时捕获的页面 context —— 那个 context 在
// SheetScope 之外，会查不到。本项目里所有默认关闭按钮
// （SheetCloseButton / SheetCancelAction）都在自己的 build 里取 context。
class SheetScope extends InheritedWidget {
  const SheetScope({super.key, required super.child});

  static SheetScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SheetScope>();

  @override
  bool updateShouldNotify(covariant SheetScope oldWidget) => false;
}

/// 内容组件**唯一**的「请求关闭 / 回传结果」入口。
abstract final class SheetActions {
  static void close<T extends Object?>(BuildContext context, [T? value]) {
    // 工作逻辑见 [SheetScope] 上方注释：查标记 → 有才 pop。
    if (SheetScope.maybeOf(context) == null) return;
    unawaited(Navigator.maybePop<T>(context, value));
  }
}

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

/// 统一标题栏（**静态零件**：StatelessWidget，无状态、无注册、无副作用）。
///
/// [centered] = true → 三栏（取消 / 标题 / 保存），标题真居中；
/// false → 标题与副标题靠左，右侧可放「详情」「关闭」等动作。
/// 两种形态在 6 张原型里都出现过，用同一个组件避免各写一套 Row。
///
/// 用法（固定与否是**布局**决定的，不是本组件决定的）：
///   AppSheetShell.show(context, header: SheetHeader(title: '主题颜色'),
///                      child: SelectSheetContent(...));
/// 壳把 header 放在 Column 的 Flexible（滚动区）之前 → 标题恒定可见。
/// 本组件只负责"长什么样"，不负责"在哪"。看构造函数就知道全部内容，
/// 没有隐藏分支，脱离 Sheet 单独渲染也是同一个 Row。
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
        ?leading,
        Expanded(
          child: Column(
            crossAxisAlignment:
                centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              titleWidget,
              ?subtitleWidget,
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
    // 确认 / 概览弹层里这是整屏唯一的图标锚点，用 filled 档 +
    // 自动黑/白前景；鲜明档自动换成双色渐变圆 + 同色光晕，
    // 与空状态徽章同一档。语义色（danger/warning/…）仍由
    // sheetIntentTone 传入，换主题自动重算。
    final iconTone = AppIconTone.of(context);
    final pair = iconTone.resolve(tone, AppIconEmphasis.filled);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pair.gradient == null ? pair.container : null,
        gradient: pair.gradient,
        shape: BoxShape.circle,
        boxShadow: iconTone.isVivid
            ? <BoxShadow>[
                BoxShadow(
                  color: pair.container.withValues(alpha: AppOpacity.outline),
                  blurRadius: AppElevation.sheetBlur,
                  offset: AppElevation.cardOffset,
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: AppSheetSize.iconBadgeIconSize,
        color: pair.foreground,
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

/// 顶栏「取消」文字按钮（静态零件）。
///
/// 【为什么单独做一个零件，而不是让调用方传 onTap】
/// [SheetActions.close] 必须用"渲染时的 context"才能查到 [SheetScope]
/// （详见该文件顶部契约注释）。调用方在 `AppSheetShell.show(...)` 之前
/// 构造 header 时捕获的是页面 context，位于 SheetScope 之外，
/// 直接写 `onTap: () => SheetActions.close(context)` 会静默 no-op。
/// 所以这里不接收 onTap，在自己的 build 里取 context 再关闭。
/// 行为固定、一眼能读完，没有任何动态注册。
class SheetCancelAction extends StatelessWidget {
  const SheetCancelAction({super.key, this.label = '取消'});

  final String label;

  @override
  Widget build(BuildContext context) => SheetTextAction(
        label: label,
        onTap: () => SheetActions.close(context),
      );
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
          onTap: onTap ?? () => SheetActions.close(context),
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
