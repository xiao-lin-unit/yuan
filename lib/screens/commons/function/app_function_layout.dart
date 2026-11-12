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
const double _kStatIndicatorHeight = 2;

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
///
/// 两种用法，构造期一眼可辨：
///   · **纯展示**（默认，不传 [selectedIndex] / [onSelected]）：三格只是数字，
///     完全静态，行为与旧版一致；
///   · **可点 tab**（成对传入 [selectedIndex] + [onSelected]）：每格变成
///     可点击，选中格用 primaryContainer 底 + 2dp 主色底部指示线。
///
/// 【动态逻辑说明】tab 模式是通用结构件里唯一一处动态行为，分步写清：
///   ① 页面持有「当前选中第几格」的状态，把下标和回调一起传进来；
///   ② 组件自己**不持有**任何选中状态，只按 [selectedIndex] 渲染；
///   ③ 点某格 → `onSelected(i)` → 页面 setState → 组件重建 → 高亮同步；
///   ④ 边界：两个参数必须成对（assert 保证）；下标越界时按「无选中」渲染，
///      不会崩；未传回调时格子不可点、也不画高亮。
/// 高亮色与文字色全部取自 ColorScheme，换主题色 / 切明暗自动跟随。
class AppStatBar extends StatelessWidget {
  const AppStatBar({
    super.key,
    required this.items,
    this.selectedIndex,
    this.onSelected,
  }) : assert(
          (selectedIndex == null) == (onSelected == null),
          'tab 模式必须同时传 selectedIndex 和 onSelected',
        );

  final List<AppStatItem> items;

  /// 当前选中格下标；null = 纯展示模式。
  final int? selectedIndex;

  /// 点某格的回调；null = 纯展示模式。
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final bool tabMode = onSelected != null;
    return Padding(
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
                  child: _StatCell(
                    item: items[i],
                    selected: tabMode && selectedIndex == i,
                    onTap: tabMode ? () => onSelected!(i) : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 统计条的一格。样式全走全局令牌；是否可点由 [onTap] 决定。
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppStatItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // InkWell 的水波纹画在最近的一层 Material 上；若直接用带不透明底色的
    // Container，splash 会被那层颜色盖住。所以这里显式给每格铺一层 Material，
    // 未选中格透明，露出整条卡片的底色。
    return Material(
      color: selected ? cs.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _kStatCellHeight,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.label,
                    style: context.appText.caption.copyWith(
                      color: selected ? cs.onPrimaryContainer : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.value,
                    style: context.appText.menuTitle.copyWith(
                      color: selected ? cs.onPrimaryContainer : null,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: _kStatIndicatorHeight,
                    color: cs.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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

// ══════════════════════════════════════════════════════════════════
// 明细页通用结构件（本轮账户明细页首次使用）
//
// 【为什么上提到通用层】原型里「资产明细 / 负债明细 / 账单明细」用的都是
// 同一套：大数字摘要卡 → 2 列信息网格 → 按日期分组的流水列表。
// 它们会被 ≥2 个页面复用，按「通用 / 私有分开」的规矩放这里；
// 文案与数值由业务层构造期传入，本文件不认识「账户」「负债」这些概念。
// 全部纯静态，无状态、无回调注册。
// ══════════════════════════════════════════════════════════════════

const double _kHeroValueSize = 36;
const double _kHeroMinHeight = 132;
const double _kProgressHeight = 6;
const double _kLedgerRowHeight = AppLayout.listItemMinHeight;

/// 信息网格的一格（纯数据）。
@immutable
class AppInfoItem {
  const AppInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

/// 明细页顶部的大数字摘要卡（原型 `.detail-hero`）。
///
/// [value] 是业务层用 MoneyFormat 格式化好的字符串；[caption] 是
/// 设计原则第一条要求的「大白话解释」，每个数字旁边都要说清代表什么。
/// [progress] 0..1 时显示一条已用比例（信用卡额度条），不传就不画。
/// [accent] 由调用方从 `context.tokens` 取语义色，本组件不定义颜色。
class AppSummaryHero extends StatelessWidget {
  const AppSummaryHero({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.trailing,
    this.secondary = const <AppInfoItem>[],
    this.progress,
    this.accent,
  });

  final String label;
  final String value;
  final String caption;
  final Widget? trailing;
  final List<AppInfoItem> secondary;

  /// 0..1；null = 不画进度条。
  final double? progress;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color tone = accent ?? cs.primary;
    return Container(
      decoration: AppDecorations.card(context),
      padding: const EdgeInsets.all(AppSpacing.md),
      constraints: const BoxConstraints(minHeight: _kHeroMinHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(label, style: context.appText.caption),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: context.appText.pageTitle.copyWith(
              fontSize: _kHeroValueSize,
              color: tone,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(caption, style: context.appText.caption),
          if (progress != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0).toDouble(),
                minHeight: _kProgressHeight,
                backgroundColor: cs.surfaceContainerHighest,
                color: tone,
              ),
            ),
          ],
          if (secondary.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                for (var i = 0; i < secondary.length; i++) ...<Widget>[
                  if (i > 0)
                    const SizedBox(width: AppSpacing.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(secondary[i].label,
                          style: context.appText.caption),
                      Text(secondary[i].value,
                          style: context.appText.menuTitle),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 2 列信息网格（原型 `.detail-info-grid`）。
/// 用 Wrap 而不是 GridView：格子高度随内容自适应，也不会和外层
/// SingleChildScrollView 抢滚动手势。
class AppInfoGrid extends StatelessWidget {
  const AppInfoGrid({super.key, required this.items});

  final List<AppInfoItem> items;

  @override
  Widget build(BuildContext context) {
    final double cellWidth =
        (MediaQuery.sizeOf(context).width - AppSpacing.md * 2 - AppSpacing.xs) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          for (final AppInfoItem item in items)
            SizedBox(
              width: cellWidth.clamp(120.0, 320.0).toDouble(),
              child: Container(
                decoration: AppDecorations.item(context),
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(item.label, style: context.appText.caption),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(item.value, style: context.appText.menuTitle),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 流水的一行（纯数据，金额已由业务层用 MoneyFormat 格式化）。
@immutable
class AppLedgerRowData {
  const AppLedgerRowData({
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.icon,
    required this.positive,
  });

  final String title;
  final String subtitle;
  final String amountText;

  /// 图标语义 key 解析后的 IconData，由业务层从 AppIcons 取。
  final IconData icon;

  /// true = 入账（取 income 语义色），false = 出账（取 expense 语义色）。
  final bool positive;
}

/// 按交易日期分组的一组流水（附录 C：以交易时间归属，不是录入时间）。
@immutable
class AppLedgerGroupData {
  const AppLedgerGroupData({required this.dateLabel, required this.rows});

  final String dateLabel;
  final List<AppLedgerRowData> rows;
}

/// 明细页的流水列表。分组标题 + 行，行高走 AppLayout.listItemMinHeight。
/// 颜色只取 `context.tokens` 的 income / expense 语义色，换主题自动跟随。
class AppLedgerList extends StatelessWidget {
  const AppLedgerList({super.key, required this.groups});

  final List<AppLedgerGroupData> groups;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final AppLedgerGroupData group in groups) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xxs,
            ),
            child: Text(group.dateLabel, style: context.appText.caption),
          ),
          for (final AppLedgerRowData row in group.rows)
            SizedBox(
              height: _kLedgerRowHeight,
              child: Row(
                children: <Widget>[
                  Icon(row.icon,
                      size: AppIconSize.medium,
                      color: row.positive ? tokens.income : tokens.expense),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(row.title, style: context.appText.body),
                        Text(row.subtitle, style: context.appText.caption),
                      ],
                    ),
                  ),
                  Text(
                    row.amountText,
                    style: context.appText.menuTitle.copyWith(
                      color: row.positive ? tokens.income : tokens.expense,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
