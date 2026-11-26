import 'package:material_ui/material_ui.dart';

import '../../../database/ledger/az_math.dart';
import '../../../database/ledger/az_record.dart';
import '../../../styles/theme_tokens.dart';

/// home 页顶部摘要卡：自登记资产 / 负债 / 净资产。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】展示资产合计、负债合计与净资产三个数字，并标注「仅自登记资产，不含账户余额」。
/// 【使用限制】纯展示，不读库、不写库；金额由调用方从 AzMath 算好传入。
/// 【入参与结果】构造收 assets / liabilities / netWorth；build 返回 Widget。
/// 【异常与调用方处理】不抛异常；负值由调用方文案处理，本卡只原样显示。
class AzSummaryCard extends StatelessWidget {
  const AzSummaryCard({
    super.key,
    required this.assets,
    required this.liabilities,
    required this.netWorth,
  });

  final double assets;
  final double liabilities;
  final double netWorth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('仅自登记资产（不含账户余额）',
                style: TextStyle(fontSize: 12, color: colors.outline)),
            const SizedBox(height: AppSpacing.xs),
            Text('净资产 ${netWorth.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.primary)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('资产 ${assets.toStringAsFixed(2)}'),
                Text('负债 ${liabilities.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个「类型组」分区：组标题可折叠，组内按具体类型分块。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】渲染一个 AzGroupStat：组名 + 条目数 + 金额小计，展开后按成员类型逐块列出条目。
/// 【使用限制】纯展示；折叠状态由 home 页持有；onTap 只用于跳详情，不得写库。
/// 【入参与结果】构造收 group / data / collapsed / onToggle / onTap；build 返回 Widget。
/// 【异常与调用方处理】不抛异常；空组由本组件渲染「暂无记录」。
class AzGroupSection extends StatelessWidget {
  const AzGroupSection({
    super.key,
    required this.group,
    required this.data,
    required this.collapsed,
    required this.onToggle,
    required this.onTap,
  });

  final AzGroupStat group;
  final AzData data;
  final bool collapsed;
  final VoidCallback onToggle;
  final void Function(AzRecord row) onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Text(group.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${group.entryCount} 条 · 合计 ${group.total.toStringAsFixed(2)}'),
            trailing: Text(collapsed ? '展开' : '收起'),
            onTap: onToggle,
          ),
          if (!collapsed) ...<Widget>[
            const Divider(height: 1),
            for (final AzTypeBlock block in group.typeBlocks)
              AzTypeBlockView(block: block, data: data, onTap: onTap),
          ],
        ],
      ),
    );
  }
}

/// 组内一个具体类型（如「A4（股票）」）的条目块。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】渲染一个类型的中文名、条目数与小计，并逐条列出该类型的记录。
/// 【使用限制】纯展示；金额经 AzMath.valueOf 读次表，不写库。
/// 【入参与结果】构造收 block / data / onTap；build 返回 Widget。
/// 【异常与调用方处理】不抛异常；类型未登记时 data.typOf 返回 null，本组件按 0 金额展示。
class AzTypeBlockView extends StatelessWidget {
  const AzTypeBlockView({
    super.key,
    required this.block,
    required this.data,
    required this.onTap,
  });

  final AzTypeBlock block;
  final AzData data;
  final void Function(AzRecord row) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('${block.spec.code}（${block.spec.label}）',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${block.rows.length} 条 · ${block.total.toStringAsFixed(2)}'),
            ],
          ),
          if (block.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text('暂无记录', style: TextStyle(fontSize: 12)),
            )
          else
            for (final AzRecord r in block.rows)
              AzEntryTile(
                row: r,
                amount: AzMath.valueOf(data, r, block.spec),
                onTap: () => onTap(r),
              ),
        ],
      ),
    );
  }
}

/// 一条资产 / 负债的列表行。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】显示名称、说明、金额与（负债侧）状态，点击交给 home 页跳详情。
/// 【使用限制】纯展示；不写库；金额只用于展示。
/// 【入参与结果】构造收 row / amount / onTap；build 返回 Widget。
/// 【异常与调用方处理】不抛异常；名称缺失显示「未命名」。
class AzEntryTile extends StatelessWidget {
  const AzEntryTile({
    super.key,
    required this.row,
    required this.amount,
    required this.onTap,
  });

  final AzRecord row;
  final double amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = row.text('name').isEmpty ? '未命名' : row.text('name');
    final String status = row.text('status');
    return ListTile(
      dense: true,
      title: Text(name),
      subtitle: Text(
        <String>[
          if (row.text('note').isNotEmpty) row.text('note'),
          if (status.isNotEmpty) '状态：$status',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(amount.toStringAsFixed(2)),
      onTap: onTap,
    );
  }
}
