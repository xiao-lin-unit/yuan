import 'package:material_ui/material_ui.dart';

import '../../../database/ledger/az_math.dart';
import '../../../database/ledger/az_record.dart';
import '../../../screens/commons/function/app_function_layout.dart';
import '../../../screens/commons/icons/app_icons.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../../../utils/money_format.dart';

/// 资债页的**私有卡片集合**。
///
/// 【通用 / 私有分开】家底账展开、A1/A2 只读镜像、流向三格、白给银行
/// 分段条这些形态只在资债模块出现，按项目约定留在
/// `screens/ledger/widgets/` 私有区，不上提到 commons。
/// 真正被 ≥2 个页面复用的（AppSummaryHero / AppInfoGrid / AppStatBar /
/// AppSegmentTabs / AppFloatingActions）一律直接复用现有公共件。
///
/// 【静态优先】除 [AzNetWorthCard] 的「展开看怎么算的」外，全部是
/// StatelessWidget：值、文案、回调构造期传入；折叠状态由页面持有，本文件
/// 不注册监听、不持有第二份状态。颜色一律走 `context.tokens` 与
/// ColorScheme，组件里不写死任何 hex；金额一律走 [MoneyFormat]。

/// 语义 key → 图标。复用全软件唯一图标表里已有的 key，不新增、不写
/// `Icons.xxx`、不用 emoji；语义相近的大类允许共用同一图标（与分类管理
/// 同一取舍）。新增资产大类时在这里加一行即可，不用迁移数据。
IconData azIcon(String key) => switch (key) {
      'finance' => AppIcons.finance,
      'investment' => AppIcons.investment,
      'housing' => AppIcons.housing,
      'rent' => AppIcons.rent,
      'car' => AppIcons.car,
      'gift' => AppIcons.gift,
      'accountCreditCard' => AppIcons.accountCreditCard,
      'basket' => AppIcons.basket,
      'study' => AppIcons.study,
      'homeImprovement' => AppIcons.homeImprovement,
      'insurance' => AppIcons.insurance,
      'other' => AppIcons.other,
      _ => AppIcons.other,
    };

/// 一行「标签 ← 值」，资债页所有汇总/算式行共用。
class AzKeyValueRow extends StatelessWidget {
  const AzKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.total = false,
    this.minus = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool total;
  final bool minus;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final TextStyle labelStyle = total
        ? context.appText.menuTitle
        : context.appText.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: labelStyle)),
          Text(
            value,
            style: context.appText.menuTitle.copyWith(
              color: valueColor ??
                  (minus
                      ? t.expense
                      : (total ? Theme.of(context).colorScheme.primary : null)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 白话提示小字（原型的 `.sheet-hint`）。全仓同类文案都走这一处。
class AzHint extends StatelessWidget {
  const AzHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Text(text, style: context.appText.caption),
      );
}

/// 分组里的空槽位（比整页 AppEmptyState 轻，不占 200dp 高度）。
class AzSmallEmpty extends StatelessWidget {
  const AzSmallEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppDecorations.item(context),
        padding: const EdgeInsets.all(AppSpacing.md),
        alignment: Alignment.center,
        child: Text(text, style: context.appText.caption),
      );
}

/// 家底账：真正属于你的钱 + 展开「这笔数是怎么算出来的」。
///
/// 【唯一一处动态逻辑，工作逻辑写清楚】为什么动态：展开与否是用户点击
/// 后才有的状态，构造期定不死。用最朴素的 StatefulWidget + setState：
///   ① 点标题行 → `setState(() => _expanded = !_expanded)`；
///   ② true 时在标题行下方渲染逐项算式；false 时只留标题行；
///   ③ 组件销毁时 state 随之消失，路由切换不残留；
///   ④ 没有动画控制器、没有 Notifier、没有跨帧回调。
/// 展开区的每一项都由页面从 [AzMath] 算好传进来，本组件不做任何计算。
class AzNetWorthCard extends StatefulWidget {
  const AzNetWorthCard({
    super.key,
    required this.netWorth,
    required this.caption,
    required this.cashNow,
    required this.monthlyIn,
    required this.monthlyOut,
    required this.mirrors,
    required this.selfAssets,
    required this.assetsTotal,
    required this.debtsTotal,
    required this.contingentCount,
    required this.valuationNote,
    required this.staleNote,
  });

  final double netWorth;
  final String caption;
  final double cashNow;
  final double monthlyIn;
  final double monthlyOut;
  final List<AzAccountMirror> mirrors;
  final double selfAssets;
  final double assetsTotal;
  final double debtsTotal;
  final int contingentCount;
  final String valuationNote;
  final String staleNote;

  @override
  State<AzNetWorthCard> createState() => _AzNetWorthCardState();
}

class _AzNetWorthCardState extends State<AzNetWorthCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final double a1 = widget.mirrors.isEmpty ? 0 : widget.mirrors[0].amount;
    final double a2 = widget.mirrors.length < 2 ? 0 : widget.mirrors[1].amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 配色 A 方案：资债页这一张用主色表面，字走 onEmphasis（不是硬写白）。
        AppSummaryHero(
          label: '真正属于你的钱',
          value: MoneyFormat.yuan0(widget.netWorth),
          caption: widget.caption,
          emphasized: true,
          secondary: <AppInfoItem>[
            AppInfoItem(
              label: '能马上拿出来的',
              value: MoneyFormat.yuan0(widget.cashNow),
            ),
            AppInfoItem(
              label: '每月自动进来',
              value: MoneyFormat.yuan0(widget.monthlyIn),
            ),
            AppInfoItem(
              label: '每月自动出去',
              value: MoneyFormat.yuan0(widget.monthlyOut),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: AppDecorations.card(context),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '这笔数是怎么算出来的',
                          style: context.appText.menuTitle,
                        ),
                      ),
                      Icon(
                        _expanded ? AppIcons.expandMore : AppIcons.chevronRight,
                        size: AppIconSize.medium,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AzKeyValueRow(
                        label: '① 你卡里和手上的钱',
                        value: MoneyFormat.yuan0(a1),
                      ),
                      AzKeyValueRow(
                        label: '② 暂时动不了的钱',
                        value: MoneyFormat.yuan0(a2),
                      ),
                      AzKeyValueRow(
                        label: '③ 除了钱以外的东西',
                        value: MoneyFormat.yuan0(widget.selfAssets),
                      ),
                      AzHint(widget.valuationNote),
                      AzKeyValueRow(
                        label: '东西一共值',
                        value: MoneyFormat.yuan0(widget.assetsTotal),
                        total: true,
                      ),
                      AzKeyValueRow(
                        label: '减：你欠的钱',
                        value: '−${MoneyFormat.yuan0(widget.debtsTotal)}',
                        minus: true,
                      ),
                      AzKeyValueRow(
                        label: '减：万一要你还的钱',
                        value: '不计入（${widget.contingentCount} 笔）',
                        valueColor: context.appText.caption.color,
                      ),
                      AzKeyValueRow(
                        label: '真正属于你的钱',
                        value: MoneyFormat.yuan0(widget.netWorth),
                        total: true,
                        valueColor: t.accentOnEmphasis,
                      ),
                      if (widget.staleNote.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            widget.staleNote,
                            style: context.appText.caption
                                .copyWith(color: t.warning),
                          ),
                        ),
                      const AzHint(
                        '账本里记的都是当时填下的钱数，不会自己改大改小；'
                        '变化趋势按月末存一次数，之后改了数也不改历史。',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A1 / A2 只读镜像行。唯一写入点在账户页，这里点一下只做跳转。
class AzMirrorRow extends StatelessWidget {
  const AzMirrorRow({
    super.key,
    required this.mirror,
    required this.onTap,
  });

  final AzAccountMirror mirror;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        child: Container(
          decoration: AppDecorations.item(context),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Icon(
                    mirror.a1 ? AppIcons.accountCash : AppIcons.locked,
                    size: AppIconSize.medium,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(mirror.label, style: context.appText.menuTitle),
                        Text(
                          mirror.a1
                              ? '能自由花 · ${mirror.accountCount} 个账户'
                              : '有特定用途，不能随便花 · ${mirror.accountCount} 个账户',
                          style: context.appText.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    MoneyFormat.yuan0(mirror.amount),
                    style: context.appText.menuTitle,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  const Icon(AppIcons.chevronRight, size: AppIconSize.small),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 流向账三格：给你钱 / 拿你钱 / 不上班也能剩。
class AzFlowCard extends StatelessWidget {
  const AzFlowCard({
    super.key,
    required this.flow,
    required this.inSub,
    required this.outSub,
  });

  final AzFlow flow;
  final String inSub;
  final String outSub;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: AppDecorations.card(context),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: IntrinsicHeight(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _cell(
                  context,
                  '给你钱',
                  MoneyFormat.yuan0(flow.fixed),
                  inSub,
                  t.income,
                ),
              ),
              const VerticalDivider(width: 1, thickness: AppBorder.thin),
              Expanded(
                child: _cell(
                  context,
                  '拿你钱',
                  MoneyFormat.yuan0(flow.totalOut),
                  outSub,
                  t.expense,
                ),
              ),
              const VerticalDivider(width: 1, thickness: AppBorder.thin),
              Expanded(
                child: _cell(
                  context,
                  '不上班也能剩',
                  MoneyFormat.yuan0(flow.passiveLeft),
                  '进来的减出去的',
                  flow.passiveLeft >= 0 ? t.income : t.expense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String label,
    String value,
    String sub,
    Color tone,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: context.appText.caption),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              value,
              style: context.appText.menuTitle.copyWith(color: tone),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(sub, style: context.appText.caption),
          ],
        ),
      );
}

/// 可折叠分组头（在给你钱 / 在拿你钱 / 不进也不出）。
/// 折叠状态由页面持有，本组件纯静态：只按 [collapsed] 渲染。
class AzGroupSection extends StatelessWidget {
  const AzGroupSection({
    super.key,
    required this.label,
    required this.count,
    required this.sumText,
    required this.collapsed,
    required this.onToggle,
    required this.children,
    this.sumPositive = false,
  });

  final String label;
  final int count;
  final String sumText;
  final bool collapsed;
  final VoidCallback onToggle;
  final List<Widget> children;
  final bool sumPositive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  collapsed ? AppIcons.chevronRight : AppIcons.expandMore,
                  size: AppIconSize.medium,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(label, style: context.appText.sectionHeader),
                ),
                Text('$count', style: context.appText.caption),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  sumText,
                  style: context.appText.menuTitle.copyWith(
                    color: sumPositive ? t.income : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: children.isEmpty
                ? const AzSmallEmpty('暂无')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final Widget c in children) ...<Widget>[
                        c,
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
          ),
      ],
    );
  }
}

/// 一项资产卡。值、流向标签、估值时间标签全部由页面算好传入。
class AzAssetCard extends StatelessWidget {
  const AzAssetCard({
    super.key,
    required this.asset,
    required this.valueText,
    required this.tag,
    required this.staleText,
    required this.onTap,
  });

  final AssetRecord asset;
  final String valueText;
  final AzFlowTag tag;
  final String staleText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: AppDecorations.item(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    azIcon(asset.iconKey),
                    size: AppIconSize.medium,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      asset.code.isEmpty ? asset.name : '${asset.name}（${asset.code}）',
                      style: context.appText.menuTitle,
                    ),
                  ),
                  Text(valueText, style: context.appText.menuTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: <Widget>[
                  Text(
                    tag.text,
                    style: context.appText.caption.copyWith(
                      color: tag.good
                          ? t.income
                          : (tag.bad ? t.expense : null),
                    ),
                  ),
                  const Spacer(),
                  Text(staleText, style: context.appText.caption),
                ],
              ),
              if (asset.intention.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(asset.intention, style: context.appText.caption),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一笔欠款卡。按实际一年要付多少从高到低排（页面已排好）。
class AzDebtCard extends StatelessWidget {
  const AzDebtCard({
    super.key,
    required this.debt,
    required this.rateText,
    required this.costText,
    required this.leverageText,
    required this.subText,
    required this.onTap,
  });

  final LiabilityRecord debt;
  final String rateText;
  final String costText;
  final String leverageText;
  final String subText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: AppDecorations.item(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    azIcon(debt.iconKey),
                    size: AppIconSize.medium,
                    color: t.expense,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(debt.name, style: context.appText.menuTitle),
                  ),
                  Text(
                    MoneyFormat.yuan0(debt.principal),
                    style: context.appText.menuTitle.copyWith(color: t.expense),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(rateText, style: context.appText.caption),
              Text(
                costText,
                style: context.appText.caption.copyWith(color: t.expense),
              ),
              if (leverageText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    leverageText,
                    style: context.appText.caption.copyWith(color: t.warning),
                  ),
                ),
              if (subText.isNotEmpty)
                Text(subText, style: context.appText.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// 负债页顶部：一共欠多少 / 这个月要还 / 偿债比例条 / 安全提示。
class AzDebtHero extends StatelessWidget {
  const AzDebtHero({
    super.key,
    required this.stats,
    required this.incomeSet,
    required this.levelLabel,
    required this.safeText,
  });

  final AzDebtStats stats;
  final bool incomeSet;
  final String levelLabel;
  final String safeText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final double ratio = stats.payIncomeRatio;
    final bool over = incomeSet && ratio > 0.4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: AppDecorations.card(context),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('一共欠多少', style: context.appText.caption),
                      Text(
                        MoneyFormat.yuan0(stats.total),
                        style: context.appText.pageTitle,
                      ),
                      Text('${stats.count} 笔欠款', style: context.appText.caption),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('这个月要还', style: context.appText.caption),
                    Text(
                      MoneyFormat.yuan0(stats.monthPay),
                      style: context.appText.menuTitle,
                    ),
                    Text(
                      incomeSet
                          ? '占每月到手 ${(ratio * 100).toStringAsFixed(0)}%'
                          : '还没填每月到手的钱',
                      style: context.appText.caption,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: LinearProgressIndicator(
                value: incomeSet ? ratio.clamp(0.0, 1.0).toDouble() : 0,
                minHeight: AppComponentSize.linearProgressHeight + 2,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: over ? t.expense : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              safeText,
              style: context.appText.caption.copyWith(
                color: over ? t.expense : null,
              ),
            ),
            Text('当前口径：$levelLabel', style: context.appText.caption),
          ],
        ),
      ),
    );
  }
}

/// 白给银行多少钱：利息 / 手续费 / 本金三段条 + 图例。
class AzBurnCard extends StatelessWidget {
  const AzBurnCard({
    super.key,
    required this.cost,
    required this.interest,
    required this.fee,
    required this.pay,
    required this.ratioText,
  });

  final double cost;
  final double interest;
  final double fee;
  final double pay;
  final String ratioText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final double principal = pay - interest - fee > 0 ? pay - interest - fee : 0;
    final double total = (interest + fee + principal) == 0
        ? 1
        : interest + fee + principal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: AppDecorations.card(context),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('这个月白给银行的', style: context.appText.caption),
                ),
                Text(
                  MoneyFormat.yuan0(cost),
                  style: context.appText.pageTitle.copyWith(color: t.expense),
                ),
              ],
            ),
            Text(ratioText, style: context.appText.caption),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: SizedBox(
                height: AppComponentSize.linearProgressHeight + 4,
                child: Row(
                  children: <Widget>[
                    if (interest > 0)
                      Expanded(
                        flex: (interest / total * 1000).round() < 1
                            ? 1
                            : (interest / total * 1000).round(),
                        child: Container(color: t.expense),
                      ),
                    if (fee > 0)
                      Expanded(
                        flex: (fee / total * 1000).round() < 1
                            ? 1
                            : (fee / total * 1000).round(),
                        child: Container(color: t.warning),
                      ),
                    if (principal > 0)
                      Expanded(
                        flex: (principal / total * 1000).round() < 1
                            ? 1
                            : (principal / total * 1000).round(),
                        child: Container(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '本金不算花掉的钱，利息和手续费才算。',
              style: context.appText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// 三格入口：划不划算 / 哪个月最紧张 / 利率涨 1 个点。
class AzMiniGrid3 extends StatelessWidget {
  const AzMiniGrid3({
    super.key,
    required this.leverageText,
    required this.worstText,
    required this.floatText,
    required this.onLeverage,
    required this.onGap,
  });

  final String leverageText;
  final String worstText;
  final String floatText;
  final VoidCallback onLeverage;
  final VoidCallback onGap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _mini(
              context,
              '借钱买的东西\n划不划算',
              leverageText,
              t.info,
              onLeverage,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _mini(
              context,
              '哪个月最紧张',
              worstText,
              t.warning,
              onGap,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _mini(
              context,
              '利率涨 1 个点\n每月多还',
              floatText,
              t.info,
              null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(
    BuildContext context,
    String label,
    String value,
    Color tone,
    VoidCallback? onTap,
  ) {
    final Widget body = Container(
      decoration: AppDecorations.item(context),
      padding: const EdgeInsets.all(AppSpacing.sm),
      constraints: const BoxConstraints(minHeight: 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: context.appText.caption),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: context.appText.menuTitle.copyWith(color: tone),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            onTap == null ? '只算会变的那些' : '点开看',
            style: context.appText.caption,
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

/// 汇总行（资产汇总 / 负债汇总共用）。
class AzSummaryRows extends StatelessWidget {
  const AzSummaryRows({super.key, required this.rows});

  final List<AzKeyValueRow> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Container(
          decoration: AppDecorations.card(context),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          ),
        ),
      );
}

/// 真要用钱能拿出多少：按「多久能变成现金」分四层，各带一条比例条。
class AzCashLayers extends StatelessWidget {
  const AzCashLayers({
    super.key,
    required this.layers,
    required this.total,
  });

  final List<AzCashLayer> layers;
  final double total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Container(
          decoration: AppDecorations.card(context),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final AzCashLayer l in layers) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(l.label, style: context.appText.body)),
                    Text(
                      MoneyFormat.yuan0(l.amount),
                      style: context.appText.menuTitle,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: LinearProgressIndicator(
                    value: total <= 0
                        ? 0
                        : (l.amount / total).clamp(0.0, 1.0).toDouble(),
                    minHeight: AppComponentSize.linearProgressHeight,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(l.note, style: context.appText.caption),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      );
}

/// 快到期的（未来 90 天）。到期日由用户输入，界面标「还有 X 天」。
class AzDueList extends StatelessWidget {
  const AzDueList({
    super.key,
    required this.debts,
    required this.today,
    required this.onTap,
  });

  final List<LiabilityRecord> debts;
  final DateTime today;
  final ValueChanged<LiabilityRecord> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (debts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AzSmallEmpty('未来 3 个月没有到期的'),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final LiabilityRecord d in debts) ...<Widget>[
            Container(
              decoration: AppDecorations.item(context),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(d),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Icon(azIcon(d.iconKey), size: AppIconSize.medium),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(d.name, style: context.appText.menuTitle),
                            Text(
                              '每月 ${d.payDay ?? '—'} 号还 ${MoneyFormat.yuan0(d.monthlyPay)}',
                              style: context.appText.caption,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        d.endDate == null
                            ? '—'
                            : '还有 ${d.endDate!.difference(today).inDays} 天',
                        style: context.appText.caption.copyWith(color: t.warning),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// 两张成对清单（7.11 / 13.10）。唯一可编辑入口在各自标题行右侧的「＋」。
/// 两张都**不算进「一共欠多少」，也不算进「真正属于你的钱」**。
class AzContingentList extends StatelessWidget {
  const AzContingentList({
    super.key,
    required this.items,
    required this.kind,
    required this.onAdd,
    required this.onTap,
  });

  final List<ContingentRecord> items;
  final ContingentKind kind;
  final VoidCallback onAdd;
  final ValueChanged<ContingentRecord> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final double total = items.fold<double>(
      0,
      (double s, ContingentRecord c) => s + c.maxAmount,
    );
    final bool insured = kind == ContingentKind.insured;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ContingentRecord c in items) ...<Widget>[
            Container(
              decoration: AppDecorations.item(context),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(c),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        insured ? AppIcons.insurance : AppIcons.warning,
                        size: AppIconSize.medium,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(c.title, style: context.appText.menuTitle),
                            Text(
                              <String>[
                                if (c.conditionText.isNotEmpty) c.conditionText,
                                if (c.eta.isNotEmpty) '大概 ${c.eta}',
                              ].join(' · '),
                              style: context.appText.caption,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        MoneyFormat.yuan0(c.maxAmount),
                        style: context.appText.menuTitle.copyWith(
                          color: insured ? t.income : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (items.isEmpty)
            const AzSmallEmpty('暂无记录'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(AppIcons.add, size: AppIconSize.small),
              label: Text(insured ? '记一笔有人替我付' : '记一笔可能要我还'),
            ),
          ),
          Text(
            insured
                ? '最多合计 ${MoneyFormat.yuan0(total)} 有人替你付，不计入总账。'
                : '最多可能要还 ${MoneyFormat.yuan0(total)}，不计入总账。',
            style: context.appText.caption,
          ),
        ],
      ),
    );
  }
}
