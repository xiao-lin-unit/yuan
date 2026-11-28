import 'package:material_ui/material_ui.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../header/section_header.dart';
import '../icons/app_icons.dart';
import 'app_info_tip.dart';

// ── 组件私有样式（只服务本文件，全部引用全局令牌）──────────────
// 统计格的**最小高度**，不是固定高度。
//
// 第五轮把它写成 SizedBox(height: 60) 的 tight 约束，并把「56 → 60」当作
// 给 label 旁 28dp 小 ⓘ 热区留 4dp 余量的推算值。真机实测：系统字号 /
// 中文字体度量下，label 行（被 IconButton 热区撑高）+ 4dp 行距 +
// 16px/1.4 数值行的自然高度约 64dp，被 tight 60 压出 4px 底部
// RenderFlex overflow（黄黑条纹）。数字是猜的，撑不撑得下由内容决定。
//
// 改为 ConstrainedBox(minHeight:) 后：常态按内容自然高，下限 60；
// 系统文字缩放再大也只会把格子撑高，不会再 overflow。外层
// IntrinsicHeight 仍把同一条里的所有格统一到最高那一格，保持等高。
const double _kStatCellMinHeight = 60;

// ── label + 小 ⓘ 的横向约束（第十一轮）──────────────────────────
// `Row(mainAxisSize: MainAxisSize.min)` 会给非 flex 子节点 **unbounded
// 横向约束**：Text 就算写了 `overflow: TextOverflow.ellipsis` 也不会生效，
// 因为「没有宽度上限就不需要省略」，Text 按整段文字的自然宽度布局。
// 再加上 ⓘ 的 IconButton 固定 28dp 热区，在 97.6dp 的窄统计格里合计
// 约 111.6dp，被父约束 clamp 到 97.6 → 右侧溢出 14px（真机黄黑条纹）。
//
// 下面几处 label 行统一用 `Flexible` 包 Text：Row 先把固定宽度分给
// ⓘ，再把剩余宽度的**有界**约束交给 Text，省略号才真正起作用。
// 这比缩小 ⓘ 热区更对——28dp 是最小可点目标，不该为排版让路。
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
  const AppStatItem({
    required this.label,
    required this.value,
    this.tip,
  });

  final String label;
  final String value;

  /// 口径说明。传了就在 label 旁显示小 ⓘ，点开展示；不常驻占版面。
  final String? tip;
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
        // 不给 tight 高度：label 旁挂小 ⓘ 后这一列的内容自然高会超过 60，
        // 固定高度必然压出底部溢出。minHeight 只保证格子不塌，长高交给
        // 内容，外层 IntrinsicHeight 负责把整条统计条拉齐到同一高度。
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kStatCellMinHeight),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appText.caption.copyWith(
                            color: selected ? t.info : null,
                          ),
                        ),
                      ),
                      if (item.tip != null)
                        AppInfoTip(
                          title: item.label,
                          message: item.tip!,
                          size: AppIconSize.small,
                        ),
                    ],
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

/// 提示条：现在只是**一行小 ⓘ + 短标签**，点图标才看全文。
///
/// 旧版是一整块淡蓝底 + 整段常驻小灰字，占掉列表顶部一块版面，和
/// 「提示不该抢内容」的层级冲突。参考基金详情页的做法：解释文案收进
/// label 旁的小图标，点开用弹框展示。
///
/// 是否显示仍由调用方决定（页面里一个 bool），本组件不持有可见状态。
class AppHintBanner extends StatelessWidget {
  const AppHintBanner({
    super.key,
    required this.message,
    required this.onDismiss,
    this.label = '使用提示',
  });

  final String message;
  final VoidCallback onDismiss;

  /// 图标旁的短引导文字，不重复展示 [message] 全文。
  /// 视觉固定用 [AppInfoTip] 的小圆圈 i，不再允许调用方换图标 ——
  /// 「提示」全软件一个样子，才不会又散成几套语义。
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          AppInfoTip(
            title: label,
            message: message,
            size: AppIconSize.small,
          ),
          Text(
            label,
            style: context.appText.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(AppIcons.clear),
            iconSize: AppIconSize.small,
            color: cs.onSurfaceVariant,
            constraints: const BoxConstraints.tightFor(
              width: kMinTapTarget,
              height: kMinTapTarget,
            ),
            padding: EdgeInsets.zero,
            tooltip: '不再提示',
          ),
        ],
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

// 流水行的**最小高度**，不是固定高度。
//
// 原来写的是 SizedBox(height: 56) 的 tight 约束，而里面的 Column 装了
// 两行 Text（body 15/1.47≈22dp + caption 13/1.45≈19dp），且 title /
// subtitle 都**没有 maxLines**——长流水标题在窄屏换行后 Column 变 3~4 行，
// 直接把 56dp 撑出纵向 RenderFlex overflow（「纵向超限问题」）。
// 系统文字缩放到 1.3 倍时两行合计约 53dp，也已逼近 56。
//
// 两处一起收：① 两行 Text 补 maxLines:1 + ellipsis，长标题省略而非换行；
// ② 固定高度改 ConstrainedBox(minHeight:)，即便以后有人给行里加内容，
// 也只会把行撑高、不会再被压出溢出。常态两行 41dp < 56dp，行高仍是 56，
// 列表密度与对齐完全不变。
const double _kLedgerRowMinHeight = AppLayout.listItemMinHeight;

/// 信息网格的一格（纯数据）。
@immutable
class AppInfoItem {
  const AppInfoItem({
    required this.label,
    required this.value,
    this.tip,
  });

  final String label;
  final String value;

  /// 字段口径说明。传了就在 label 旁显示小 ⓘ，点开展示。
  final String? tip;
}

/// 明细页顶部的大数字摘要卡（原型 `.detail-hero`）。
///
/// [value] 是业务层用 MoneyFormat 格式化好的字符串；[caption] 是
/// 「口径说明」，现在**不再常驻**：label 旁挂一个小 ⓘ，点开才看
/// （参考基金详情页「昨日收益(元) ⓘ」）。少数必须常驻的补充数据
/// （账单日 / 还款日这类）走 [detail]，不混进提示里。
/// [progress] 0..1 时显示一条已用比例（信用卡额度条），不传就不画。
/// [accent] 由调用方从 `context.tokens` 取**语义色**，本组件不定义颜色。
///
/// 【布局层次：不是从上到下平铺】自上而下分成三个权重不同的区：
///   ① 提示位 —— [label]（口径 / 单位），最小最淡、居中；[trailing] 放
///      右上，供分类胶囊等状态标记用；
///   ② 主角区 —— [value]，全页唯一的大字号、纯中性 onSurface、上下留白
///      最大；[caption] 收进 label 旁的小 ⓘ，[detail] 才是可选的常驻
///      补充数据行（淡且居中）；
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
    this.detail,
    this.trailing,
    this.secondary = const <AppInfoItem>[],
    this.progress,
    this.accent,
    this.emphasized = false,
  });

  final String label;
  final String value;

  /// 口径提示：点 label 旁的小 ⓘ 展示，不占版面。
  final String caption;

  /// 可选的常驻补充数据（账单日 / 还款日等）。不是提示，别塞进 caption。
  final String? detail;
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
          // 提示位：口径 / 单位居中，紧跟一个小 ⓘ 收起解释文案；
          // 右上角留给分类胶囊等状态标记。左右各放一个等宽 Expanded，
          // 既让 label 严格居中，又不会和 trailing 叠在一起。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (trailing != null) const Expanded(child: SizedBox.shrink()),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hintStyle,
                    ),
                  ),
                  if (caption.isNotEmpty)
                    AppInfoTip(
                      title: label,
                      message: caption,
                      size: AppIconSize.small,
                    ),
                ],
              ),
              if (trailing != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                ),
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
          if (detail != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            // 必须常驻的补充数据（账单日 / 还款日）；解释性文案已经收进
            // label 旁的小 ⓘ，这里不再出现一整行小灰字。
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: captionStyle,
            ),
          ],
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                secondary[i].label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: hintStyle,
                              ),
                            ),
                            if (secondary[i].tip != null)
                              AppInfoTip(
                                title: secondary[i].label,
                                message: secondary[i].tip!,
                                size: AppIconSize.small,
                              ),
                          ],
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                  if (item.tip != null)
                    AppInfoTip(
                      title: item.label,
                      message: item.tip!,
                      size: AppIconSize.small,
                    ),
                ],
              ),
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
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kLedgerRowMinHeight),
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
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // 长标题 / 长备注省略而不是换行：换行会把固定 56dp
                        // 的行撑出纵向溢出，且让整条列表行高参差不齐。
                        Text(
                          row.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appText.body,
                        ),
                        Text(
                          row.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appText.caption,
                        ),
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
