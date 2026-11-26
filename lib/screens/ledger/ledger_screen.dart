import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../database/ledger/az_schema.dart';
import '../../screens/commons/empty/app_empty_state.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/home/app_home_page.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../service/ledger/az_controller.dart';
import '../../styles/app_decorations.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import 'az_sheets.dart';
import 'az_view_contract.dart';
import 'widgets/az_cards.dart';

// ── 页面私有尺寸与文案（与账户页同一套全局令牌）─────────────────
const double _kSearchHeight = 40;
const double _kClearSize = 32;
const double _kChipGap = AppSpacing.xs;

const String _kSearchHint = '搜索名称、类型或说明';
const String _kSearchGroup = '搜索结果';
const String _kEmptyTitle = '还没有添加记录';
const String _kEmptyDescription = '点右上角 ＋ 新增，把房子、股票、借进借出的钱都记进来。';
const String _kSearchEmptyTitle = '没找到匹配的记录';
const String _kSearchEmptyDescription = '换个关键词，或者点「全部」查看其它类型组。';
const String _kFilterEmptyTitle = '这一组还没有记录';
const String _kFilterEmptyDescription = '点右上角 ＋ 新增，或切回「全部」查看其它类型组。';
const String _kFootNote =
    '这里只统计自己登记的资产与负债；账户余额在「账户」页单独看。'
    '挂卡分期的剩余本金已含在信用卡欠款里，不重复相加。';

/// 资产 / 负债两段 tab，与账户页的类型快筛是两套不同控件（各管一件事）。
enum _AzTab { asset, liability }

/// 资债 Home 页：按「类型组」分类整理。
///
/// ── 结构嵌套（与账户页 AccountsScreen 共用同一套结构层）──────────
/// ```
/// AppShell（全局唯一 Scaffold + 断点导航）
///  └ AppHomePage（Home 页专用：无标题、无返回、右上角只有 ＋）
///     ├ hero   → AppSummaryHero（通用件；数字随资产 / 负债 tab 切换）
///     └ child  → AppSegmentTabs → 搜索栏 → 类型组快筛 chips
///                  → 可折叠分组（箭头 / 段名 / 数量徽章 / 段内合计）
///                  → 底部说明
/// ```
/// 分区结构件各自管左右 16dp 留白，页壳只管上下留白，避免双重缩进。
/// 卡片外壳、图标徽章、搜索框、chips、分组头全部复用账户页的全局组件，
/// 本页不写任何硬编码颜色 / 字号 / 圆角。
///
/// ── 动态逻辑（与账户页同源的 5 处状态）──────────────────────────
/// ① 数据源：`context.watch<AzController>()` 的内存快照，页面不复制列表、不查库；
/// ② tab：点资产 / 负债 → setState → 换 side，同时把类型组快筛重置为 all；
/// ③ 快筛：点 chip → setState → `_filteredGroups` 只留该组；
/// ④ 搜索：输入 → setState 存关键词 → 只影响列表、不影响顶部统计；
///    搜索时强制展开并合并成「搜索结果」一段（与账户页一致）；
/// ⑤ 折叠：点分组头 → setState 把组键加入 / 移出 `_collapsed`，只在内存。
///
/// 【所属模块】screens/ledger · 资债 Home
/// 【实现功能】按类型组分类整理展示资产 / 负债、摘要卡、搜索、快筛、折叠与新增入口；写操作一律交给 AzWriteController。
/// 【使用限制】页面不 import DAO、不直接写库、不持有第二份数据副本；新增流程异步回来必须判 mounted。
/// 【入参与结果】无构造入参；build 返回 AppHomePage；动作回调收 groupKey / id / keyword，新增返回 Future<void>。
/// 【异常与调用方处理】createEntry 的异常由本页 try/catch 后用 SnackBar 提示，保持旧快照不跳详情；读库失败由 AzController.load 上抛，页面仍展示旧快照。
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  _AzTab _tab = _AzTab.asset;
  String _filter = 'all';
  String _keyword = '';
  final Set<String> _collapsed = <String>{};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _side => _tab == _AzTab.asset ? 'asset' : 'liability';

  void _clearSearch() {
    _search.clear();
    setState(() => _keyword = '');
  }

  void _toggleGroup(String key) => setState(() {
        if (!_collapsed.remove(key)) _collapsed.add(key);
      });

  static bool _matches(AzRecord r, String kw) {
    if (kw.isEmpty) return true;
    return '${r.text('name')} ${r.text('note')} ${r.text('asset_class')} '
            '${r.text('liability_type')}'
        .toLowerCase()
        .contains(kw);
  }

  /// 新增两步：先按类型组选类型，再声明式动态表单填主表 + 次表。
  /// 【所属模块】screens/ledger · 资债 Home
  /// 【实现功能】选类型 → 填表 → 交给 AzWriteController 同事务落库；失败只提示不跳页。
  /// 【使用限制】异步回来必须判 mounted；spec / draft 为 null 直接结束；不得绕过写入口直调 DAO。
  /// 【入参与结果】无入参；返回 Future<void>，内部全部 await。
  /// 【异常与调用方处理】重名 / CHECK / SQL 异常在此 try/catch 后用 SnackBar 提示「保存失败」。
  Future<void> _add() async {
    final AzTypeSpec? spec = await showAzTypeSheet(context, side: _side);
    if (spec == null || !mounted) return;
    final AzEntryDraft? draft = await showAzEntrySheet(context, spec);
    if (draft == null || !mounted) return;
    try {
      await context.read<AzWriteController>().createEntry(
            spec,
            draft.mainValues,
            draft.subValues,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AzController az = context.watch<AzController>();
    final AzData data = az.data;
    final String kw = _keyword.trim().toLowerCase();
    final bool searching = kw.isNotEmpty;

    final List<AzGroupStat> allGroups =
        _side == 'asset' ? az.assetGroups : az.liabilityGroups;
    final List<AzGroupStat> scoped = _filter == 'all'
        ? allGroups
        : allGroups
            .where((AzGroupStat g) => g.groupKey == _filter)
            .toList(growable: false);

    // 搜索只影响列表、不影响统计：与账户页「统计不受搜索词影响」一致。
    final List<AzGroupStat> matched = scoped.map((AzGroupStat g) {
      final List<AzTypeBlock> blocks = g.typeBlocks.map((AzTypeBlock b) {
        final List<AzRecord> rows = b.rows
            .where((AzRecord r) => _matches(r, kw))
            .toList(growable: false);
        double total = 0;
        for (final AzRecord r in rows) {
          total += AzMath.valueOf(data, r, b.spec);
        }
        return AzTypeBlock(spec: b.spec, rows: rows, total: total);
      }).where((AzTypeBlock b) => b.rows.isNotEmpty).toList(growable: false);
      return AzGroupStat(
        groupKey: g.groupKey,
        label: g.label,
        side: g.side,
        typeBlocks: blocks,
        entryCount: blocks.fold<int>(0, (int p, AzTypeBlock b) => p + b.rows.length),
        total: blocks.fold<double>(0, (double p, AzTypeBlock b) => p + b.total),
      );
    }).where((AzGroupStat g) => !searching || g.entryCount > 0).toList(growable: false);

    // 搜索时合并成一段（账户页同一行为），并强制展开。
    final List<AzGroupStat> groups;
    if (searching && matched.isNotEmpty) {
      final List<AzTypeBlock> blocks = <AzTypeBlock>[
        for (final AzGroupStat g in matched) ...g.typeBlocks,
      ];
      groups = <AzGroupStat>[
        AzGroupStat(
          groupKey: 'search',
          label: _kSearchGroup,
          side: _side,
          typeBlocks: blocks,
          entryCount: blocks.fold<int>(0, (int p, AzTypeBlock b) => p + b.rows.length),
          total: blocks.fold<double>(0, (double p, AzTypeBlock b) => p + b.total),
        ),
      ];
    } else {
      groups = matched;
    }

    final int totalCount = allGroups.fold<int>(
      0,
      (int p, AzGroupStat g) => p + g.entryCount,
    );
    final bool nothingAtAll = totalCount == 0;
    final bool nothingShown = groups.isEmpty ||
        groups.every((AzGroupStat g) => g.entryCount == 0);

    final AzViewData view = AzViewData(
      data: data,
      side: _side,
      keyword: kw,
      groups: groups,
      assetsTotal: AzMath.assetsTotal(data),
      liabilitiesTotal: AzMath.liabilitiesTotal(data),
    );
    final AzViewActions actions = AzViewActions(
      onSideChanged: (String side) => setState(() {
        _tab = side == 'asset' ? _AzTab.asset : _AzTab.liability;
        _filter = 'all';
      }),
      onFilterChanged: (String f) => setState(() => _filter = f),
      toggleGroup: _toggleGroup,
      add: _add,
      open: (int id) {
        if (_side == 'asset') {
          context.push('/ledger/asset/$id');
        } else {
          context.push('/ledger/debt/$id');
        }
      },
      onKeyword: (String v) => setState(() => _keyword = v),
    );

    return AppHomePage(
      // 右上角只放动作，没有标题、没有返回按钮（与账户页一致）。
      actions: <Widget>[
        IconButton(
          icon: const Icon(AppIcons.add),
          tooltip: _side == 'asset' ? '新增资产' : '新增负债',
          onPressed: () => unawaited(actions.add()),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom,
      ),
      hero: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: _hero(context, view),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSegmentTabs<_AzTab>(
            options: const <AppSegmentOption<_AzTab>>[
              AppSegmentOption<_AzTab>(value: _AzTab.asset, label: '资产'),
              AppSegmentOption<_AzTab>(value: _AzTab.liability, label: '负债'),
            ],
            selected: _tab,
            onChanged: (_AzTab v) => actions.onSideChanged(
              v == _AzTab.asset ? 'asset' : 'liability',
            ),
          ),
          _searchField(context, actions),
          const SizedBox(height: AppSpacing.xs),
          _filterChips(context, allGroups, actions),
          const SizedBox(height: AppSpacing.sm),
          if (!az.loaded)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (nothingAtAll)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: AppEmptyState(
                icon: AppIcons.add,
                title: _kEmptyTitle,
                description: _kEmptyDescription,
              ),
            )
          else if (nothingShown)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: AppEmptyState(
                icon: searching ? AppIcons.search : AppIcons.ledger,
                title: searching ? _kSearchEmptyTitle : _kFilterEmptyTitle,
                description: searching
                    ? _kSearchEmptyDescription
                    : _kFilterEmptyDescription,
              ),
            )
          else ...<Widget>[
            for (final AzGroupStat g in groups)
              AzGroupSection(
                key: ValueKey<String>(g.groupKey),
                group: g,
                data: view.data,
                collapsed: searching ? false : _collapsed.contains(g.groupKey),
                onToggle: () => actions.toggleGroup(g.groupKey),
                onTap: (AzRecord r) => actions.open(r.id),
              ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text(_kFootNote, style: context.appText.caption),
            ),
          ],
        ],
      ),
    );
  }

  /// 顶部摘要：同一张通用 AppSummaryHero，按 tab 换 label / 数字 / 口径说明。
  /// 与账户页一样只从 context.tokens 取语义色，换主题自动重算。
  Widget _hero(BuildContext context, AzViewData view) {
    final AppThemeTokens tokens = context.tokens;
    if (view.side == 'liability') {
      return AppSummaryHero(
        label: '待还合计',
        value: MoneyFormat.yuan0(view.liabilitiesTotal),
        caption: '只算贷款与不挂卡分期；信用卡欠款在账户页看。',
        accent: tokens.expense,
        secondary: <AppInfoItem>[
          AppInfoItem(
            label: '自登记资产',
            value: MoneyFormat.yuan0(view.assetsTotal),
          ),
          AppInfoItem(
            label: '净资产',
            value: MoneyFormat.yuan0(view.assetsTotal - view.liabilitiesTotal),
          ),
        ],
      );
    }
    return AppSummaryHero(
      emphasized: true,
      label: '自登记资产合计',
      value: MoneyFormat.yuan0(view.assetsTotal),
      caption: '按当前估值 / 成本合计，不含账户余额。',
      secondary: <AppInfoItem>[
        AppInfoItem(
          label: '待还合计',
          value: MoneyFormat.yuan0(view.liabilitiesTotal),
        ),
        AppInfoItem(
          label: '净资产',
          value: MoneyFormat.yuan0(view.assetsTotal - view.liabilitiesTotal),
        ),
      ],
    );
  }

  /// 搜索框：与账户页 `_searchField` 逐行同构（40dp、全局 field 装饰、
  /// TextField 自己不画边框，显式覆盖 constraints 免得被全局 56dp 撑高）。
  Widget _searchField(BuildContext context, AzViewActions actions) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        height: _kSearchHeight,
        decoration: AppDecorations.field(context),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(AppIcons.search,
                size: AppIconSize.small, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: actions.onKeyword,
                textInputAction: TextInputAction.search,
                style: context.appText.body,
                decoration: InputDecoration(
                  isCollapsed: true,
                  constraints: const BoxConstraints(),
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: _kSearchHint,
                  hintStyle: context.appText.hint,
                ),
              ),
            ),
            if (_keyword.isNotEmpty)
              GestureDetector(
                onTap: _clearSearch,
                child: SizedBox(
                  width: _kClearSize,
                  height: _kClearSize,
                  child: Icon(AppIcons.clear,
                      size: AppIconSize.small, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 类型组快筛：与账户页 `_filterChips` 同一套 ChoiceChip（圆角 / 选中底
  /// 全来自全局 ChipThemeData），数量与标签合成一个文本，不写任何颜色。
  Widget _filterChips(
    BuildContext context,
    List<AzGroupStat> allGroups,
    AzViewActions actions,
  ) {
    final int allCount = allGroups.fold<int>(
      0,
      (int p, AzGroupStat g) => p + g.entryCount,
    );
    final List<({String key, String label, int count})> chips =
        <({String key, String label, int count})>[
      (key: 'all', label: '全部', count: allCount),
      for (final AzGroupStat g in allGroups)
        (key: g.groupKey, label: g.label, count: g.entryCount),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < chips.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: _kChipGap),
            ChoiceChip(
              avatar: Icon(
                chips[i].key == 'all' ? AppIcons.ledger : AppIcons.category,
                size: AppIconSize.small,
              ),
              label: Text('${chips[i].label} ${chips[i].count}'),
              selected: _filter == chips[i].key,
              showCheckmark: false,
              onSelected: (bool _) => actions.onFilterChanged(chips[i].key),
            ),
          ],
        ],
      ),
    );
  }
}
