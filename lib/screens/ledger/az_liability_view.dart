import 'package:material_ui/material_ui.dart';

import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import 'az_view_contract.dart';
import 'widgets/az_cards.dart';

/// 负债视图（原型 `#view-liability`）。
///
/// 顺序照原型：一共欠多少、贵不贵 → 这个月白给银行多少 → 划不划算 /
/// 哪个月最紧张 / 利率涨 1 个点 → 欠的每一笔 → 快到期的 → 两张成对
/// 清单 → 负债汇总。所有数字由 [AzMath] 现场算，页面不写死金额。
class AzLiabilityView extends StatelessWidget {
  const AzLiabilityView({
    super.key,
    required this.view,
    required this.actions,
  });

  final AzViewData view;
  final AzViewActions actions;

  @override
  Widget build(BuildContext context) {
    final AzData d = view.data;
    final t = context.tokens;
    final List<LiabilityRecord> debts = d.activeLiabilities;
    final List<AzGapRow> gaps = AzMath.gapTable(d, view.accounts, view.today);
    final AzDebtStats stats = AzMath.debtStats(d, gaps);
    final AzFlow flow = AzMath.flow(d);
    final DebtRatioLevel level = d.preferences.debtRatioLevel;
    final bool incomeSet = d.preferences.monthlyIncome > 0;
    final bool mustCostSet = d.preferences.mustCost > 0;
    final double limit = level.limit;

    final String safeText = !incomeSet
        ? '还没填「每月到手的钱」：去设置里填一次，这里才看得出每个月要还的钱占挣的多少。'
        : (stats.payIncomeRatio > limit
            ? '已经超过${level.label}口径的 ${(limit * 100).toStringAsFixed(0)}%：'
                '每挣 100 块有 ${(stats.payIncomeRatio * 100).toStringAsFixed(0)} 块要拿去还债，'
                '手上一有闪失就转不动。'
            : '还在${level.label}口径的安全线内（${(limit * 100).toStringAsFixed(0)}%）。'
                '换口径点右边「偿债口径」。');

    final List<LiabilityRecord> ordered = AzMath.payoffOrder(d);
    final List<LiabilityRecord> shown = _filter(debts, view.filter, d, view.today);
    final List<LiabilityRecord> due = AzMath.dueSoon(d, view.today, 90);
    final List<ContingentRecord> contingent = d.activeContingents
        .where((ContingentRecord c) => c.kind == ContingentKind.contingent)
        .toList();
    final List<ContingentRecord> insured = d.activeContingents
        .where((ContingentRecord c) => c.kind == ContingentKind.insured)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _chips(context, debts, d, view.today),
        const AppFunctionSection(
          title: '一共欠多少、贵不贵',
          child: SizedBox.shrink(),
        ),
        AzDebtHero(
          stats: stats,
          incomeSet: incomeSet,
          levelLabel: level.label,
          safeText: safeText,
        ),
        const SizedBox(height: AppSpacing.sm),
        AzBurnCard(
          cost: stats.monthCost,
          interest: flow.interest,
          fee: flow.fee,
          pay: stats.monthPay,
          ratioText: stats.monthPay == 0
              ? '这个月没有要还的分期'
              : '占这个月还款 ${(stats.interestRatio * 100).toStringAsFixed(0)}%'
                  '${incomeSet ? ' · 占月收入 ${(stats.monthCost / d.preferences.monthlyIncome * 100).toStringAsFixed(0)}%' : ''}',
        ),
        const SizedBox(height: AppSpacing.sm),
        AzMiniGrid3(
          leverageText: _leverageSummary(d, ordered),
          worstText: stats.worstMonth,
          floatText: MoneyFormat.yuan0(stats.floatDelta),
          onLeverage: actions.leverage,
          onGap: actions.gap,
        ),
        // ── 欠的每一笔 ──────────────────────────────────────────
        AppFunctionSection(
          title: '欠的每一笔',
          actionLabel: '先还哪一笔最划算 ›',
          onAction: actions.payoff,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: shown.isEmpty
                ? const AzSmallEmpty('没有欠款，这是好事')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final LiabilityRecord x in shown) ...<Widget>[
                        AzDebtCard(
                          debt: x,
                          rateText:
                              '实际一年 ${(AzMath.realAnnualRate(x) * 100).toStringAsFixed(1)}%'
                              '${x.rateType == RateType.float ? '（会变）' : ''}',
                          costText: x.monthlyCost > 0
                              ? '每月白给 ${MoneyFormat.yuan0(x.monthlyCost)}'
                              : '这个月不产生利息',
                          leverageText: _leverageLine(d, x),
                          subText: _sub(x),
                          onTap: () => actions.openDebt(x),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: OutlinedButton.icon(
            onPressed: actions.addDebt,
            icon: const Icon(AppIcons.add, size: AppIconSize.small),
            label: const Text('＋ 新增一笔欠款'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppLayout.fieldMinHeight),
            ),
          ),
        ),
        // ── 快到期的 ────────────────────────────────────────────
        const AppFunctionSection(
          title: '快到期的',
          child: SizedBox.shrink(),
        ),
        AzDueList(
          debts: due,
          today: view.today,
          onTap: actions.openDebt,
        ),
        // ── 两张成对清单 ────────────────────────────────────────
        const AppFunctionSection(
          title: '万一要我还的钱',
          child: SizedBox.shrink(),
        ),
        AzContingentList(
          items: contingent,
          kind: ContingentKind.contingent,
          onAdd: actions.addContingent,
          onTap: actions.openContingent,
        ),
        const AppFunctionSection(
          title: '万一出事，有人替我付吗',
          child: SizedBox.shrink(),
        ),
        AzContingentList(
          items: insured,
          kind: ContingentKind.insured,
          onAdd: actions.addInsured,
          onTap: actions.openContingent,
        ),
        const AzHint(
          '这两张都不算进「一共欠多少」，也不算进「真正属于你的钱」——'
          '它们现在不用还，但真出事就得还，所以单独摆出来让你看得见。',
        ),
        // ── 负债汇总 ────────────────────────────────────────────
        AppFunctionSection(
          title: '负债汇总',
          actionLabel: '偿债口径：${level.label} ▾',
          onAction: actions.ratioLevel,
          child: AzSummaryRows(
            rows: <AzKeyValueRow>[
              for (final AzClassSum s in AzMath.byType(d))
                AzKeyValueRow(
                  label: '${s.label}（${s.count} 笔）',
                  value: MoneyFormat.yuan0(s.sum),
                ),
              AzKeyValueRow(
                label: '一共欠多少',
                value: MoneyFormat.yuan0(stats.total),
                valueColor: t.expense,
                total: true,
              ),
              AzKeyValueRow(
                label: '其中这个月要还',
                value: MoneyFormat.yuan0(stats.monthPay),
              ),
              AzKeyValueRow(
                label: '这个月白给银行的',
                value: MoneyFormat.yuan0(stats.monthCost),
                valueColor: t.expense,
              ),
              AzKeyValueRow(
                label: '还完债还剩（月收入−必须花的）÷月还款',
                value: (!incomeSet || !mustCostSet || stats.monthPay == 0)
                    ? '—'
                    : '${stats.afterDebt.toStringAsFixed(1)} 倍',
                valueColor: stats.afterDebt < 1.5 ? t.expense : t.income,
              ),
            ],
          ),
        ),
        const AzHint(
          '这里记的是真要还给别人、有账期的钱；自己住的房子每个月要贴的钱，'
          '记在那套房子的卡片上。软件不评价你花钱对不对，只把钱往哪边流摆出来。',
        ),
      ],
    );
  }

  Widget _chips(
    BuildContext context,
    List<LiabilityRecord> debts,
    AzData d,
    DateTime today,
  ) {
    final List<List<String>> chips = <List<String>>[
      <String>['all', '全部', '${debts.length}'],
      <String>[
        'cost',
        '最贵的',
        '${debts.where((LiabilityRecord x) => AzMath.realAnnualRate(x) > 0.1).length}'
      ],
      <String>[
        'T4',
        '先花后还',
        '${debts.where((LiabilityRecord x) => x.purpose == DebtPurpose.t4).length}'
      ],
      <String>[
        'float',
        '利率会变',
        '${debts.where((LiabilityRecord x) => x.rateType == RateType.float).length}'
      ],
      <String>[
        'due',
        '快到期',
        '${AzMath.dueSoon(d, today, 90).length}'
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        children: <Widget>[
          for (final List<String> c in chips)
            ChoiceChip(
              label: Text('${c[1]} ${c[2]}'),
              selected: view.filter == c[0],
              onSelected: (_) => actions.filterChanged(c[0]),
            ),
        ],
      ),
    );
  }

  static List<LiabilityRecord> _filter(
    List<LiabilityRecord> src,
    String filter,
    AzData d,
    DateTime today,
  ) {
    if (filter == 'all' || filter == 'give' || filter == 'take' ||
        filter == 'flat' || filter == 'A7' || filter == 'A4' ||
        filter == 'stale') {
      return src;
    }
    if (filter == 'cost') {
      final List<LiabilityRecord> l = src
          .where((LiabilityRecord x) => AzMath.realAnnualRate(x) > 0.1)
          .toList();
      l.sort((LiabilityRecord a, LiabilityRecord b) =>
          AzMath.realAnnualRate(b).compareTo(AzMath.realAnnualRate(a)));
      return l;
    }
    if (filter == 'T4') {
      return src
          .where((LiabilityRecord x) => x.purpose == DebtPurpose.t4)
          .toList();
    }
    if (filter == 'float') {
      return src
          .where((LiabilityRecord x) => x.rateType == RateType.float)
          .toList();
    }
    if (filter == 'due') return AzMath.dueSoon(d, today, 90);
    return src;
  }

  static String _sub(LiabilityRecord x) => <String>[
        x.purpose.label,
        x.repayMethod.label,
        if (x.leftTerms > 0) '还剩 ${x.leftTerms} 期',
        if (x.payDay != null) '每月 ${x.payDay} 号还',
        if (x.status != LiabilityStatus.normal) x.status.label,
      ].join(' · ');

  static String _leverageLine(AzData d, LiabilityRecord x) {
    final AzLeverage? lev = AzMath.leverageOf(x, d.activeAssets);
    if (lev != null) {
      return lev.net >= 0
          ? '它替你付了利息，还多留 ${MoneyFormat.yuan0(lev.net)}'
          : '它每月从你口袋拿走 ${MoneyFormat.yuan0(-lev.net)}';
    }
    if (x.purpose == DebtPurpose.t4) return '借来先花了再还，成本最高';
    if (x.purpose == DebtPurpose.t5) return '这是应急借的，不是乱花';
    return '';
  }

  static String _leverageSummary(AzData d, List<LiabilityRecord> ordered) {
    final List<AzLeverage> list = <AzLeverage>[
      for (final LiabilityRecord x in ordered)
        if (AzMath.leverageOf(x, d.activeAssets) != null)
          AzMath.leverageOf(x, d.activeAssets)!,
    ];
    if (list.isEmpty) return '没有借钱买东西';
    list.sort((AzLeverage a, AzLeverage b) => a.net.compareTo(b.net));
    return list.first.net >= 0 ? '划得来' : '不划算';
  }
}
