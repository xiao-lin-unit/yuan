import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/ledger/az_record.dart';
import '../../database/ledger/az_schema.dart';
import '../../service/ledger/az_controller.dart';
import '../../styles/theme_tokens.dart';
import 'az_sheets.dart';

/// 把一条记录渲染成只读字段列表。
/// 【所属模块】screens/ledger · 详情
/// 【实现功能】按 AzSchema 列清单逐行显示字段名与值，供资产 / 负债详情复用。
/// 【使用限制】纯展示；不写库；不解析金额语义。
/// 【入参与结果】收 record；返回 Widget。
/// 【异常与调用方处理】不抛异常；空值显示 '—'。
Widget azRecordFields(AzRecord record) {
  final List<AzColumn> cols = AzSchema.columnsFor(record.table);
  if (cols.isEmpty) return const Text('该表未登记列');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final AzColumn c in cols)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(c.label, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  (record.fields[c.name] ?? '—').toString(),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// 列出与主表行关联的附属表记录（按 asset_id / liability_id 过滤）。
/// 【所属模块】screens/ledger · 详情
/// 【实现功能】遍历 AzSchema.allTables 中该侧的附属表，按外键筛出属于本条主表记录的行，按表分块展示。
/// 【使用限制】纯展示；附表只按外键过滤，不做金额计算；次表单独由调用方展示。
/// 【入参与结果】收 data / mainId / side / subTable；返回 Widget。
/// 【异常与调用方处理】不抛异常；无附属记录时显示「暂无附属记录」。
Widget azAttachedRows(AzData data, int mainId, String side, String subTable) {
  final String fk = side == 'asset' ? 'asset_id' : 'liability_id';
  final String prefix = side == 'asset' ? 'az_asset_' : 'az_liability_';
  final List<Widget> blocks = <Widget>[];
  for (final String table in AzSchema.allTables) {
    if (!table.startsWith(prefix) || table == subTable) continue;
    if (AzSchema.bySubTable(table) != null) continue;
    final List<AzRecord> rows = data.rowsOf(table)
        .where((AzRecord r) => r.intOf(fk) == mainId)
        .toList(growable: false);
    if (rows.isEmpty) continue;
    blocks.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(table, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final AzRecord r in rows) azRecordFields(r),
        ],
      ),
    ));
  }
  if (blocks.isEmpty) return const Text('暂无附属记录');
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks);
}

/// 资产详情页：主表 + 对应次表 + 全部附属记录。
/// 【所属模块】screens/ledger · 详情
/// 【实现功能】按 assetId 从共享账本取主表行，显示主表字段、次表字段与附属表记录，并提供软删入口。
/// 【使用限制】页面不读库、不写库；删除走 AzWriteController（内部经 LifecycleService 同事务）；assetId 无效时展示空态。
/// 【入参与结果】构造收 assetId（由路由 /ledger/asset/:id 传入）；build 返回 Scaffold。
/// 【异常与调用方处理】删除异常由 AzWriteController 上抛，本页 try/catch 后用 SnackBar 提示；不吞异常后返回上一页。
class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({super.key, required this.assetId});

  final int assetId;

  @override
  Widget build(BuildContext context) {
    final AzController az = context.watch<AzController>();
    final AzData data = az.data;
    AzRecord? found;
    for (final AzRecord r in data.assets) {
      if (r.id == assetId) {
        found = r;
        break;
      }
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资产详情')),
        body: const Center(child: Text('记录不存在或已删除')),
      );
    }
    final AzRecord row = found;
    final AzTypeSpec? spec = data.typOf(row);
    final AzRecord? sub = spec == null ? null : data.subFor(row.id, spec.subTable);

    return Scaffold(
      appBar: AppBar(title: Text(row.text('name'))),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('主表 az_assets', style: const TextStyle(fontWeight: FontWeight.w700)),
                  azRecordFields(row),
                  const SizedBox(height: AppSpacing.md),
                  if (spec != null) ...<Widget>[
                    Text('次表 ${spec.subTable}（${spec.label}）',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (sub == null) const Text('尚未录入次表') else azRecordFields(sub),
                    const SizedBox(height: AppSpacing.md),
                    Text('附属记录', style: const TextStyle(fontWeight: FontWeight.w700)),
                    azAttachedRows(data, row.id, 'asset', spec.subTable),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (spec != null)
                    OutlinedButton(
                      onPressed: () async {
                        final AzEntryDraft? draft = await showAzEntrySheet(
                          context,
                          spec,
                          initialData: data,
                          editId: row.id,
                        );
                        if (draft == null || !context.mounted) return;
                        try {
                          await context.read<AzWriteController>().updateEntry(
                                spec,
                                row.id,
                                draft.mainValues,
                                draft.subValues,
                              );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('保存失败：$e')),
                            );
                          }
                        }
                      },
                      child: const Text('编辑这条记录'),
                    ),
                  if (spec != null)
                    const SizedBox(height: AppSpacing.xs),
                  if (spec != null)
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await context.read<AzWriteController>().removeEntry(
                                spec, row.id, '详情页删除');
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('删除失败：$e')),
                            );
                          }
                        }
                      },
                      child: const Text('删除这条资产'),
                    ),
                ],
              ),
            ),
    );
  }
}
