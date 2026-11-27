import 'package:material_ui/material_ui.dart';

import '../../../database/ledger/az_math.dart';
import '../../../database/ledger/az_record.dart';
import '../../../database/ledger/az_schema.dart';
import '../../../screens/commons/function/app_function_layout.dart';
import '../../../screens/commons/icon/app_icon_badge.dart';
import '../../../screens/commons/sheet/parts/sheet_primitives.dart';
import '../../../screens/commons/icons/app_icons.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../../../utils/money_format.dart';

// ── 组件私有尺寸（只服务本文件，全部引用全局令牌）───────────────
const double _kIconSize = 44;
const double _kIconGlyphSize = AppIconSize.medium;
const double _kCardMinHeight = 76;
const double _kBadgeRadius = AppRadius.small;
const double _kGroupHeaderHeight = kMinTapTarget;

/// 资产 / 负债类型 → 语义图标。与账户页 `accountTypeIcon` 同一写法：
/// 映射放在业务模块内（不进全局图标表），因为只有资债列表 / 详情用得到。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】按 AzTypeSpec.code 返回已有矢量图标，不新增图标资产。
/// 【使用限制】只读函数；未知编码回退 AppIcons.other，调用方不得据此判断类型合法性。
/// 【入参与结果】收 AzTypeSpec；返回 IconData。
/// 【异常与调用方处理】不抛异常；调用方需先用 AzSchema.byCode 判空再取图标。
IconData azTypeIcon(AzTypeSpec spec) => switch (spec.code) {
      'A3' => AppIcons.salary,
      'A4' => AppIcons.investment,
      'A5' => AppIcons.investment,
      'A6' => AppIcons.category,
      'A7' => AppIcons.property,
      'A8' => AppIcons.car,
      'A9' => AppIcons.giftMoney,
      'A10' => AppIcons.category,
      'A11' => AppIcons.other,
      '贷款' => AppIcons.accountBank,
      '分期' => AppIcons.accountCreditCard,
      _ => AppIcons.other,
    };

/// 一个「类型组」分区：组标题可折叠，组内按具体类型分块。
/// 分组头与账户页 `_AccountGroupHeader` 逐行同构（箭头 / 段名 / 数量徽章 / 合计）。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】渲染一个 AzGroupStat 的折叠分区：标题行 + 展开后的具体类型块。
/// 【使用限制】纯展示，不读库不写库；折叠状态由 home 页持有；空组渲染「暂无记录」。
/// 【入参与结果】构造收 group / data / collapsed / onToggle / onTap；build 返回 Widget。
/// 【异常与调用方处理】不抛异常；onTap 的异常由调用方（页面）自行 try/catch。
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xxs,
            ),
            child: SizedBox(
              height: _kGroupHeaderHeight,
              child: Row(
                children: <Widget>[
                  AnimatedRotation(
                    turns: collapsed ? 0 : 0.5,
                    duration: AppMotion.short,
                    child: Icon(
                      AppIcons.expandMore,
                      size: AppIconSize.medium,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(group.label, style: context.appText.sectionHeader),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(_kBadgeRadius),
                    ),
                    child: Text('${group.entryCount}',
                        style: context.appText.caption),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    MoneyFormat.yuan0(group.total),
                    style: context.appText.menuTitle
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!collapsed) ...<Widget>[
          for (final AzTypeBlock block in group.typeBlocks)
            AzTypeBlockView(block: block, data: data, onTap: onTap),
          if (group.entryCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text('暂无记录', style: context.appText.caption),
            ),
        ],
      ],
    );
  }
}

/// 组内一个具体类型（如「A4（股票）」）的条目块。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】渲染类型小标题、条目数与小计，并逐条列出该类型的记录卡片。
/// 【使用限制】纯展示；金额经 AzMath.valueOf 读次表，不写库。
/// 【入参与结果】构造收 block / data / onTap；build 返回 Widget。
/// 【异常与调用方处理】不抛异常；未登记类型按 0 金额展示。
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xxs,
              bottom: AppSpacing.xxs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(block.spec.label, style: context.appText.caption),
                Text('${block.rows.length} 条 · ${MoneyFormat.yuan0(block.total)}',
                    style: context.appText.caption),
              ],
            ),
          ),
          for (var i = 0; i < block.rows.length; i++)
            AzEntryCard(
              row: block.rows[i],
              spec: block.spec,
              amount: AzMath.valueOf(data, block.rows[i], block.spec),
              index: i,
              onTap: () => onTap(block.rows[i]),
            ),
        ],
      ),
    );
  }
}

/// 一条资产 / 负债的列表卡片，与账户页 `AccountCard` 同一套外壳：
/// `InkWell + AppDecorations.item + AppIconBadge + 名称/副标题 + 右侧金额`。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】显示类型图标徽章、名称、备注 / 状态、右侧金额与状态徽章，点击跳详情。
/// 【使用限制】纯展示，不写库；金额只用于展示；index 只用于徽章色相轮换。
/// 【入参与结果】构造收 row / spec / amount / index / onTap；build 返回 Widget。
/// 【异常与调用方处理】不抛异常；名称缺失显示「未命名」。
class AzEntryCard extends StatelessWidget {
  const AzEntryCard({
    super.key,
    required this.row,
    required this.spec,
    required this.amount,
    required this.index,
    required this.onTap,
  });

  final AzRecord row;
  final AzTypeSpec spec;
  final double amount;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeTokens tokens = context.tokens;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String name = row.text('name').isEmpty ? '未命名' : row.text('name');
    final String status = row.text('status');
    final bool overdue = status == '逾期' || status == 'overdue';
    final bool liability = spec.side == 'liability';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.item),
          child: Container(
            decoration: AppDecorations.item(context),
            constraints: const BoxConstraints(minHeight: _kCardMinHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                AppIconBadge(
                  icon: azTypeIcon(spec),
                  size: _kIconSize,
                  iconSize: _kIconGlyphSize,
                  tone: null,
                  index: index,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(name, style: context.appText.menuTitle),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        <String>[
                          spec.label,
                          if (row.text('note').isNotEmpty) row.text('note'),
                        ].join(' · '),
                        style: context.appText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      MoneyFormat.yuan0(amount),
                      style: context.appText.amount.copyWith(
                        color: liability ? tokens.expense : null,
                      ),
                    ),
                    if (status.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: (overdue ? tokens.warning : cs.primary)
                              .withValues(alpha: AppOpacity.disabledContainer),
                          borderRadius: BorderRadius.circular(_kBadgeRadius),
                        ),
                        child: Text(
                          status,
                          style: context.appText.caption.copyWith(
                            color: overdue ? tokens.warning : cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
// 详情页字段展示（资产 / 负债两页共用，样式走账户页同一套组件）
// ══════════════════════════════════════════════════════════════════

const Set<String> _kHiddenDetailCols = <String>{
  'id', 'book_id', 'created_at', 'updated_at', 'revision', 'sort_order',
  'archived', 'deleted_at', 'delete_reason',
  'asset_id', 'liability_id', 'sub_asset_id', 'sub_liability_id',
};

/// 一行记录 → AppInfoGrid 的条目列表（剔除纯技术列，金额按元格式化）。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】把一条主表 / 次表 / 附表记录按 AzSchema 列清单转成详情信息格，金额列走 MoneyFormat。
/// 【使用限制】只读派生；不含 BuildContext；未登记列返回空列表。
/// 【入参与结果】收 AzRecord；返回 List<AppInfoItem>。
/// 【异常与调用方处理】不抛异常；空值显示「—」。
List<AppInfoItem> azInfoItems(AzRecord record) {
  final List<AppInfoItem> out = <AppInfoItem>[];
  for (final AzColumn c in AzSchema.columnsFor(record.table)) {
    if (_kHiddenDetailCols.contains(c.name)) continue;
    final Object? raw = record.fields[c.name];
    final String value = (raw == null || raw.toString().isEmpty)
        ? '—'
        : (c.kind == AzInputKind.money ? MoneyFormat.yuan(record.money(c.name)) : raw.toString());
    out.add(AppInfoItem(label: c.label, value: value));
  }
  return out;
}

/// 与主表行关联的附属表记录，按表分块渲染（SheetSectionLabel + AppInfoGrid）。
/// 【所属模块】screens/ledger/widgets · 资债卡片
/// 【实现功能】遍历该侧所有附属表，按外键筛出属于本条主表记录的行，按表分块展示。
/// 【使用限制】纯展示；不做金额计算；次表由调用方单独展示，本函数跳过它。
/// 【入参与结果】收 data / mainId / side / subTable；返回 List<Widget>（可直接塞进 Column）。
/// 【异常与调用方处理】不抛异常；无附属记录时返回一段「暂无附属记录」文案。
List<Widget> azAttachedSections(
  AzData data,
  int mainId,
  String side,
  String subTable,
) {
  final String fk = side == 'asset' ? 'asset_id' : 'liability_id';
  final String prefix = side == 'asset' ? 'az_asset_' : 'az_liability_';
  final List<Widget> out = <Widget>[];
  for (final String table in AzSchema.allTables) {
    if (!table.startsWith(prefix) || table == subTable) continue;
    if (AzSchema.bySubTable(table) != null) continue;
    final List<AzRecord> rows = data.rowsOf(table)
        .where((AzRecord r) => r.intOf(fk) == mainId)
        .toList(growable: false);
    if (rows.isEmpty) continue;
    out.add(SheetSectionLabel(label: table, count: '${rows.length} 条'));
    for (final AzRecord r in rows) {
      <Widget>[
      AppInfoGrid(items: azInfoItems(r)),
      const SizedBox(height: AppSpacing.xs),
    ];
    }
  }
  if (out.isEmpty) {
    out.add(const SheetCaption(text: '暂无附属记录'));
  }
  return out;
}
