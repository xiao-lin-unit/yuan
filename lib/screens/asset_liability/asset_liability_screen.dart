import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:yuan/styles/app_typography.dart';

import '../../database/account/account_record.dart';
import '../../database/asset_liability/az_math.dart';
import '../../database/asset_liability/az_record.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/home/app_home_page.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../service/account_controller.dart';
import '../../service/az_controller.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import 'az_asset_view.dart';
import 'az_liability_view.dart';
import 'az_sheets.dart';
import 'az_view_contract.dart';
import 'widgets/az_cards.dart';

/// 资债页（5 个 Home 页之一，底导 / rail 直接打开）。
///
/// 【为什么用 AppHomePage】约定：Home 页不渲染 AppBar、不渲染标题、
/// 不渲染返回按钮 —— 导航栏已经说明这是哪个页面，顶上再放一行标题是
/// 重复信息。首屏第一块直接是「真正属于你的钱」，视觉重心落在数字上；
/// 右上角只保留纯动作行（搜索 / 口径设置 / 月末存一次数）。
///
/// 【动态状态，工作逻辑写清楚】为什么动态：视图、快筛、搜索词、分组折叠
/// 都是用户点击后才有的状态，构造期定不死。全部收在 StatefulWidget 里：
///   ① 点 tab → `setState` 换视图，同时把快筛重置为 all、收起搜索
///      （否则两个视图会同时露出来，原型 switchAZ 里的坑）；
///   ② 搜索框输入 → `setState` 更新 keyword → 主区切成合并搜索结果；
///      ✕ 清空后回到原视图；
///   ③ 分组折叠、快筛、所有弹层回调都只改这里的 state 或调 Sheet；
///   ④ 数据本身**不在这里存副本**：`context.watch` 两个共享账本，
///      写操作由 AzWriteController 先落库再通知，页面自动重建。
/// 没有 Notifier 嵌套、没有跨帧注册、没有第二份数据。
enum _AzTab { asset, liability }

class AssetLiabilityScreen extends StatefulWidget {
  const AssetLiabilityScreen({super.key});

  @override
  State<AssetLiabilityScreen> createState() => _AssetLiabilityScreenState();
}

class _AssetLiabilityScreenState extends State<AssetLiabilityScreen> {
  _AzTab _tab = _AzTab.asset;
  String _filter = 'all';
  bool _searchVisible = false;
  final TextEditingController _search = TextEditingController();
  final Map<String, bool> _collapsed = <String, bool>{
    'give': false,
    'take': false,
    'flat': true,
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 两个共享账本一起 watch：账户余额一变，家底账的只读镜像当场跟着变，
    // 不需要 AzController 再监听一次（避免一处变化通知两遍）。
    final AccountController accounts = context.watch<AccountController>();
    final AzController az = context.watch<AzController>();
    final List<AccountRecord> accountRows = accounts.all;
    final AzData d = az.data;
    final DateTime today = az.today;

    final List<AzAccountMirror> mirrors = AzMath.mirrors(accountRows);
    final double netWorth = AzMath.netWorth(d, accountRows);
    final double selfAssets = AzMath.selfAssets(d);
    final double assetsTotal = AzMath.accountTotal(mirrors) + selfAssets;
    final double debtsTotal = AzMath.debtsTotal(d, accountRows);
    final AzFlow flow = AzMath.flow(d);
    final List<AzCashLayer> layers = AzMath.cashLayers(d, accountRows);
    final double cashNow = layers[0].amount + layers[1].amount;
    final List<AssetRecord> stale = AzMath.staleAssets(d, today);
    final int contingentCount = d.activeContingents
        .where((ContingentRecord c) => c.kind == ContingentKind.contingent)
        .length;

    final String valuationNote = d.preferences.valuationMode == ValuationMode.cost
        ? '按买入时算（保守口径），没算涨跌；没更新过价的持仓显示「还没卖，先不算赚没赚」。'
        : '按你自己填的最新价算，软件不联网，不会自动变；这不是查来的准数。';
    final String staleNote = stale.isEmpty
        ? ''
        : '有 ${stale.length} 样的价是很久以前填的（'
            '${stale.map((AssetRecord a) => a.name).join('、')}），总数可能不准。';
    final String caption = netWorth >= 0
        ? '把东西全加起来，再减去欠的；欠的都还完，还剩这么多。'
        : '欠的比手上有的还多 ${MoneyFormat.yuan0(-netWorth)}。'
            '刚工作、还在读书时欠着助学贷很正常，别只看这个数。';

    final AzViewData viewData = AzViewData(
      data: d,
      accounts: accountRows,
      today: today,
      filter: _filter,
      collapsed: _collapsed,
    );
    final AzViewActions viewActions = _actions(context, d, accountRows, today);

    final String keyword = _search.text.trim();
    return AppHomePage(
      // 子组件自己负责 md 水平留白，这里只给上下节奏，避免左右叠两遍。
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom,
      ),
      actions: <Widget>[
        IconButton(
          tooltip: '搜资产、负债、类型、备注',
          icon: const Icon(AppIcons.search),
          onPressed: () => setState(() {
            _searchVisible = !_searchVisible;
            if (!_searchVisible) _search.clear();
          }),
        ),
        IconButton(
          tooltip: '填每月到手的钱 / 必须花的钱 / 应急金',
          icon: const Icon(AppIcons.edit),
          onPressed: () => unawaited(showAzPreferenceSheet(context)),
        ),
        IconButton(
          tooltip: '按月末存一次数',
          icon: const Icon(AppIcons.calendarMonth),
          onPressed: () => unawaited(showAzSnapshotSheet(context)),
        ),
      ],
      hero: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AzNetWorthCard(
          netWorth: netWorth,
          caption: caption,
          cashNow: cashNow,
          monthlyIn: flow.totalIn,
          monthlyOut: flow.totalOut,
          mirrors: mirrors,
          selfAssets: selfAssets,
          assetsTotal: assetsTotal,
          debtsTotal: debtsTotal,
          contingentCount: contingentCount,
          valuationNote: valuationNote,
          staleNote: staleNote,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_searchVisible) _searchBox(context),
          if (keyword.isEmpty) ...<Widget>[
            AppSegmentTabs<_AzTab>(
              options: const <AppSegmentOption<_AzTab>>[
                AppSegmentOption<_AzTab>(value: _AzTab.asset, label: '资产'),
                AppSegmentOption<_AzTab>(
                  value: _AzTab.liability,
                  label: '负债',
                ),
              ],
              selected: _tab,
              onChanged: (_AzTab v) => setState(() {
                _tab = v;
                _filter = 'all';
                _searchVisible = false;
                _search.clear();
              }),
            ),
            if (_tab == _AzTab.asset)
              AzAssetView(view: viewData, actions: viewActions)
            else
              AzLiabilityView(view: viewData, actions: viewActions),
          ] else
            _searchResults(context, keyword, d),
        ],
      ),
    );
  }

  Widget _searchBox(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: TextField(
          controller: _search,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜资产、负债、类型、备注',
            prefixIcon: const Icon(AppIcons.search, size: AppIconSize.medium),
            suffixIcon: IconButton(
              tooltip: '清空',
              icon: const Icon(AppIcons.clear, size: AppIconSize.small),
              onPressed: () => setState(() => _search.clear()),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      );

  Widget _searchResults(BuildContext context, String keyword, AzData d) {
    final String kw = keyword.toLowerCase();
    final List<AssetRecord> assets = d.activeAssets
        .where((AssetRecord a) =>
            (a.name + a.assetClass.label + a.code + a.intention + a.note)
                .toLowerCase()
                .contains(kw))
        .toList();
    final List<LiabilityRecord> debts = d.activeLiabilities
        .where((LiabilityRecord x) =>
            (x.name + x.type.label + x.purpose.label + x.note)
                .toLowerCase()
                .contains(kw))
        .toList();
    final AzViewActions a = _actions(context, d, context.read<AccountController>().all, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '搜到 ${assets.length + debts.length} 条',
                  style: context.appText.sectionHeader,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _search.clear()),
                child: const Text('清空'),
              ),
            ],
          ),
          if (assets.isEmpty && debts.isEmpty)
            const AzSmallEmpty('没搜到，换个名字或类型试试'),
          for (final AssetRecord x in assets) ...<Widget>[
            AzAssetCard(
              asset: x,
              valueText: x.counted
                  ? MoneyFormat.yuan0(
                      AzMath.assetValueOf(x, d.preferences.valuationMode),
                    )
                  : '不算进总账',
              tag: AzMath.flowTagOf(x, d.activeLiabilities),
              staleText: x.assetClass.label,
              onTap: () => a.openAsset(x),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          for (final LiabilityRecord x in debts) ...<Widget>[
            AzDebtCard(
              debt: x,
              rateText:
                  '实际一年 ${(AzMath.realAnnualRate(x) * 100).toStringAsFixed(1)}%',
              costText: x.monthlyCost > 0
                  ? '每月白给 ${MoneyFormat.yuan0(x.monthlyCost)}'
                  : '这个月不产生利息',
              leverageText: '',
              subText: x.purpose.label,
              onTap: () => a.openDebt(x),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  AzViewActions _actions(
    BuildContext context,
    AzData d,
    List<AccountRecord> accounts,
    DateTime today,
  ) =>
      AzViewActions(
        openAsset: (AssetRecord x) =>
            unawaited(context.push('/ledger/asset/${x.id}')),
        openDebt: (LiabilityRecord x) =>
            unawaited(context.push('/ledger/debt/${x.id}')),
        openContingent: (ContingentRecord c) =>
            unawaited(showAzContingentSheet(context, existing: c, kind: c.kind)),
        addAsset: () => unawaited(showAzAssetSheet(context)),
        addDebt: () => unawaited(showAzLiabilitySheet(context)),
        addContingent: () => unawaited(
          showAzContingentSheet(
            context,
            kind: ContingentKind.contingent,
          ),
        ),
        addInsured: () => unawaited(
          showAzContingentSheet(
            context,
            kind: ContingentKind.insured,
          ),
        ),
        valuationMode: () => unawaited(
          showAzValuationModeSheet(context, d.preferences.valuationMode),
        ),
        leverage: () => unawaited(showAzLeverageSheet(context)),
        gap: () => unawaited(showAzGapSheet(context)),
        payoff: () => unawaited(showAzPayoffSheet(context)),
        goAccounts: () => context.go('/accounts'),
        ratioLevel: () => unawaited(
          showAzDebtRatioSheet(context, d.preferences.debtRatioLevel),
        ),
        filterChanged: (String f) => setState(() => _filter = f),
        toggleGroup: (String g) => setState(
          () => _collapsed[g] = !(_collapsed[g] ?? false),
        ),
      );
}
