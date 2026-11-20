import 'package:material_ui/material_ui.dart';
import 'package:yuan/styles/app_typography.dart';

import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import 'az_view_contract.dart';
import 'widgets/az_cards.dart';

/// 资产视图（原型 `#view-asset`）。
///
/// 顺序严格照原型：只读镜像 → 流向账 → 在给你钱/在拿你钱/不进不出 →
/// 新增按钮 → 资产汇总 → 真要用钱能拿出多少。
/// 所有数字现场调 [AzMath] 从明细算出来，页面上不写死任何金额。
class AzAssetView extends StatelessWidget {
  const AzAssetView({
    super.key,
    required this.view,
    required this.actions,
  });

  final AzViewData view;
  final AzViewActions actions;

  @override
  Widget build(BuildContext context) {
    final AzData d = view.data;
    final List<AzAccountMirror> mirrors = AzMath.mirrors(view.accounts);
    final AzFlow flow = AzMath.flow(d);
    final List<AzCashLayer> layers = AzMath.cashLayers(d, view.accounts);
    final List<LiabilityRecord> debts = d.activeLiabilities;
    final List<AssetRecord> all = d.activeAssets;
    final List<AssetRecord> stale = AzMath.staleAssets(d, view.today);
    final List<AzClassSum> byClass = AzMath.byClass(d);

    final Map<String, List<AssetRecord>> groups = <String, List<AssetRecord>>{
      'give': <AssetRecord>[],
      'take': <AssetRecord>[],
      'flat': <AssetRecord>[],
    };
    for (final AssetRecord a in all) {
      final AzFlowTag tag = AzMath.flowTagOf(a, debts);
      final String key = tag.good ? 'give' : (tag.bad ? 'take' : 'flat');
      groups[key]!.add(a);
    }

    List<AssetRecord> pick(String f) => all.where((AssetRecord a) {
          if (f == 'all') return true;
          if (f == 'give') return AzMath.flowTagOf(a, debts).good;
          if (f == 'take') return AzMath.flowTagOf(a, debts).bad;
          if (f == 'flat') {
            final AzFlowTag t = AzMath.flowTagOf(a, debts);
            return !t.good && !t.bad;
          }
          if (f == 'stale') {
            return a.valuedAt != null &&
                view.today.difference(a.valuedAt!).inDays > d.preferences.staleDays;
          }
          if (f == 'A4') {
            return a.assetClass == AssetClass.stock ||
                a.assetClass == AssetClass.fund;
          }
          return a.assetClass.code == f;
        }).toList();

    final List<AssetRecord> filtered = pick(view.filter);
    final Map<String, List<AssetRecord>> shown =
        <String, List<AssetRecord>>{
      'give': filtered.where((AssetRecord a) => groups['give']!.contains(a)).toList(),
      'take': filtered.where((AssetRecord a) => groups['take']!.contains(a)).toList(),
      'flat': filtered.where((AssetRecord a) => groups['flat']!.contains(a)).toList(),
    };

    final double total = AzMath.accountTotal(mirrors) + AzMath.selfAssets(d);
    final double uncounted = all
        .where((AssetRecord a) => !a.counted)
        .fold<double>(
          0,
          (double s, AssetRecord a) =>
              s + AzMath.assetValueOf(a, d.preferences.valuationMode),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ── 快筛：资产按「给不给你钱」────────────────────────────
        _chips(context, all, pick, stale.length),
        // ── A1/A2 只读镜像 ──────────────────────────────────────
        AppFunctionSection(
          title: '钱（记在账户页，这里只看）',
          actionLabel: '去账户页改 ›',
          onAction: actions.goAccounts,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final AzAccountMirror m in mirrors)
                AzMirrorRow(mirror: m, onTap: actions.goAccounts),
            ],
          ),
        ),
        // ── 流向账 ──────────────────────────────────────────────
        const AppFunctionSection(
          title: '每个月，它们是给你钱还是拿你钱',
          child: SizedBox.shrink(),
        ),
        AzFlowCard(
          flow: flow,
          inSub: flow.occasional > 0
              ? '每月都有（另有 ${MoneyFormat.yuan0(flow.occasional)} 偶尔才有，未计）'
              : '每月都有',
          outSub:
              '东西的开销 ${MoneyFormat.yuan0(flow.holdCost)} + 借款利息费用 ${MoneyFormat.yuan0(flow.interest + flow.fee)}',
        ),
        // ── 三组折叠 ────────────────────────────────────────────
        _group(context, 'give', '在给你钱的', shown['give']!, debts, d),
        _group(context, 'take', '在拿你钱的', shown['take']!, debts, d),
        _group(context, 'flat', '不进也不出的', shown['flat']!, debts, d),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: OutlinedButton.icon(
            onPressed: actions.addAsset,
            icon: const Icon(AppIcons.add, size: AppIconSize.small),
            label: const Text('＋ 新增资产'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppLayout.fieldMinHeight),
            ),
          ),
        ),
        // ── 资产汇总 ────────────────────────────────────────────
        AppFunctionSection(
          title: '资产汇总',
          actionLabel: '估值口径：${d.preferences.valuationMode.label} ▾',
          onAction: actions.valuationMode,
          child: AzSummaryRows(
            rows: <AzKeyValueRow>[
              for (final AzClassSum s in byClass)
                AzKeyValueRow(
                  label: '${s.label}（${s.count}）',
                  value: MoneyFormat.yuan0(s.sum),
                ),
              if (uncounted > 0)
                AzKeyValueRow(
                  label: '不算进总账的',
                  value: MoneyFormat.yuan0(uncounted),
                ),
              AzKeyValueRow(
                label: '除了钱以外的东西一共',
                value: MoneyFormat.yuan0(AzMath.selfAssets(d)),
                total: true,
              ),
              AzKeyValueRow(
                label: '加上卡里的和动不了的',
                value: MoneyFormat.yuan0(total),
                total: true,
              ),
            ],
          ),
        ),
        // ── 真要用钱能拿出多少 ──────────────────────────────────
        const AppFunctionSection(
          title: '真要用钱，能拿出多少',
          child: SizedBox.shrink(),
        ),
        AzCashLayers(layers: layers, total: total <= 0 ? 1 : total),
        AzHint('换成现金大概还要扣 ${MoneyFormat.yuan0(AzMath.exitCost(d))}（估算）。'),
        if (stale.isNotEmpty)
          AzHint('${stale.length} 样的价很久没更新，总数可能不准。'),
        Text(
          '共 ${all.length} 项 · ${MoneyFormat.yuan0(total)}',
          style: context.appText.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _chips(
    BuildContext context,
    List<AssetRecord> all,
    List<AssetRecord> Function(String) pick,
    int staleCount,
  ) {
    final List<List<String>> chips = <List<String>>[
      <String>['all', '全部', '${all.length}'],
      <String>['give', '给你钱', '${pick('give').length}'],
      <String>['take', '拿你钱', '${pick('take').length}'],
      <String>['A7', '房子', '${pick('A7').length}'],
      <String>['A4', '股票基金', '${pick('A4').length}'],
      <String>['stale', '很久没更新价', '$staleCount'],
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

  Widget _group(
    BuildContext context,
    String key,
    String label,
    List<AssetRecord> items,
    List<LiabilityRecord> debts,
    AzData d,
  ) {
    final double sum = items.fold<double>(
      0,
      (double s, AssetRecord a) =>
          s + AzMath.assetValueOf(a, d.preferences.valuationMode),
    );
    return AzGroupSection(
      label: label,
      count: items.length,
      sumText: MoneyFormat.yuan0(sum),
      collapsed: view.collapsed[key] ?? false,
      onToggle: () => actions.toggleGroup(key),
      sumPositive: key == 'give',
      children: <Widget>[
        for (final AssetRecord a in items)
          AzAssetCard(
            asset: a,
            valueText: a.counted
                ? MoneyFormat.yuan0(
                    AzMath.assetValueOf(a, d.preferences.valuationMode),
                  )
                : '不算进总账',
            tag: AzMath.flowTagOf(a, debts),
            staleText: a.valuedAt == null
                ? '按买入时算'
                : '${view.today.difference(a.valuedAt!).inDays} 天前填的',
            onTap: () => actions.openAsset(a),
          ),
      ],
    );
  }
}
