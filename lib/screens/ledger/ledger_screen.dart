import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:yuan/styles/app_typography.dart';

import '../../database/account/account_record.dart';
import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../screens/commons/function/app_floating_actions.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/home/app_home_page.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../service/account_controller.dart';
import '../../service/ledger/az_controller.dart';
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
/// 重复信息。首屏第一块直接是「真正属于你的钱」，视觉重心落在数字上。
/// 【职责边界】资债只做记录：月收入、应急金月数、物价假设这类参数是
/// 情境设计（8.2 / 13.2）的输入，月末快照属分析（13.12），都不在本页
/// 录入也不展示；右上角只留搜索一个动作，新增在右下角悬浮按钮。
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

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
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

  /// 【新增两步：先选类型，再只填这一类专属字段】工作逻辑：
  ///   ① 点右下角「新增资产 / 新增欠款」→ 弹一排图标（CategorySheetContent，
  ///      契约第 5 条）选一次大类 / 类型，6.1 与 7.2 要求「只选一次」；
  ///   ② 把选中的枚举传给表单的 presetClass / presetType，表单构造期就定死
  ///      items，运行期不换字段 —— 静态优先，没有第二套状态；
  ///   ③ 用户关掉选择弹层（返回 null）就什么都不做；异步回来先查 mounted，
  ///      避免弹层还没关、页面已销毁时继续 push。
  /// 这是本轮唯一的跨帧流程，不是状态字段；页面本身仍只有原有 4 处 state。
  Future<void> _addAsset(BuildContext context) async {
    final AssetClass? cls = await showAzAssetClassSheet(context);
    if (cls == null || !context.mounted) return;
    await showAzAssetSheet(context, presetClass: cls);
  }

  Future<void> _addDebt(BuildContext context) async {
    final LiabilityType? type = await showAzLiabilityTypeSheet(context);
    if (type == null || !context.mounted) return;
    await showAzLiabilitySheet(context, presetType: type);
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
        ? '按买入价'
        : '按最新价';
    final String staleNote = stale.isEmpty
        ? ''
        : '${stale.length} 样价待更新。';
    final String caption = netWorth >= 0
        ? '减掉欠款'
        : '倒欠 ${MoneyFormat.yuan0(-netWorth)}';

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
      // 新增入口固定在右下角：单按钮形态直接显示一枚正圆主色 FAB，
      // 只画图标、名称走 tooltip（hover / 长按），不占顶部动作行、
      // 不埋在滚动列表里。随 tab 换动作，仍是「一个功能一个入口」。
      floating: AppFloatingActions(
        actions: <AppFloatingAction>[
          AppFloatingAction(
            label: _tab == _AzTab.asset ? '新增资产' : '新增欠款',
            icon: AppIcons.add,
            emphasized: true,
            onPressed: _tab == _AzTab.asset
                ? viewActions.addAsset
                : viewActions.addDebt,
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          tooltip: '搜索',
          icon: const Icon(AppIcons.search),
          onPressed: () => setState(() {
            _searchVisible = !_searchVisible;
            if (!_searchVisible) _search.clear();
          }),
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
          // 给右下角 FAB 让出高度，滚动到底时最后一行不被压住。
          const SizedBox(
            height: AppComponentSize.fabSize + AppSpacing.md * 2,
          ),
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
            hintText: '搜索',
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
            const AzSmallEmpty('没搜到'),
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
                  '年化 ${(AzMath.realAnnualRate(x) * 100).toStringAsFixed(1)}%',
              costText: x.monthlyCost > 0
                  ? '成本 ${MoneyFormat.yuan0(x.monthlyCost)}'
                  : '无利息',
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
        addAsset: () => unawaited(_addAsset(context)),
        addDebt: () => unawaited(_addDebt(context)),
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
        filterChanged: (String f) => setState(() => _filter = f),
        toggleGroup: (String g) => setState(
          () => _collapsed[g] = !(_collapsed[g] ?? false),
        ),
      );
}
