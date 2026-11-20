import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../screens/commons/sheet/app_sheet_shell.dart';
import '../../screens/commons/sheet/contents/confirm_sheet_content.dart';
import '../../screens/commons/sheet/contents/form_sheet_content.dart';
import '../../screens/commons/sheet/contents/overview_sheet_content.dart';
import '../../screens/commons/sheet/contents/select_sheet_content.dart';
import '../../screens/commons/sheet/parts/sheet_primitives.dart';
import '../../screens/commons/sheet/sheet_form_items.dart';
import '../../screens/commons/sheet/sheet_models.dart';
import '../../service/account_controller.dart';
import '../../service/ledger/az_controller.dart';
import '../../utils/money_format.dart';
import '../commons/icons/app_icons.dart';

/// 表单类入口统一从这里导出：页面只 `import 'az_sheets.dart'` 一处。
export 'az_form_sheets.dart';

/// 资债模块的**展示 / 口径类 Sheet**。
///
/// 【契约】全部走 `AppSheetShell.show` 唯一外壳 + 既有 7 类内容组件：
///   · 口径切换 / 偿债档 → [SelectSheetContent]（未指定选择）；
///   · 月末存一次数 → [ConfirmSheetContent]（确认）；
///   · 划不划算 / 逐月缺口 / 先还哪一笔 → [OverviewSheetContent]（仅展示）；
///   · 设置（月收入、必须花的钱、应急金、物价）→ [FormSheetContent]（修改）。
/// **没有新建任何 XxxSheetContent，也没有第二套弹层外壳。**
///
/// 【关闭按钮怎么拿到渲染时 context】[OverviewSheetContent.onAction] 是
/// 不带 context 的 VoidCallback。这里统一用 `Builder` 包一层：Builder 的
/// context 在 SheetScope **内部**，所以 `SheetActions.close(sheetContext)`
/// 既能查到「我在 Sheet 内」的标记，也一定 pop 的是弹层而不是页面。
/// 这与 SheetCancelAction 用自己 build 里的 context 是同一条规矩。

/// ① 估值口径（6.4）。切到「按我填的最新价」时给一句白话提醒，
/// 不冒充实时行情；切换留痕走 setPreference 的 revision。
Future<void> showAzValuationModeSheet(
  BuildContext context,
  ValuationMode current,
) async {
  await AppSheetShell.show<ValuationMode>(
    context,
    header: const SheetHeader(
      title: '总账按哪个价算',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: SelectSheetContent<ValuationMode>(
      options: const <SheetOption<ValuationMode>>[
        SheetOption<ValuationMode>(
          value: ValuationMode.cost,
          label: '保守：按买入价（推荐）',
          icon: AppIcons.balanceAdjust,
        ),
        SheetOption<ValuationMode>(
          value: ValuationMode.latest,
          label: '按我填的最新价',
          icon: AppIcons.investment,
        ),
      ],
      initialValue: current,
      actionLabel: '就用这个口径',
      onApplyAsync: (ValuationMode v) async {
        await context.read<AzWriteController>().setPreference(
              'valuation_mode',
              v.dbValue,
            );
      },
    ),
  );
}

/// ② 偿债比例三档（7.9）。只改判断的安全线，不改任何真实数字。
Future<void> showAzDebtRatioSheet(
  BuildContext context,
  DebtRatioLevel current,
) async {
  await AppSheetShell.show<DebtRatioLevel>(
    context,
    header: const SheetHeader(
      title: '每月要还的钱，多少算安全',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: SelectSheetContent<DebtRatioLevel>(
      options: <SheetOption<DebtRatioLevel>>[
        for (final DebtRatioLevel l in DebtRatioLevel.values)
          SheetOption<DebtRatioLevel>(
            value: l,
            label: '${l.label}：月还款占月收入 ${(l.limit * 100).toStringAsFixed(0)}% 以内',
            icon: AppIcons.about,
          ),
      ],
      initialValue: current,
      actionLabel: '就用这一档',
      onApplyAsync: (DebtRatioLevel v) async {
        await context.read<AzWriteController>().setPreference(
              'debt_ratio_level',
              v.dbValue,
            );
      },
    ),
  );
}

/// ③ 设置（13.13 唯一入口）：每月到手的钱、每月必须花的钱、想留几个月、
/// 东西一年贵百分之几、隐藏余额为 0 的欠款、借钱的成本计不计入支出。
/// 【不替用户猜】默认都是 0 / 可跳过，没填就显示「—」，不编一个数。
Future<void> showAzPreferenceSheet(BuildContext context) async {
  final AzController az = context.read<AzController>();
  final AzPreferences p = az.preferences;
  final FormSheetController ctl = FormSheetController();
  await AppSheetShell.show<void>(
    context,
    header: SheetHeader(
      title: '几个要自己填的数',
      subtitle: '不填显示「—」',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: ctl.submit,
      ),
    ),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '保存',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'monthly_income',
          label: '每月到手的钱',
          initialValue: p.monthlyIncome == 0 ? '' : p.monthlyIncome.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'must_cost',
          label: '每月必须花的钱',
          initialValue: p.mustCost == 0 ? '' : p.mustCost.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'emergency_months',
          label: '想留几个月急用的钱',
          initialValue: p.emergencyMonths.toString(),
          keyboardType: TextInputType.number,
        ),
        SheetFormSingleLineTextItem(
          key: 'inflation_rate',
          label: '东西一年大概贵百分之几（可跳过）',
          initialValue: p.inflationRate == 0 ? '' : p.inflationRate.toStringAsFixed(1),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'stale_days',
          label: '多久没更新价就提醒（天）',
          initialValue: p.staleDays.toString(),
          keyboardType: TextInputType.number,
        ),
        SheetFormToggleItem(
          key: 'hide_zero',
          label: '隐藏已经还清的欠款',
          initialValue: p.hideZero,
        ),
        SheetFormToggleItem(
          key: 'include_debt_cost_in_expense',
          label: '借钱的成本计入「这个月一共花了多少」',
          initialValue: p.includeDebtCostInExpense,
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        final AzWriteController write = context.read<AzWriteController>();
        double? numOr(String key) => double.tryParse(v.text(key).trim());
        await write.setPreference(
          'monthly_income',
          (numOr('monthly_income') ?? 0).toString(),
        );
        await write.setPreference(
          'must_cost',
          (numOr('must_cost') ?? 0).toString(),
        );
        await write.setPreference(
          'emergency_months',
          (int.tryParse(v.text('emergency_months').trim()) ?? 3).toString(),
        );
        await write.setPreference(
          'inflation_rate',
          (numOr('inflation_rate') ?? 0).toString(),
        );
        await write.setPreference(
          'stale_days',
          (int.tryParse(v.text('stale_days').trim()) ?? 90).toString(),
        );
        await write.setPreference('hide_zero', v.flag('hide_zero') ? '1' : '0');
        await write.setPreference(
          'include_debt_cost_in_expense',
          v.flag('include_debt_cost_in_expense') ? '1' : '0',
        );
      },
    ),
  );
}

/// ④ 按月末存一次数（10.9 / 13.12）。写进去就不改历史。
Future<void> showAzSnapshotSheet(BuildContext context) async {
  final AzController az = context.read<AzController>();
  final List<AccountRecord> accounts = context.read<AccountController>().all;
  final AzData d = az.data;
  final DateTime today = DateTime.now();
  final double accountTotal = AzMath.accountTotal(AzMath.mirrors(accounts));
  final double assetTotal = accountTotal + AzMath.selfAssets(d);
  final double debtTotal = AzMath.debtsTotal(d, accounts);
  final String month =
      '${today.year}-${today.month.toString().padLeft(2, '0')}';
  await AppSheetShell.show<void>(
    context,
    header: const SheetHeader(
      title: '按月末存一次数',
      subtitle: '存下就锁定',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: ConfirmSheetContent(
      title: '把 $month 的数存下来？',
      description:
          '存下 $month 的数：卡里和动不了的 ${MoneyFormat.yuan0(accountTotal)}、'
          '除了钱以外的 ${MoneyFormat.yuan0(AzMath.selfAssets(d))}、'
          '欠的 ${MoneyFormat.yuan0(debtTotal)}。已存过不覆盖。',
      secondaryLabel: '再想想',
      primaryLabel: '存一次',
      intent: SheetIntent.neutral,
      icon: AppIcons.calendarMonth,
      onPrimaryAsync: () async {
        await context.read<AzWriteController>().writeSnapshot(
              MonthlySnapshotRecord(
                yearMonth: month,
                accountTotal: accountTotal,
                assetTotal: assetTotal,
                debtTotal: debtTotal,
                netWorth: assetTotal - debtTotal,
                valuationMode: d.preferences.valuationMode,
                snapshotAt: today,
                note: '按月末存一次数',
              ),
            );
      },
    ),
  );
}

/// ⑤ 借钱买的东西划不划算（13.5）：逐笔「稳稳每月进 − 当月利息费用」。
/// 只展示，不评价消费行为；T5 应急借的单独说明。
Future<void> showAzLeverageSheet(BuildContext context) async {
  final AzController az = context.read<AzController>();
  final AzData d = az.data;
  final List<AzLeverage> list = <AzLeverage>[
    for (final LiabilityRecord x in d.activeLiabilities)
      if (AzMath.leverageOf(x, d.activeAssets) != null)
        AzMath.leverageOf(x, d.activeAssets)!,
  ];
  double maxAbs = 1;
  for (final AzLeverage l in list) {
    if (l.net.abs() > maxAbs) maxAbs = l.net.abs();
  }
  await AppSheetShell.show<void>(
    context,
    header: const SheetHeader(
      title: '借钱买的东西划不划算',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: list.isEmpty
            ? const <SheetMetric>[
                SheetMetric(label: '连着东西的债', value: '0 笔'),
              ]
            : <SheetMetric>[
                for (final AzLeverage l in list)
                  SheetMetric(
                    label: l.asset.name,
                    value: MoneyFormat.yuan0(l.net.abs()),
                    unit: l.net >= 0 ? '多留' : '拿走',
                  ),
              ],
        trend: <SheetTrendPoint>[
          for (final AzLeverage l in list)
            SheetTrendPoint(
              label: l.debt.name,
              value: (l.net.abs() / maxAbs).clamp(0.0, 1.0).toDouble(),
              highlighted: l.net < 0,
            ),
        ],
        updatedAt: list.isEmpty
            ? '暂无连着东西的债。'
            : '只算标了「每月都有」的进账。',
        actionLabel: '知道了',
        onAction: () => SheetActions.close(sheetContext),
      ),
    ),
  );
}

/// ⑥ 逐月缺口表（7.9 / 13.6）：未来 12 个月「这个月要还 / 那个月能拿出 / 差多少」。
/// 别拿今天的钱去除明年的债；资产按「多久能变成现金」排到能到手的月份。
Future<void> showAzGapSheet(BuildContext context) async {
  final AzController az = context.read<AzController>();
  final AzData d = az.data;
  final List<AccountRecord> accounts = context.read<AccountController>().all;
  final List<AzGapRow> gaps =
      AzMath.gapTable(d, accounts, az.today);
  AzGapRow worst = gaps.isEmpty
      ? const AzGapRow(month: '—', pay: 0, available: 0, gap: 0)
      : gaps.first;
  for (final AzGapRow g in gaps) {
    if (g.gap > worst.gap) worst = g;
  }
  double maxPay = 1;
  for (final AzGapRow g in gaps) {
    if (g.pay > maxPay) maxPay = g.pay;
  }
  await AppSheetShell.show<void>(
    context,
    header: const SheetHeader(
      title: '这个月要还的，那个月拿得出来吗',
      subtitle: '未来 12 个月',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: <SheetMetric>[
          SheetMetric(label: '最紧张的是', value: worst.month),
          SheetMetric(label: '那个月要还', value: MoneyFormat.yuan0(worst.pay)),
          SheetMetric(
            label: worst.gap > 0 ? '还差' : '都还得上',
            value: MoneyFormat.yuan0(worst.gap > 0 ? worst.gap : 0),
          ),
        ],
        trend: <SheetTrendPoint>[
          for (final AzGapRow g in gaps)
            SheetTrendPoint(
              label: g.month,
              value: (g.pay / maxPay).clamp(0.0, 1.0).toDouble(),
              highlighted: g.gap > 0,
            ),
        ],
        updatedAt: worst.gap > 0
            ? '${worst.month} 要还 ${MoneyFormat.yuan0(worst.pay)}，'
                '能拿出 ${MoneyFormat.yuan0(worst.available)}，'
                '差 ${MoneyFormat.yuan0(worst.gap)}。动不了的钱未计入，这是估算。'
            : '未来 12 个月都还得上。动不了的钱未计入，这是估算。',
        actionLabel: '知道了',
        onAction: () => SheetActions.close(sheetContext),
      ),
    ),
  );
}

/// ⑦ 先还哪一笔最划算（7.10）：默认按「实际一年要付多少」从高到低。
Future<void> showAzPayoffSheet(BuildContext context) async {
  final AzController az = context.read<AzController>();
  final AzData d = az.data;
  final List<LiabilityRecord> order = AzMath.payoffOrder(d);
  final double topRate =
      order.isEmpty ? 0 : AzMath.realAnnualRate(order.first);
  final double oneYearSave = order.isEmpty
      ? 0
      : order.first.principal * topRate;
  double maxRate = 0.01;
  for (final LiabilityRecord x in order) {
    final double r = AzMath.realAnnualRate(x);
    if (r > maxRate) maxRate = r;
  }
  await AppSheetShell.show<void>(
    context,
    header: const SheetHeader(
      title: '先还哪一笔最划算',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: <SheetMetric>[
          SheetMetric(
            label: order.isEmpty ? '现在没有欠款' : '先还：${order.first.name}',
            value: order.isEmpty
                ? '—'
                : '${(topRate * 100).toStringAsFixed(1)}%',
          ),
          SheetMetric(label: '一年大约能少付', value: MoneyFormat.yuan0(oneYearSave)),
          SheetMetric(label: '一共几笔', value: '${order.length} 笔'),
        ],
        trend: <SheetTrendPoint>[
          for (final LiabilityRecord x in order)
            SheetTrendPoint(
              label: x.name,
              value: (AzMath.realAnnualRate(x) / maxRate)
                  .clamp(0.0, 1.0)
                  .toDouble(),
              highlighted: x == order.first,
            ),
        ],
        updatedAt: order.isEmpty
            ? '暂无欠款'
            : '先还「${order.first.name}」：实际一年 '
                '${(topRate * 100).toStringAsFixed(1)}%，现在最贵。',
        actionLabel: '知道了',
        onAction: () => SheetActions.close(sheetContext),
      ),
    ),
  );
}
