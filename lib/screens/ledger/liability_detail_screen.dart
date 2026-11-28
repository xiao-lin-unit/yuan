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
import '../../service/ledger/az_liability_service.dart';
import '../../service/ledger/az_repayment_service.dart';
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
    final bool isInstallment =
        spec != null && spec.subTable == 'az_liability_installment';
    // 当期应还只从负债侧的待还记录取（要-13）：账户侧只有累计量，查不出本期增量。
    final AzRecord? plan = _currentPlan(data, row.id, isInstallment);
    final double dueTotal = plan == null
        ? 0
        : plan.money('principal_part') +
            plan.money('interest_part') +
            plan.money('fee') +
            plan.money('penalty_amount');

    // 与资产详情页同一套：功能入口上移到首屏横排格，一行 5 个。
    final List<AppFloatingAction> actions = <AppFloatingAction>[
      AppFloatingAction(
        // 一次性还清 / 随借随还没有自动计划，主按钮改叫「登记还款」，
        // 走 user 主动还款路径，不能因 plan == null 把入口堵死。
        label: plan == null ? '登记还款' : '还本期',
        icon: AppIcons.repay,
        emphasized: true,
        onPressed: () => unawaited(_repay(context, row, plan, dueTotal,
            isInstallment: isInstallment, prepay: false)),
      ),
      AppFloatingAction(
        label: '提前还款',
        icon: AppIcons.add,
        onPressed: () => unawaited(_repay(context, row, plan, dueTotal,
            isInstallment: isInstallment, prepay: true)),
      ),
      AppFloatingAction(
        label: '检查逾期',
        icon: AppIcons.schedule,
        onPressed: () => unawaited(_scanOverdue(context, row.id, isInstallment)),
      ),
      AppFloatingAction(
        label: '编辑',
        icon: AppIcons.edit,
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
          // 当期应还：只展示已生成的一条 pending / overdue，不预测未来期数。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppInfoGrid(
              groupLabel: '当期应还',
              items: <AppInfoItem>[
                AppInfoItem(
                  label: '合计应还',
                  value: MoneyFormat.yuan(dueTotal),
                  tip: '本金 + 利息 + 费用 + 罚费；软件按次表参数算好这一条。',
                ),
                AppInfoItem(
                  label: '期号',
                  value: plan == null || plan.text('term_no').isEmpty
                      ? '—'
                      : '第 ${plan.text('term_no')} 期',
                ),
                AppInfoItem(
                  label: '应还日',
                  value: plan == null ? '—' : _dateLabel(plan.intOf('due_at')),
                ),
                AppInfoItem(
                  label: '状态',
                  value: plan == null ? '无待还记录' : _stateLabel(plan.text('state')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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

  /// 从负债侧取唯一一条待还记录（未来永远只有一条 pending / overdue）。
  /// 【所属模块】screens/ledger · 详情
  /// 【实现功能】在还款附表里按 liability_id 筛未还记录，按期号取最早一条。
  /// 【使用限制】纯内存只读派生；不读账户表、不预测未来期数。
  /// 【入参与结果】收 data / liabilityId / 是否分期；返回 AzRecord?。
  /// 【异常与调用方处理】不抛异常；无记录返回 null，调用方渲染「无待还记录」。
  AzRecord? _currentPlan(AzData data, int liabilityId, bool isInstallment) {
    final String table = isInstallment
        ? 'az_liability_installment_repay'
        : 'az_liability_loan_repay';
    final List<AzRecord> rows = data
        .rowsOf(table)
        .where((AzRecord r) =>
            r.intOf('liability_id') == liabilityId &&
            (r.text('state') == 'pending' || r.text('state') == 'overdue'))
        .toList();
    if (rows.isEmpty) return null;
    rows.sort((AzRecord a, AzRecord b) =>
        a.intOf('term_no').compareTo(b.intOf('term_no')));
    return rows.first;
  }

  /// 【所属模块】screens/ledger · 详情
  /// 【实现功能】把毫秒时间戳显示成 YYYY-MM-DD。
  /// 【使用限制】只读；0 或负数按「—」。
  /// 【入参与结果】收毫秒；返回 String。
  /// 【异常与调用方处理】不抛异常。
  String _dateLabel(int ms) {
    if (ms <= 0) return '—';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// 【所属模块】screens/ledger · 详情
  /// 【实现功能】把附表 state 的英文值显示成中文。
  /// 【使用限制】只读；未知值原样显示。
  /// 【入参与结果】收 state；返回 String。
  /// 【异常与调用方处理】不抛异常。
  String _stateLabel(String state) => switch (state) {
        'pending' => '待还',
        'overdue' => '逾期',
        'paid' => '已还',
        'cancelled' => '已取消',
        _ => state.isEmpty ? '—' : state,
      };

  /// 还款：先现算逾期，再弹动作表，最后走全库唯一的跨模块编排入口。
  /// 【所属模块】screens/ledger · 详情
  /// 【实现功能】常规还本期调 repayLoanInstallment；主动提前还款 / 分期结清调 prepay；写库失败只提示、不跳页。
  /// 【使用限制】页面不拆金额、不判断该不该收违约金、不直接调账户出账；写库异常不吞。
  /// 【入参与结果】收 context / 主表行 / 当期计划 / 建议金额 / 是否分期 / 是否提前；返回 Future<void>。
  /// 【异常与调用方处理】服务抛异常时 SnackBar 提示「还款未生效」，保持页面与旧快照；调用方必须判 mounted。
  Future<void> _repay(
    BuildContext context,
    AzRecord row,
    AzRecord? plan,
    double dueTotal, {
    required bool isInstallment,
    required bool prepay,
  }) async {
    await _scanOverdue(context, row.id, isInstallment, quiet: true);
    if (!context.mounted) return;
    final AzRepaySheetResult? result = await showAzRepaySheet(
      context,
      name: row.text('name'),
      isInstallment: isInstallment,
      suggestedAmount: dueTotal,
      defaultAccountId: row.intOf('link_account_id'),
    );
    if (result == null || !context.mounted) return;
    if (result.repayAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先到「账户」页新建一个流动资金账户，再回来还款')),
      );
      return;
    }
    // 没有自动计划（一次性 / 随借随还 / 计划被取消）时一律走 user 主动还款，
    // 否则 markPlanPaidIn 会因找不到 plan 抛错、还款永远办不成。
    final bool usePrepay = result.prepay || plan == null;
    try {
      final AzRepaymentService service = context.read<AzRepaymentService>();
      AzRepayOutcome outcome;
      if (usePrepay) {
        outcome = await service.prepay(AzPrepayRequest(
          liabilityId: row.id,
          amount: result.amount,
          repaidAt: DateTime.now(),
          repayAccountId: result.repayAccountId,
          isInstallment: isInstallment,
          settleAll: result.settleAll,
          settleRule: result.settleRule,
          ruleRatio: result.ruleRatio,
          serviceFee: result.serviceFee,
          partialMode: result.partialMode,
          // 无自动计划时不能勾选「先还完本期」，否则逻辑会去找不存在的计划。
          payCurrentTerm: result.payCurrentTerm && plan != null,
          hasPenalty: result.hasPenalty,
        ));
      } else {
        outcome = await service.repayLoanInstallment(
          liabilityId: row.id,
          planId: plan!.id,
          amount: result.amount,
          repaidAt: DateTime.now(),
          repayAccountId: result.repayAccountId,
          isInstallment: isInstallment,
        );
      }
      // 全额结清按规则重算过金额时，明确告诉用户实际扣了多少。
      if (context.mounted && (outcome.amount - result.amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              '已按结清规则以 ${outcome.amount.toStringAsFixed(2)} 元入账（与你填的 ${result.amount.toStringAsFixed(2)} 元不同）')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('还款未生效：$e')),
        );
      }
    }
  }

  /// 用户打开 / 操作时现算现标逾期（软件不打开不处理数据）。
  /// 【所属模块】screens/ledger · 详情
  /// 【实现功能】调 AzWriteController.scanOverdue 在唯一事务里标逾期、算罚息与复利、累加总亏损。
  /// 【使用限制】不做定时跨天累计；quiet=true 时不弹提示。
  /// 【入参与结果】收 context / liabilityId / 是否分期 / quiet；返回 Future<void>。
  /// 【异常与调用方处理】DAO 异常只提示、不吞后继续走还款流程之外的其它动作。
  Future<void> _scanOverdue(
    BuildContext context,
    int liabilityId,
    bool isInstallment, {
    bool quiet = false,
  }) async {
    try {
      final int changed = await context
          .read<AzWriteController>()
          .scanOverdue(liabilityId, isInstallment: isInstallment);
      if (!quiet && changed > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已标记 $changed 条逾期记录')),
        );
      }
    } catch (e) {
      if (!quiet && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('逾期检查失败：$e')),
        );
      }
    }
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
