import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:yuan/database/ledger/az_schema.dart';

import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../screens/commons/home/app_home_page.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../service/ledger/az_controller.dart';
import '../../styles/theme_tokens.dart';
import 'az_sheets.dart';
import 'az_view_contract.dart';
import 'widgets/az_cards.dart';

/// 资债 Home 页：按「类型组」分类整理。
///
/// 资产 4 组（钱借出去 / 投资类 / 实物类 / 经营与其他）、负债 2 组
/// （贷款 / 分期），组内再按具体类型分块；分组定义唯一真源在 AzSchema.groups。
/// 旧实现的「在给你钱的 / 在拿你钱的 / 不进也不出的」三组现金流视图已删除。
/// 【所属模块】screens/ledger · 资债 Home
/// 【实现功能】展示按类型组分类整理的资产 / 负债列表、摘要卡、搜索、折叠与新增入口；写操作一律交给 AzWriteController。
/// 【使用限制】页面不 import DAO、不直接写库、不持有第二份数据副本；数据全部 watch AzController；新增流程异步回来必须判 mounted。
/// 【入参与结果】无构造入参；build 返回 AppHomePage；动作回调收 groupKey / id / keyword，新增返回 Future<void>。
/// 【异常与调用方处理】AzWriteController.createEntry 的异常由本页 try/catch 后用 SnackBar 提示，保持旧快照不跳详情；读库失败由 AzController.load 上抛，页面仍展示旧快照。
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _side = 'asset';
  String _keyword = '';
  bool _searchVisible = false;
  final Map<String, bool> _collapsed = <String, bool>{};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 【所属模块】screens/ledger · 资债 Home
  /// 【实现功能】新增两步：先按类型组选类型，再动态表单填主表 + 次表，最后交给写入口同事务落库。
  /// 【使用限制】异步回来必须判 mounted；spec / draft 为 null 直接结束；不得绕过 AzWriteController 直接调 DAO。
  /// 【入参与结果】无入参；返回 Future<void>，调用方（按钮）不 await 结果但本方法内部全部 await。
  /// 【异常与调用方处理】写库异常（重名 / CHECK / SQL）在此 try/catch 后用 SnackBar 提示「保存失败」，不吞异常后跳详情。
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

  /// 【所属模块】screens/ledger · 资债 Home
  /// 【实现功能】按搜索词过滤每个类型块的条目，返回新的 AzGroupStat 列表（不改原快照）。
  /// 【使用限制】只读派生；keyword 为空时原样返回；不写库、不通知。
  /// 【入参与结果】收 groups 与 keyword；返回 List<AzGroupStat>。
  /// 【异常与调用方处理】不抛异常；调用方按空结果渲染空态。
  List<AzGroupStat> _filtered(List<AzGroupStat> groups, String keyword) {
    if (keyword.isEmpty) return groups;
    final String k = keyword.toLowerCase();
    return groups.map((AzGroupStat g) {
      final List<AzTypeBlock> blocks = g.typeBlocks.map((AzTypeBlock b) {
        final List<AzRecord> rows = b.rows
            .where((AzRecord r) =>
                r.text('name').toLowerCase().contains(k) ||
                r.text('note').toLowerCase().contains(k))
            .toList(growable: false);
        return AzTypeBlock(spec: b.spec, rows: rows, total: b.total);
      }).toList(growable: false);
      final int count = blocks.fold<int>(0, (int p, AzTypeBlock b) => p + b.rows.length);
      return AzGroupStat(
        groupKey: g.groupKey,
        label: g.label,
        side: g.side,
        typeBlocks: blocks,
        entryCount: count,
        total: g.total,
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AzController az = context.watch<AzController>();
    final AzData data = az.data;
    final List<AzGroupStat> groups =
        _filtered(_side == 'asset' ? az.assetGroups : az.liabilityGroups, _keyword);

    final AzViewActions actions = AzViewActions(
      toggleGroup: (String key) => setState(() {
        _collapsed[key] = !(_collapsed[key] ?? false);
      }),
      add: _add,
      open: (int id) {
        if (_side == 'asset') {
          context.push('/ledger/asset/$id');
        } else {
          context.push('/ledger/debt/$id');
        }
      },
      onKeyword: (String v) => setState(() => _keyword = v.trim()),
    );

    return AppHomePage(
      padding: const EdgeInsets.fromLTRB(0, AppLayout.pageTop, 0, AppLayout.pageBottom),
      actions: <Widget>[
        IconButton(
          tooltip: '搜索',
          icon: const Icon(AppIcons.search),
          onPressed: () => setState(() {
            _searchVisible = !_searchVisible;
            if (!_searchVisible) {
              _search.clear();
              _keyword = '';
            }
          }),
        ),
      ],
      floating: FloatingActionButton(
        tooltip: _side == 'asset' ? '新增资产' : '新增负债',
        onPressed: actions.add,
        child: const Icon(AppIcons.add),
      ),
      hero: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AzSummaryCard(
          assets: AzMath.assetsTotal(data),
          liabilities: AzMath.liabilitiesTotal(data),
          netWorth: AzMath.netWorth(data),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_searchVisible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(hintText: '按名称 / 说明搜索'),
                onChanged: actions.onKeyword,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('资产'),
                  selected: _side == 'asset',
                  onSelected: (_) => setState(() => _side = 'asset'),
                ),
                const SizedBox(width: AppSpacing.xs),
                ChoiceChip(
                  label: const Text('负债'),
                  selected: _side == 'liability',
                  onSelected: (_) => setState(() => _side = 'liability'),
                ),
              ],
            ),
          ),
          if (!az.loaded)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final AzGroupStat g in groups)
              AzGroupSection(
                key: ValueKey<String>(g.groupKey),
                group: g,
                data: data,
                collapsed: _collapsed[g.groupKey] ?? false,
                onToggle: () => actions.toggleGroup(g.groupKey),
                onTap: (AzRecord r) => actions.open(r.id),
              ),
        ],
      ),
    );
  }
}
