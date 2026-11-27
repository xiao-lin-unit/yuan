import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../database/ledger/az_schema.dart';
import '../../screens/commons/empty/app_empty_state.dart';
import '../../screens/commons/function/app_detail_page.dart';
import '../../screens/commons/function/app_floating_actions.dart';
import '../../screens/commons/function/app_function_grid.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../service/ledger/az_controller.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import 'az_sheets.dart';
import 'widgets/az_cards.dart';

const String _kNotFoundTitle = '负债不存在';
const String _kNotFoundBody = '这条记录可能已被删除。';
const String _kNoSub = '尚未录入次表。';
const String _kSubSection = '专属信息';
const String _kAttachSection = '关联记录';

/// LiabilityDetailScreen：二级功能页，用公共 [AppDetailPage]，与 home 页
/// [LedgerScreen] 的 [AppHomePage] 明确分开。布局与账户明细页同源：
/// AppSummaryHero → AppFunctionGrid → AppInfoGrid → AppFunctionSection；
/// 编辑 / 删除是首屏横排功能格，不再是右下角悬浮展开列。
/// 【所属模块】screens/ledger · 详情
/// 【实现功能】按 debtId 从共享账本取主表行，展示主表 / 次表 / 全部关联附表，并提供编辑与删除。
/// 【使用限制】页面不读库、不写库；编辑与删除走 AzWriteController；debtId 无效时展示空态。
/// 【入参与结果】构造收 debtId（由路由 /ledger/debt/:id 传入）；build 返回 AppDetailPage。
/// 【异常与调用方处理】写库异常由 AzWriteController 上抛，本页 try/catch 后用 SnackBar 提示；不吞异常后返回上一页。
class LiabilityDetailScreen extends StatelessWidget {
  const LiabilityDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  Widget build(BuildContext context) {
    final AzController az = context.watch<AzController>();
    final AzData data = az.data;
    AzRecord? found;
    for (final AzRecord r in data.liabilities) {
      if (r.id == debtId) {
        found = r;
        break;
      }
    }
    if (found == null) {
      return AppDetailPage(
        title: _kNotFoundTitle,
        brandHeader: true,
        child: AppEmptyState(
          icon: AppIcons.warning,
          title: _kNotFoundTitle,
          description: _kNotFoundBody,
        ),
      );
    }
    final AzRecord row = found;
    final AzTypeSpec? spec = data.typOf(row);
    final AzRecord? sub = spec == null ? null : data.subFor(row.id, spec.subTable);
    final double amount = spec == null
        ? 0
        : AzMath.valueOf(data, row, spec);
    final String status = row.text('status');
    final AppThemeTokens tokens = context.tokens;

    // 与资产详情页同一套：功能入口上移到首屏横排格。
    final List<AppFloatingAction> actions = <AppFloatingAction>[
      AppFloatingAction(
        label: '编辑',
        icon: AppIcons.edit,
        emphasized: true,
        onPressed: () => unawaited(_edit(context, data, row, spec)),
      ),
      AppFloatingAction(
        label: '删除',
        icon: AppIcons.trash,
        onPressed: () => unawaited(_remove(context, row, spec)),
      ),
    ];

    return AppDetailPage(
      title: row.text('name').isEmpty ? '详情' : row.text('name'),
      brandHeader: true,
      // 不再有右下悬浮层，底部留白回到常规值。
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppSummaryHero(
              emphasized: false,
              label: '剩余待还本金',
              value: MoneyFormat.yuan0(amount),
              caption: '挂卡分期已含在信用卡欠款里，不重复相加。',
              accent: tokens.expense,
              // 负债页单独定主角：次要指标放主表的「总亏损」与「状态」，
              // 与待还本金同属金额语义；类型留在信息网格里，不重复。
              secondary: <AppInfoItem>[
                AppInfoItem(
                  label: '总亏损',
                  value: MoneyFormat.yuan(row.money('total_loss')),
                  tip: '主表登记的累计亏损，按当前记录原值展示。',
                ),
                AppInfoItem(
                  label: '状态',
                  value: status.isEmpty ? '正常' : status,
                ),
              ],
            ),
          ),
          // ★ 留白按层级查表：主角 → 操作 md → 主信息 lg
          //   → 附表大区块 xl → 组内 md。与资产 / 账户详情页同一套节奏。
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppFunctionGrid(actions: actions),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppInfoGrid(
              items: azInfoItems(row),
              groupLabel: '负债信息',
            ),
          ),
          if (spec != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            AppFunctionSection(
              title: '${spec.label} · $_kSubSection',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: sub == null
                    ? Text(_kNoSub, style: context.appText.caption)
                    : AppInfoGrid(items: azInfoItems(sub)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppFunctionSection(
              title: _kAttachSection,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: azAttachedSections(
                    data,
                    row.id,
                    'liability',
                    spec.subTable,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 编辑：声明式表单带出主表 + 次表已有值，交给 AzWriteController 同事务更新。
  Future<void> _edit(
    BuildContext context,
    AzData data,
    AzRecord row,
    AzTypeSpec? spec,
  ) async {
    if (spec == null) return;
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
  }

  /// 删除：二次确认后软删，成功才返回上一页。
  Future<void> _remove(
    BuildContext context,
    AzRecord row,
    AzTypeSpec? spec,
  ) async {
    if (spec == null) return;
    bool deleted = false;
    await showAzDeleteSheet(
      context,
      name: row.text('name'),
      onDelete: () async {
        await context.read<AzWriteController>().removeEntry(
              spec,
              row.id,
              '详情页删除',
            );
        deleted = true;
      },
    );
    // 弹层关掉之后再返回上一页，避免在已卸载的 context 上叠两次关闭。
    if (deleted && context.mounted) context.pop();
  }
}
