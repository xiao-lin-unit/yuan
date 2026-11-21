import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../screens/commons/sheet/app_sheet_shell.dart';
import '../../screens/commons/sheet/contents/overview_sheet_content.dart';
import '../../screens/commons/sheet/contents/select_sheet_content.dart';
import '../../screens/commons/sheet/parts/sheet_primitives.dart';
import '../../screens/commons/sheet/sheet_models.dart';
import '../../service/account_controller.dart';
import '../../service/ledger/az_controller.dart';
import '../../utils/money_format.dart';
import '../commons/icons/app_icons.dart';

/// 表单类入口统一从这里导出：页面只 `import 'az_sheets.dart'` 一处。
export 'az_form_sheets.dart';

/// 资债模块的**展示类 Sheet**。
///
/// 【职责边界】资债只做记录：月收入、每月必须花的钱、应急金月数、
/// 物价假设、偿债档位等是情境设计（8.2 / 13.2）与分析（7.9）的输入，
/// 月末快照属分析（8.1.3 / 13.12），都不在本模块录入或直接展示。
/// 本文件只留基于**已记录数据**的只读展示，以及估值口径这一记录口径
/// （6.4，放资产汇总行的下拉，不单开设置弹层）。
///
/// 【契约】全部走 `AppSheetShell.show` 唯一外壳 + 既有内容组件：
///   · 估值口径 → [SelectSheetContent]（未指定选择）；
///   · 划不划算 / 逐月缺口 / 先还哪一笔 → [OverviewSheetContent]（仅展示）。
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
      title: '估值口径',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: SelectSheetContent<ValuationMode>(
      options: const <SheetOption<ValuationMode>>[
        SheetOption<ValuationMode>(
          value: ValuationMode.cost,
          label: '买入价',
          icon: AppIcons.balanceAdjust,
        ),
        SheetOption<ValuationMode>(
          value: ValuationMode.latest,
          label: '最新价',
          icon: AppIcons.investment,
        ),
      ],
      initialValue: current,
      actionLabel: '确定',
      onApplyAsync: (ValuationMode v) async {
        await context.read<AzWriteController>().setPreference(
              'valuation_mode',
              v.dbValue,
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
      title: '划不划算',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: list.isEmpty
            ? const <SheetMetric>[
                SheetMetric(label: '关联债', value: '0 笔'),
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
            ? '无关联'
            : '仅每月进账',
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
      title: '偿债缺口',
      subtitle: '12 个月',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: <SheetMetric>[
          SheetMetric(label: '最紧月', value: worst.month),
          SheetMetric(label: '当月还', value: MoneyFormat.yuan0(worst.pay)),
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
      title: '还款顺序',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: <SheetMetric>[
          SheetMetric(
            label: order.isEmpty ? '无欠款' : '先还：${order.first.name}',
            value: order.isEmpty
                ? '—'
                : '${(topRate * 100).toStringAsFixed(1)}%',
          ),
          SheetMetric(label: '年少付', value: MoneyFormat.yuan0(oneYearSave)),
          SheetMetric(label: '笔数', value: '${order.length} 笔'),
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
