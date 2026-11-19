import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/asset_liability/az_db.dart';
import '../../database/asset_liability/az_math.dart';
import '../../database/asset_liability/az_record.dart';
import '../../screens/commons/function/app_detail_page.dart';
import '../../screens/commons/function/app_floating_actions.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../service/account_controller.dart';
import '../../service/az_controller.dart';
import '../../styles/app_decorations.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import 'az_sheets.dart';
import 'widgets/az_cards.dart';

/// 负债详情页（7.4 / 7.8 / 7.10 共用同一个框架）。
///
/// 头卡说清「现在还欠多少」，信息网格把「这笔钱贵不贵」逐项摊开，
/// 还款计划表把每一期里的 本金 / 利息 / 手续费 **分列**显示 ——
/// 7.12 的方向铁律就靠这三列让人一眼看懂「哪部分真花掉了」。
///
/// 与资产详情页共用 [AppDetailPage] 与 [AppFloatingActions]，不新建壳。
class LiabilityDetailScreen extends StatelessWidget {
  const LiabilityDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  Widget build(BuildContext context) {
    final AzController az = context.watch<AzController>();
    final AccountController accounts = context.watch<AccountController>();
    final LiabilityRecord? debt = az.liabilityById(debtId);
    if (debt == null) {
      return AppDetailPage(
        title: '找不到这一笔',
        child: Center(
          child: Text('它可能已经进了回收站。', style: context.appText.body),
        ),
      );
    }

    final AzData d = az.data;
    final List<RepayPlanRecord> plans = az.plansFor(debt);
    final double realRate = AzMath.realAnnualRate(debt);
    final AzLeverage? lev = AzMath.leverageOf(debt, d.activeAssets);
    String assetName = '—（没关联）';
    for (final AssetRecord a in d.activeAssets) {
      if (a.id == debt.linkAssetId) {
        assetName = a.name;
        break;
      }
    }
    final String accountName = _accountName(accounts, debt.linkAccountId);
    final double progress = debt.totalTerms == 0
        ? 0
        : (debt.paidTerms / debt.totalTerms).clamp(0.0, 1.0).toDouble();

    return AppDetailPage(
      title: debt.name,
      actions: <Widget>[
        IconButton(
          tooltip: '编辑',
          icon: const Icon(AppIcons.edit),
          onPressed: () => unawaited(
            showAzLiabilitySheet(context, existing: debt),
          ),
        ),
      ],
      floating: AppFloatingActions(
        actions: <AppFloatingAction>[
          AppFloatingAction(
            label: '记一笔还款',
            icon: AppIcons.repay,
            emphasized: true,
            onPressed: () => unawaited(
              showAzRepaySheet(context, debt, plans),
            ),
          ),
          AppFloatingAction(
            label: '算一下提前还',
            icon: AppIcons.balanceAdjust,
            onPressed: () => unawaited(showAzPrepaySheet(context, debt)),
          ),
          AppFloatingAction(
            label: '编辑这一笔',
            icon: AppIcons.edit,
            onPressed: () => unawaited(
              showAzLiabilitySheet(context, existing: debt),
            ),
          ),
          AppFloatingAction(
            label: '删除',
            icon: AppIcons.trash,
            onPressed: () => unawaited(
              showAzDeleteSheet(
                context,
                title: '把「${debt.name}」放进回收站？',
                description:
                    '${plans.length} 期还款计划会保留，30 天内可恢复。删掉后它就不再进「一共欠多少」。',
                onConfirm: () async {
                  await context.read<AzWriteController>().softDelete(
                        AzDb.liabilitiesTable,
                        debt.id!,
                        '从负债详情页删除',
                      );
                  if (context.mounted) context.pop();
                },
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSummaryHero(
            label: '现在还欠多少',
            value: MoneyFormat.yuan0(debt.principal),
            caption: debt.totalTerms == 0
                ? '${debt.repayMethod.label}：${debt.repayMethod.hint}'
                : '已经还了 ${debt.paidTerms} 期 / 一共 ${debt.totalTerms} 期，'
                    '还剩 ${debt.leftTerms} 期。',
            accent: context.tokens.expense,
            progress: progress,
            secondary: <AppInfoItem>[
              AppInfoItem(
                label: '这个月要还',
                value: MoneyFormat.yuan0(debt.monthlyPay),
              ),
              AppInfoItem(
                label: '这个月白给银行的',
                value: MoneyFormat.yuan0(debt.monthlyCost),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.sectionGap),
          AppInfoGrid(
            items: <AppInfoItem>[
              AppInfoItem(label: '欠的什么钱', value: debt.type.label),
              AppInfoItem(label: '借来干了什么', value: debt.purpose.label),
              AppInfoItem(
                label: '实际一年要付多少',
                value: '${(realRate * 100).toStringAsFixed(1)}%',
              ),
              AppInfoItem(
                label: '合同上写的那个数',
                value: '${(debt.rate * 100).toStringAsFixed(1)}%',
              ),
              AppInfoItem(label: '利率会不会变', value: debt.rateType.label),
              AppInfoItem(label: '怎么还', value: debt.repayMethod.label),
              AppInfoItem(
                label: '其中本金',
                value: MoneyFormat.yuan0(debt.monthlyPrincipal),
              ),
              AppInfoItem(
                label: '其中利息',
                value: MoneyFormat.yuan0(debt.monthlyInterest),
              ),
              AppInfoItem(
                label: '其中手续费',
                value: MoneyFormat.yuan0(debt.monthlyFee),
              ),
              AppInfoItem(
                label: '每月几号还',
                value: debt.payDay == null ? '—' : '${debt.payDay} 号',
              ),
              AppInfoItem(label: '从哪张卡扣', value: accountName),
              AppInfoItem(label: '这笔钱买来的东西', value: assetName),
              AppInfoItem(label: '状态', value: debt.status.label),
              if (debt.feeNote.isNotEmpty)
                AppInfoItem(label: '除了利息还交了什么', value: debt.feeNote),
            ],
          ),
          const SizedBox(height: AppLayout.sectionGap),
          if (lev != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                lev.net >= 0
                    ? '借钱买的「${lev.asset.name}」稳稳每月进 ${MoneyFormat.yuan0(lev.steadyIn)}，'
                        '这笔债每月利息费用 ${MoneyFormat.yuan0(lev.cost)} —— 它替你付了利息，还多留 ${MoneyFormat.yuan0(lev.net)}。'
                    : '借钱买的「${lev.asset.name}」稳稳每月进 ${MoneyFormat.yuan0(lev.steadyIn)}，'
                        '这笔债每月利息费用 ${MoneyFormat.yuan0(lev.cost)} —— 它每月从你口袋拿走 ${MoneyFormat.yuan0(-lev.net)}。',
                style: context.appText.body.copyWith(
                  color: lev.net >= 0
                      ? context.tokens.income
                      : context.tokens.expense,
                ),
              ),
            ),
          AppFunctionSection(
            title: '每一期要还多少',
            actionLabel: '先还哪一笔最划算 ›',
            onAction: () => unawaited(showAzPayoffSheet(context)),
            child: plans.isEmpty
                ? const AzSmallEmpty('这笔还没有逐期计划，点「编辑」填上期数就能生成')
                : _planTable(context, plans),
          ),
          const AzHint(
            '这一期里，利息和手续费是真给银行的；本金只是从左口袋换到右口袋，'
            '还完本金「真正属于你的钱」不变，只有利息与费用才让它减少。',
          ),
          const AzHint(
            '软件不联网，也不替银行计息：这里的利息、分期折算结果都是按你填的数和'
            '这张卡自己的章程估的，一律标「估算，以账单为准」。',
          ),
          const AzHint(
            '记还款只登记「这一期还了」：卡里扣的钱与负债本金要成对变动，'
            '等记账模块接上账户流水才会自动记。现在「现在还欠多少」按你编辑时填的数为准。',
          ),
        ],
      ),
    );
  }

  Widget _planTable(BuildContext context, List<RepayPlanRecord> plans) {
    final t = context.tokens;
    return Container(
      decoration: AppDecorations.card(context),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _head('期数'),
              _head('哪天还'),
              _head('本金'),
              _head('利息'),
              _head('费用'),
              _head('还剩'),
              _head('状态'),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (final RepayPlanRecord p in plans) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: <Widget>[
                  _cell(context, '${p.termNo}'),
                  _cell(context, _dateText(p.dueDate)),
                  _cell(context, MoneyFormat.yuan0(p.principal)),
                  _cell(
                    context,
                    MoneyFormat.yuan0(p.interest),
                    color: t.expense,
                  ),
                  _cell(context, MoneyFormat.yuan0(p.fee), color: t.warning),
                  _cell(context, MoneyFormat.yuan0(p.remainingPrincipal)),
                  _cell(context, p.status.label),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _head(String s) => Expanded(
        child: Text(
          s,
          style: AppTypography.labelSmall,
          textAlign: TextAlign.center,
        ),
      );

  Widget _cell(BuildContext context, String s, {Color? color}) => Expanded(
        child: Text(
          s,
          style: context.appText.caption.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
      );

  static String _accountName(AccountController accounts, int? id) {
    if (id == null) return '—（没关联）';
    for (final dynamic a in accounts.all) {
      if (a.id == id) return a.name as String;
    }
    return '原来那张卡已删除';
  }

  static String _dateText(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
