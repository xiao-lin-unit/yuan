import 'package:material_ui/material_ui.dart';

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
///     可点击，选中格用**固定蓝淡底 + 2dp 固定蓝底部指示线**（当前所在
///     分类是导航信息，不跟主题色偏）。
///
/// 【动态逻辑说明】tab 模式是通用结构件里唯一一处动态行为，分步写清：
///   ① 页面持有「当前选中第几格」的状态，把下标和回调一起传进来；
///   ② 组件自己**不持有**任何选中状态，只按 [selectedIndex] 渲染；
///   ③ 点某格 → `onSelected(i)` → 页面 setState → 组件重建 → 高亮同步；
///   ④ 边界：两个参数必须成对（assert 保证）；下标越界时按「无选中」渲染，
///      不会崩；未传回调时格子不可点、也不画高亮。
/// 高亮色取自解耦的 `tokens.info`，换主题色不变；文字取 ColorScheme 中性色。
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
    final t = context.tokens;
    // InkWell 的水波纹画在最近的一层 Material 上；若直接用带不透明底色的
    // Container，splash 会被那层颜色盖住。所以这里显式给每格铺一层 Material，
    // 未选中格透明，露出整条卡片的底色。
    // 选中是导航状态，走解耦的固定蓝淡底，不跟主题色偏。
    return Material(
      color: selected
          ? (Color.lerp(cs.surface, t.info, AppColorEmphasis.accentTint) ??
              cs.surfaceContainerHigh)
          : Colors.transparent,
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
                      color: selected ? t.info : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.value,
                    style: context.appText.menuTitle.copyWith(
                      color: selected ? t.info : null,
                      fontWeight: FontWeight.w700,
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
                    color: t.info,
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
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          // 提示是「信息」职能，用固定蓝淡底；不再铺 primaryContainer。
          color: Color.lerp(cs.surface, t.info, AppColorEmphasis.accentTint) ??
              cs.surfaceContainerHigh,
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
              child: Icon(icon, size: AppIconSize.small, color: t.info),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: context.appText.caption.copyWith(color: t.info),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(AppIcons.clear),
              iconSize: AppIconSize.small,
              color: t.info,
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

// 与 AppTypography.heroValue 同值：主角要明显大于其余所有文字。
const double _kHeroValueSize = 44;
const double _kHeroMinHeight = 140;
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
/// [accent] 由调用方从 `context.tokens` 取**语义色**，本组件不定义颜色。
///
/// 【布局层次：不是从上到下平铺】自上而下分成三个权重不同的区：
///   ① 提示位 —— [label]（口径 / 单位），最小最淡、居中；[trailing] 放
///      右上，供分类胶囊等状态标记用；
///   ② 主角区 —— [value]，全页唯一的大字号、纯中性 onSurface、上下留白
///      最大；[caption] 是它下面的次要说明，淡且居中；
///   ③ 分组指标 —— [secondary]，一条细线隔开，组内收紧、组间放松。
/// 文字职能也分三档（hintStyle / heroValue / captionStyle / infoStyle），
/// 不再一路 caption + sm 等权排队。
///
/// 【配色分工：信息层全中性】[emphasized] 只决定容器取高一档中性
/// surface 还是普通 card，**两者都不带主色**；大数字一律 onSurface，
/// 只有显式传 [accent] 才带语义色。主色归 header / 悬浮操作 / 主按钮。
/// 这是构造期静态 bool，没有运行时注册、没有 Notifier、没有跨帧回调。
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
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String caption;
  final Widget? trailing;
  final List<AppInfoItem> secondary;

  /// 0..1；null = 不画进度条。
  final double? progress;
  final Color? accent;

  /// 是否用高一档的中性容器底（+ 极淡中性渐变）。默认 false = 普通卡。
  /// 两个分支都不带主色，只是明度略差一档，用于首屏与详情屏区分。
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    final bool strong = emphasized;

    // ★ 配色分工：信息层全中性。容器是高一档 neutral surface，口径 /
    // 说明 / 次要指标都是 onSurface 系；只有调用方显式传语义 accent
    // （信用卡额度条 warning）时才带色。主色退到 header / 悬浮操作。
    final Color background = strong ? t.surfaceEmphasis : t.card;
    final Color tone = accent ?? cs.onSurface;

    // ★ 三种「文字职能」分别取不同权重，而不是一路 caption：
    //   提示位(口径/单位) 最小最淡 → 主角(数字) 最大最深 → 说明(白话) 淡。
    final TextStyle hintStyle = context.appText.caption.copyWith(
      color: cs.onSurfaceVariant,
      letterSpacing: 0.4,
    );
    final TextStyle captionStyle =
        context.appText.caption.copyWith(color: cs.onSurfaceVariant);
    final TextStyle infoStyle = context.appText.menuTitle.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
    );

    // 强调分支只保留一层极淡的**中性**渐变（background 已不带主色），
    // 给大卡一点体积；圆角 / 阴影仍全部来自 styles 层。
    final BoxDecoration decoration = strong
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                background,
                Color.lerp(background, cs.surface, 0.34) ?? background,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: cs.shadow.withValues(alpha: AppElevation.cardAlpha),
                offset: AppElevation.cardOffset,
                blurRadius: AppElevation.cardBlur,
              ),
            ],
          )
        : AppDecorations.card(context);

    return Container(
      decoration: decoration,
      // ★ 留白按权重分配：主角区上下最松，分组指标区收紧。
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      constraints: const BoxConstraints(minHeight: _kHeroMinHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 提示位：口径 / 单位居中，右上角留给分类胶囊等状态标记。
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Text(label, textAlign: TextAlign.center, style: hintStyle),
              if (trailing != null)
                Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 主角：全页唯一的大字号 + 纯中性文字，周围留白最大。
          AnimatedSwitcher(
            duration: AppMotion.medium,
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              value,
              key: ValueKey<String>(value),
              textAlign: TextAlign.center,
              style: context.appText.heroValue.copyWith(
                fontSize: _kHeroValueSize,
                color: tone,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 白话说明：次要、淡、居中，不跟主角争。
          Text(caption, textAlign: TextAlign.center, style: captionStyle),
          if (progress != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
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
            // 分组：一条细线把「主角区」与「次要指标组」隔开，
            // 组间 lg、组内 md，形成疏—密的层级节奏。
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, thickness: AppBorder.thin, color: t.divider),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                for (var i = 0; i < secondary.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          secondary[i].label,
                          textAlign: TextAlign.center,
                          style: hintStyle,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          secondary[i].value,
                          textAlign: TextAlign.center,
                          style: infoStyle,
                        ),
                      ],
                    ),
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
  const AppInfoGrid({super.key, required this.items, this.groupLabel});

  final List<AppInfoItem> items;

  /// 可选分组名。传了就在网格上方补一行组标题，让「四个等权小卡」
  /// 变成「有名字的一组指标」——层次感来自归属关系，不是再画四个框。
  final String? groupLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    final TextStyle labelStyle =
        context.appText.caption.copyWith(color: cs.onSurfaceVariant);
    final TextStyle valueStyle = context.appText.menuTitle.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w700,
    );

    Widget cell(AppInfoItem item) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(item.label, style: labelStyle),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                item.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ],
          ),
        );

    final int rows = (items.length / 2).ceil();
    if (rows == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (groupLabel != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              groupLabel!,
              style: context.appText.caption.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
        // 整组共用一张中性卡，内部只靠细线分格：
        // 不再给每个字段都套一个同款容器 + 同款内距 + 同款底色。
        Container(
          decoration: AppDecorations.item(context),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int r = 0; r < rows; r++) ...<Widget>[
                if (r > 0)
                  Divider(
                    height: 1,
                    thickness: AppBorder.thin,
                    color: t.divider,
                  ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: cell(items[r * 2])),
                      // 奇数项时右半留空，保持两列节奏不被打破。
                      Expanded(
                        child: r * 2 + 1 < items.length
                            ? Row(
                                children: <Widget>[
                                  VerticalDivider(
                                    width: 1,
                                    thickness: AppBorder.thin,
                                    color: t.divider,
                                  ),
                                  Expanded(child: cell(items[r * 2 + 1])),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
