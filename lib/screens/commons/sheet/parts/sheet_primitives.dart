import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/app_icon_tone.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 壳 / 内容之间的唯一契约 ─────────────────────────────────────
//
// 内容组件（contents/*.dart）**不 import、不调用 Navigator**，也不
// 知道自己被放进哪种容器。它通过 [SheetActions] 只发出两种意图：
//   · close  —— 「我完成了，请关闭」
//   · pin    —— 「这块内容要固定在壳顶端，别跟着滚动」
// 怎么关、怎么固定，都由这一层单点决定。
//
// [SheetScope] 由唯一的壳 [AppSheetShell] 注入，作用是标记
// 「当前在一个 Sheet 容器内」，并持有一个「固定头部槽位」。
// 脱离 Sheet、把内容组件直接放进页面或测试 widget 时没有这个标记：
// close 降级为不操作、pin 降级为就地渲染 —— 内容仍可安全复用。
class SheetScope extends StatefulWidget {
  const SheetScope({super.key, required this.child});

  final Widget child;

  /// 供壳在 Column 里读取槽位；内容组件用 [SheetActions] 即可，不直接取。
  static _SheetScopeAccess? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SheetScopeAccess>();

  @override
  State<SheetScope> createState() => _SheetScopeState();
}

class _SheetScopeState extends State<SheetScope> {
  /// 当前被提升到壳顶端的 Widget（null = 无固定头部）。
  /// 壳用 ValueListenableBuilder 在滚动区**之外**渲染它。
  final ValueNotifier<Widget?> pinnedHeader = ValueNotifier<Widget?>(null);

  @override
  void dispose() {
    pinnedHeader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetScopeAccess(
        pinnedHeader: pinnedHeader,
        child: widget.child,
      );
}

class _SheetScopeAccess extends InheritedWidget {
  const _SheetScopeAccess({
    required this.pinnedHeader,
    required super.child,
  });

  final ValueNotifier<Widget?> pinnedHeader;

  @override
  bool updateShouldNotify(covariant _SheetScopeAccess oldWidget) => false;
}

/// 内容组件与壳之间的**唯一**动作入口。
abstract final class SheetActions {
  static void close<T extends Object?>(BuildContext context, [T? value]) {
    // 不在 Sheet 内时不碰 Navigator：内容可安全复用为普通页面组件。
    if (SheetScope.maybeOf(context) == null) return;
    unawaited(Navigator.maybePop<T>(context, value));
  }

  /// 把 [view] 提升到壳顶端固定（不随内容滚动）。
  ///
  /// 用 post-frame 上报：内容组件的 build 发生在壳 build 之后，
  /// 直接在 build 里改 notifier 会触发 "markNeedsBuild during build"。
  /// 弹层有入场动画，1 帧延迟无感。相同 view 不重复通知。
  static void pin(BuildContext context, Widget view) {
    final access = SheetScope.maybeOf(context);
    if (access == null) return; // 不在 Sheet 内 → 由调用方就地渲染
    final notifier = access.pinnedHeader;
    if (identical(notifier.value, view)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(notifier.value, view)) return;
      notifier.value = view;
    });
  }

  // 刻意不提供 unpin：弹层里的头部都是静态结构，弹层关闭时
  // notifier 随 SheetScope 一起销毁；在 State.dispose 里反向通知
  // 反而容易撞上「notifier 已 dispose」或 unmount 阶段 setState。
  // 后注册的 header 会覆盖前一个，条件渲染的极端场景由业务自行保证。
}

/// 把任意一块内容固定到壳顶端（扩展点）。
///
/// 用法与 [SheetHeader] 一样：放在内容组件里，外观由自己决定，
/// 但渲染位置由壳统一负责。不在 Sheet 内时退化为就地渲染。
class SheetPinned extends StatelessWidget {
  const SheetPinned({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (SheetScope.maybeOf(context) == null) return child;
    SheetActions.pin(context, child);
    return const SizedBox.shrink();
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

/// 统一标题栏。
///
/// [centered] = true → 三栏（取消 / 标题 / 保存），标题真居中；
/// false → 标题与副标题靠左，右侧可放「详情」「关闭」等动作。
/// 两种形态在 6 张原型里都出现过，用同一个组件避免各写一套 Row。
/// Sheet 标题栏：全软件**唯一**的标题零件。
///
/// 位置由壳统一决定：在 `AppSheetShell` 内时自动提升到滚动区**之外**
/// 的固定槽位（不随内容滚动）；脱离 Sheet 单独使用时就地渲染。
///
/// 因此 6 个内容组件照旧写 `SheetHeader(...)` 就行 —— 要不要固定、
/// 固定区加多少内边距、要不要跟拖拽把手一起联动，全部只改壳一个文件。
class SheetHeader extends StatefulWidget {
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
  State<SheetHeader> createState() => _SheetHeaderState();
}

class _SheetHeaderState extends State<SheetHeader> {
  /// 交给槽位的「纯渲染体」，不含上报逻辑 —— 避免在固定槽位里
  /// 再次触发提升造成无限循环。
  late Widget _view;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = _SheetHeaderView(
      title: widget.title,
      subtitle: widget.subtitle,
      leading: widget.leading,
      trailing: widget.trailing,
      centered: widget.centered,
    );
  }

  @override
  void didUpdateWidget(covariant SheetHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _view = _SheetHeaderView(
      title: widget.title,
      subtitle: widget.subtitle,
      leading: widget.leading,
      trailing: widget.trailing,
      centered: widget.centered,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 不在 Sheet 内（普通页面 / 测试 widget）→ 就地渲染，行为与以前一致。
    if (SheetScope.maybeOf(context) == null) return _view;
    SheetActions.pin(context, _view);
    // 内容树里不再占位：标题已由壳在滚动区外渲染。
    return const SizedBox.shrink();
  }
}

/// [SheetHeader] 的纯渲染体（不含提升逻辑）。
class _SheetHeaderView extends StatelessWidget {
  const _SheetHeaderView({
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
