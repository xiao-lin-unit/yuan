import 'package:flutter/material.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../header/section_header.dart';
import '../icons/app_icons.dart';

// ── 组件私有样式（只服务本文件，全部引用全局令牌）──────────────
const double _kStatCellHeight = 56;
const double _kHintRadius = AppRadius.item;
const double _kSegmentMinHeight = AppComponentSize.segmentedButtonHeight;

/// 功能页的**结构层**（不是样式层，不是状态层）。
///
/// ── 为什么要做这一层 ────────────────────────────────────────────
/// 之前五个业务页都是 `AppPageScaffold + AppEmptyState` 占位页，没有
/// 「分区 / 统计条 / 提示条 / 分段切换」这些真实功能页共用的骨架。
/// 真做记账、账户、分析页时，如果每页各写一遍 Padding + Card + Row，
/// 刚建好的「全局一处改」立刻碎掉。
///
/// 这里四个组件都是**纯静态布局**：值、文案、回调全部构造期传入，
/// 无 State、无 Notifier、无注册、无跨帧。页面自己决定显示哪个状态，
/// 组件只决定「摆在哪、长什么样」。符合项目「静态优先」约定。
///
/// 结构嵌套（从上到下，三层，一眼读完）：
/// ```
/// AppShell（唯一 Scaffold + 断点导航 + 键盘根开关）
///  └ AppPageScaffold（页级：顶栏 / 滚动内容 / 可选固定底部 / 限宽）
///     └ AppFunctionSection（分区级：标题 + 动作 + child）
///        ├ AppStatBar / AppHintBanner / AppSegmentTabs（块级）
///        └ 业务列表（页面私有）
/// ```
/// 样式一律走 lib/styles/ 与 AppDecorations；本文件不定义任何颜色、
/// 字号、圆角数值，只把全局令牌拼成结构。

/// 分区：标题行 + 内容。标题行复用 [SectionHeader] 的上下留白与字号，
/// 右侧动作可以是文字链接（「显示已隐藏」）或图标。
class AppFunctionSection extends StatelessWidget {
  const AppFunctionSection({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionHeader(
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
            trailing: trailing,
          ),
          child,
        ],
      );
}

/// 统计条的一格（纯数据，不含样式）。
@immutable
class AppStatItem {
  const AppStatItem({required this.label, required this.value});

  final String label;
  final String value;
}

/// 三格统计条（原型「在用 / 已隐藏 / 自定义」「总入账 / 总出账 / 净变动」
/// 都是同一形态）。卡片装饰、分隔线宽度、文字角色全部来自全局层。
class AppStatBar extends StatelessWidget {
  const AppStatBar({super.key, required this.items});

  final List<AppStatItem> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Container(
          decoration: AppDecorations.card(context),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: <Widget>[
                for (var i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    const VerticalDivider(
                      width: 1,
                      thickness: AppBorder.thin,
                    ),
                  Expanded(
                    child: SizedBox(
                      height: _kStatCellHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            items[i].label,
                            style: context.appText.caption,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            items[i].value,
                            style: context.appText.menuTitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// 提示条（原型「拖动右侧 ⠿ 可调整顺序…」）。
///
/// 是否显示由调用方决定（页面里一个 bool），本组件只负责「显示时
/// 长什么样 + 点关闭回调」，不自己持有可见状态 —— 静态优先。
class AppHintBanner extends StatelessWidget {
  const AppHintBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    this.icon = AppIcons.about,
  });

  final String message;
  final VoidCallback onDismiss;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(_kHintRadius),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.xxs,
          AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Icon(icon, size: AppIconSize.small, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: context.appText.caption
                    .copyWith(color: cs.onPrimaryContainer),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(AppIcons.clear),
              iconSize: AppIconSize.small,
              color: cs.onPrimaryContainer,
              constraints: const BoxConstraints.tightFor(
                width: kMinTapTarget,
                height: kMinTapTarget,
              ),
              padding: EdgeInsets.zero,
              tooltip: '不再提示',
            ),
          ],
        ),
      ),
    );
  }
}

/// 分段切换的一项（纯数据）。
@immutable
class AppSegmentOption<T> {
  const AppSegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 支出 / 收入、资产 / 负债这类「二选一或多个并列视图」的统一切换。
/// 用 Material SegmentedButton（圆角、间距、选中态已在 settings.dart
/// 的 SegmentedButtonThemeData 里配好），这里不写任何颜色与尺寸魔法数。
class AppSegmentTabs<T> extends StatelessWidget {
  const AppSegmentTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            segments: <ButtonSegment<T>>[
              for (final AppSegmentOption<T> o in options)
                ButtonSegment<T>(
                  value: o.value,
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Text(o.label),
                  ),
                ),
            ],
            selected: <T>{selected},
            onSelectionChanged: (Set<T> next) {
              if (next.isNotEmpty) onChanged(next.first);
            },
            showSelectedIcon: false,
            // 让两段平分整行，和原型 .cm-tab 一致；不写死宽度。
            emptySelectionAllowed: false,
            style: Theme.of(context).segmentedButtonTheme.style?.copyWith(
                  minimumSize: WidgetStateProperty.all<Size?>(
                    const Size.fromHeight(_kSegmentMinHeight),
                  ),
                ),
          ),
        ),
      );
}
