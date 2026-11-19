import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/asset_liability/az_db.dart';
import '../../database/asset_liability/az_math.dart';
import '../../database/asset_liability/az_record.dart';
import '../../screens/commons/sheet/app_sheet_shell.dart';
import '../../screens/commons/sheet/contents/category_sheet_content.dart';
import '../../screens/commons/sheet/contents/confirm_sheet_content.dart';
import '../../screens/commons/sheet/contents/form_sheet_content.dart';
import '../../screens/commons/sheet/contents/overview_sheet_content.dart';
import '../../screens/commons/sheet/contents/select_sheet_content.dart';
import '../../screens/commons/sheet/parts/sheet_primitives.dart';
import '../../screens/commons/sheet/sheet_form_items.dart';
import '../../screens/commons/sheet/sheet_models.dart';
import '../../service/account_controller.dart';
import '../../service/az_controller.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import '../commons/icons/app_icons.dart';

/// 资债模块的**表单类 Sheet**。
///
/// 【契约，一条都没破】所有弹层都走 `AppSheetShell.show` 这一个壳：
///   · header 构造期静态传入，统一 `SheetHeader(centered: true)` + 取消 / 保存；
///   · 修改 / 新增 → [FormSheetContent]（配 [FormSheetController]）；
///   · 未指定选择 → [SelectSheetContent]；确认 → [ConfirmSheetContent]；
///   · 仅展示 → [OverviewSheetContent]；带图标的类型选择 → 大类选择器见
///     `az_sheets.dart` 的 [showAzAssetClassSheet]；
///   · 其他操作 → 本文件里的「算一下提前还」用表单 + 概览两步，仍是既有组件。
/// **没有新建任何 XxxSheetContent**，也没有第二套弹层外壳。
///
/// 【一个功能只有一个入口】「万一要我还的钱」只在 [showAzContingentSheet]
/// 可编辑；「算不算进总账」只在 [showAzCountedSheet] 可切；口径开关只在
/// `az_sheets.dart` 的设置弹层里。其余位置全是只读展示或跳转（13.13）。
///
/// 【静态优先 / 动态逻辑】Sheet 内容组件都是项目里现成的；本文件只有
/// 「打开弹层 + 把表单值写库」的函数。唯一一处自定义控件 [_InlineSelect]
/// 是私有 StatefulWidget，工作逻辑写在它紧邻的注释里。

const String _kAmountHint = '只填数字，例如 12000';
const String _kDateHint = '可不填，例如 2027-03-15';

/// 表单内联下拉的私有控件（不是新 Sheet 内容组件）。
///
/// 【动态逻辑，工作逻辑写清楚】为什么动态：选了哪一项是用户点击后才有的
/// 状态。用最朴素的 StatefulWidget + setState：
///   ① initState 记下初值；② 点选 → setState 更新 + 把值写回 FormSheetContent；
///   ③ 初值不在选项里（坏数据兜底）时显示第一项，业务层用默认值兜底；
///   ④ 组件销毁时 state 随之消失。没有 Notifier、没有跨帧注册。
/// 刻意**不在 initState 里回传初值**：父组件的 _setValue 会 setState，
/// 在 build 阶段调用会触发「markNeedsBuild during build」。
class _SelectOption {
  const _SelectOption(this.value, this.label);

  final String value;
  final String label;
}

class _InlineSelect extends StatefulWidget {
  const _InlineSelect({
    required this.options,
    required this.initial,
    required this.onChanged,
  });

  final List<_SelectOption> options;
  final String initial;
  final ValueChanged<Object?> onChanged;

  @override
  State<_InlineSelect> createState() => _InlineSelectState();
}

class _InlineSelectState extends State<_InlineSelect> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final String effective = widget.options.any(
          (_SelectOption o) => o.value == _value,
        )
        ? _value
        : widget.options.first.value;
    return DropdownButton<String>(
      value: effective,
      isExpanded: true,
      items: <DropdownMenuItem<String>>[
        for (final _SelectOption o in widget.options)
          DropdownMenuItem<String>(value: o.value, child: Text(o.label)),
      ],
      onChanged: (String? v) {
        if (v == null) return;
        setState(() => _value = v);
        widget.onChanged(v);
      },
    );
  }
}

double _num(SheetFormValues v, String key, [double fallback = 0]) =>
    double.tryParse(v.text(key).trim()) ?? fallback;

int _count(SheetFormValues v, String key, [int fallback = 0]) =>
    int.tryParse(v.text(key).trim()) ?? fallback;

DateTime? _date(String raw) => DateTime.tryParse(raw.trim());

String _positive(String? raw, String label) {
  final double? v = double.tryParse((raw ?? '').trim());
  if (v == null || v <= 0) return '$label要填正数，不能是 0 或空';
  return '';
}

/// 顶栏：取消 / 居中标题 / 保存（账户模块已统一的形态）。
Widget _header(String title, FormSheetController controller) => SheetHeader(
      title: title,
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: controller.submit,
      ),
    );

/// ① 新增 / 编辑一项资产（6.3）。大类只选一次、不进二级菜单（10.5），
/// 选中后表单里的其余字段对所有大类都适用，专属字段（股票代码、房子用途）
/// 用可选文本收在同一张表里，不套第二层弹窗。
Future<void> showAzAssetSheet(
  BuildContext context, {
  AssetRecord? existing,
}) async {
  final FormSheetController ctl = FormSheetController();
  final DateTime now = DateTime.now();
  final AssetRecord base = existing ??
      AssetRecord(
        assetClass: AssetClass.misc,
        name: '',
        cost: 1,
        createdAt: now,
        updatedAt: now,
      );
  await AppSheetShell.show<void>(
    context,
    header: _header(existing == null ? '新增一项东西' : '编辑这项东西', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '保存',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '给它起个名',
          initialValue: base.name,
          hint: '出租的那套小房 / 借给老张的钱',
          validator: (String v) => v.trim().isEmpty ? '还差一个名字' : null,
        ),
        SheetFormCustomItem(
          key: 'asset_class',
          label: '这是什么（只选一次）',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _InlineSelect(
            options: <_SelectOption>[
              for (final AssetClass c in AssetClass.values)
                _SelectOption(c.code, c.label)
            ],
            initial: base.assetClass.code,
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'cost',
          label: '买它一共花了多少',
          initialValue: base.cost.toStringAsFixed(0),
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '买它一共花了多少');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormSingleLineTextItem(
          key: 'code',
          label: '代码 / 编号（可不填）',
          initialValue: base.code,
        ),
        SheetFormSingleLineTextItem(
          key: 'latest_value',
          label: '现在大概值多少（可不填）',
          initialValue: base.latestValue?.toStringAsFixed(0) ?? '',
          hint: '默认不填，按买入价算，不用天天盯价格',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'monthly_in',
          label: '它每个月给你多少钱',
          initialValue: base.monthlyIn.toStringAsFixed(0),
          hint: '租金、利息、分红；没有就填 0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'monthly_out',
          label: '它每个月要你花多少钱',
          initialValue: base.monthlyOut.toStringAsFixed(0),
          hint: '物业、保险、保养；借钱的月供不用填在这儿',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'exit_cost',
          label: '提前拿会不会扣钱',
          initialValue: base.exitCost.toStringAsFixed(0),
          hint: '手续费、税费估算',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormCustomItem(
          key: 'liquidity',
          label: '多久能变成现金',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _InlineSelect(
            options: <_SelectOption>[
              for (final Liquidity l in Liquidity.values)
                _SelectOption(l.dbValue.toString(), l.label)
            ],
            initial: base.liquidity.dbValue.toString(),
            onChanged: onChanged,
          ),
        ),
        SheetFormCustomItem(
          key: 'stability',
          label: '这笔进账稳不稳',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _InlineSelect(
            options: <_SelectOption>[
              for (final AzStability s in AzStability.values)
                _SelectOption(s.dbValue, s.label)
            ],
            initial: base.stability.dbValue,
            onChanged: onChanged,
          ),
        ),
        SheetFormToggleItem(
          key: 'counted',
          label: '算不算进「真正属于你的钱」',
          initialValue: base.counted,
        ),
        SheetFormSingleLineTextItem(
          key: 'intention',
          label: '以后打算拿它做什么（可不填）',
          initialValue: base.intention,
        ),
        SheetFormMultiLineTextItem(
          key: 'note',
          label: '备注（可不填）',
          initialValue: base.note,
          minLines: 2,
          maxLines: 3,
          showCounter: false,
        ),
        const SheetFormNoteItem(
          key: 'hint',
          text: '「每个月要你花多少钱」只填这项东西自己的开销；'
              '借钱的月供在「欠的每一笔」里算过了，不重复扣。',
          centered: true,
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        final Map<String, Object?> m = base.toMap()..['id'] = base.id;
        m['name'] = v.text('name').trim();
        m['asset_class'] = v.get<String>('asset_class') ?? base.assetClass.code;
        m['cost'] = _num(v, 'cost', base.cost);
        m['code'] = v.text('code').trim();
        final double? latest = double.tryParse(v.text('latest_value').trim());
        m['latest_value'] = latest;
        m['valued_at'] = latest == null
            ? base.valuedAt?.millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch;
        m['valuation_source'] = latest == null
            ? base.valuationSource.dbValue
            : ValuationSource.manual.dbValue;
        m['monthly_in'] = _num(v, 'monthly_in');
        m['monthly_out'] = _num(v, 'monthly_out');
        m['exit_cost'] = _num(v, 'exit_cost');
        m['liquidity'] = int.tryParse(
              v.get<String>('liquidity') ?? '${base.liquidity.dbValue}',
            ) ??
            base.liquidity.dbValue;
        m['stability'] = v.get<String>('stability') ?? base.stability.dbValue;
        m['counted'] = v.flag('counted') ? 1 : 0;
        m['intention'] = v.text('intention').trim();
        m['note'] = v.text('note').trim();
        m['icon_key'] = AssetClass.fromDb(
          m['asset_class'] as String?,
        ).iconKey;
        await context.read<AzWriteController>().saveAsset(
              AssetRecord.fromMap(m),
            );
      },
    ),
  );
}

/// ② 新增 / 编辑一笔欠款（7.4 / 7.5）。「实际一年要付多少」由
/// AzMath.realAnnualRate 算，用户三选一输入方式里这里用「直接填利率 +
/// 每期费用」，软件反算真实成本，不让用户懂年化。
Future<void> showAzLiabilitySheet(
  BuildContext context, {
  LiabilityRecord? existing,
}) async {
  final FormSheetController ctl = FormSheetController();
  final DateTime now = DateTime.now();
  final LiabilityRecord base = existing ??
      LiabilityRecord(
        type: LiabilityType.other,
        name: '',
        principal: 1,
        createdAt: now,
        updatedAt: now,
      );
  await AppSheetShell.show<void>(
    context,
    header: _header(existing == null ? '新增一笔欠款' : '编辑这笔欠款', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '保存',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '欠谁 / 起个名',
          initialValue: base.name,
          hint: 'XX 银行房贷',
          validator: (String v) => v.trim().isEmpty ? '还差一个名字' : null,
        ),
        SheetFormCustomItem(
          key: 'liability_type',
          label: '欠的什么钱',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _InlineSelect(
            options: <_SelectOption>[
              for (final LiabilityType t in LiabilityType.values)
                _SelectOption(t.dbValue, t.label)
            ],
            initial: base.type.dbValue,
            onChanged: onChanged,
          ),
        ),
        SheetFormCustomItem(
          key: 'purpose',
          label: '这钱借来干了什么',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _InlineSelect(
            options: <_SelectOption>[
              for (final DebtPurpose p in DebtPurpose.values)
                _SelectOption(p.dbValue, p.label)
            ],
            initial: base.purpose.dbValue,
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'principal',
          label: '现在还欠多少',
          initialValue: base.principal.toStringAsFixed(0),
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '现在还欠多少');
            if (e.isNotEmpty) return e;
            return null;
          },
        ),
        SheetFormSingleLineTextItem(
          key: 'rate',
          label: '合同上写的利率（%）',
          initialValue: (base.rate * 100).toStringAsFixed(2),
          hint: '例如 3.10 表示 3.1%',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormCustomItem(
          key: 'rate_type',
          label: '利率会不会变',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _InlineSelect(
            options: <_SelectOption>[
              for (final RateType r in RateType.values)
                _SelectOption(r.dbValue, r.label)
            ],
            initial: base.rateType.dbValue,
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'monthly_pay',
          label: '每期一共还多少',
          initialValue: base.monthlyPay.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'monthly_interest',
          label: '其中利息',
          initialValue: base.monthlyInterest.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'monthly_fee',
          label: '其中手续费',
          initialValue: base.monthlyFee.toStringAsFixed(0),
          hint: '「免息分期」也要填，真实成本按这个折算',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormCustomItem(
          key: 'repay_method',
          label: '怎么还',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _InlineSelect(
            options: <_SelectOption>[
              for (final RepayMethod r in RepayMethod.values)
                _SelectOption(r.dbValue, '${r.label}（${r.hint}）')
            ],
            initial: base.repayMethod.dbValue,
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'pay_day',
          label: '每月几号还（可不填）',
          initialValue: base.payDay?.toString() ?? '',
          keyboardType: TextInputType.number,
        ),
        SheetFormSingleLineTextItem(
          key: 'total_terms',
          label: '一共几期（可不填）',
          initialValue: base.totalTerms.toString(),
          keyboardType: TextInputType.number,
        ),
        SheetFormSingleLineTextItem(
          key: 'paid_terms',
          label: '已经还了几期',
          initialValue: base.paidTerms.toString(),
          keyboardType: TextInputType.number,
        ),
        SheetFormSingleLineTextItem(
          key: 'end_date',
          label: '什么时候到期',
          initialValue: base.endDate == null
              ? ''
              : '${base.endDate!.year}-${base.endDate!.month.toString().padLeft(2, '0')}-${base.endDate!.day.toString().padLeft(2, '0')}',
          hint: _kDateHint,
        ),
        SheetFormMultiLineTextItem(
          key: 'note',
          label: '备注（可不填）',
          initialValue: base.note,
          minLines: 2,
          maxLines: 3,
          showCounter: false,
        ),
        const SheetFormNoteItem(
          key: 'hint',
          text: '软件不联网、不替银行计息：实际一年要付多少按你填的数和费用折算，'
              '是估算，以账单为准。本金不算花掉的钱。',
          centered: true,
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        final Map<String, Object?> m = base.toMap()..['id'] = base.id;
        final String type = v.get<String>('liability_type') ?? base.type.dbValue;
        final double pay = _num(v, 'monthly_pay');
        final double interest = _num(v, 'monthly_interest');
        final double fee = _num(v, 'monthly_fee');
        m['name'] = v.text('name').trim();
        m['liability_type'] = type;
        m['icon_key'] = LiabilityType.fromDb(type).iconKey;
        m['purpose'] = v.get<String>('purpose') ?? base.purpose.dbValue;
        m['principal'] = _num(v, 'principal', base.principal);
        m['original_principal'] = base.originalPrincipal == 0
            ? m['principal']
            : base.originalPrincipal;
        m['rate'] = _num(v, 'rate', base.rate * 100) / 100;
        m['rate_type'] = v.get<String>('rate_type') ?? base.rateType.dbValue;
        m['monthly_pay'] = pay;
        m['monthly_interest'] = interest;
        m['monthly_fee'] = fee;
        m['monthly_principal'] =
            (pay - interest - fee) > 0 ? pay - interest - fee : 0;
        m['repay_method'] =
            v.get<String>('repay_method') ?? base.repayMethod.dbValue;
        m['pay_day'] = int.tryParse(v.text('pay_day').trim());
        m['total_terms'] = _count(v, 'total_terms');
        m['paid_terms'] = _count(v, 'paid_terms');
        m['end_date'] = _date(v.text('end_date'))?.millisecondsSinceEpoch;
        m['note'] = v.text('note').trim();
        await context.read<AzWriteController>().saveLiability(
              LiabilityRecord.fromMap(m),
            );
      },
    ),
  );
}

/// ③ 两张成对清单的唯一编辑入口（7.11 / 13.13）。
/// 编辑「万一要我还的钱」时可勾「转成我欠的钱」，在同一张表里完成转换，
/// **不套第二层弹窗**（设计原则第二条）。
Future<void> showAzContingentSheet(
  BuildContext context, {
  ContingentRecord? existing,
  required ContingentKind kind,
}) async {
  final FormSheetController ctl = FormSheetController();
  final DateTime now = DateTime.now();
  final ContingentRecord base = existing ??
      ContingentRecord(
        kind: kind,
        title: '',
        maxAmount: 0,
        createdAt: now,
        updatedAt: now,
      );
  await AppSheetShell.show<void>(
    context,
    header: _header(
      existing == null ? '记一笔' : '编辑这一笔',
      ctl,
    ),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '保存',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'title',
          label: kind == ContingentKind.contingent ? '替谁担的 / 什么事' : '保了什么',
          initialValue: base.title,
          validator: (String v) => v.trim().isEmpty ? '还差一个名字' : null,
        ),
        SheetFormSingleLineTextItem(
          key: 'max_amount',
          label: '最多可能要还 / 最多替你付',
          initialValue: base.maxAmount.toStringAsFixed(0),
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'condition_text',
          label: kind == ContingentKind.contingent
              ? '什么情况下会轮到我还'
              : '什么情况不赔',
          initialValue: base.conditionText,
        ),
        SheetFormSingleLineTextItem(
          key: 'eta',
          label: '大概什么时候 / 保到哪天',
          initialValue: base.eta,
          hint: _kDateHint,
        ),
        SheetFormMultiLineTextItem(
          key: 'note',
          label: '备注（可不填）',
          initialValue: base.note,
          minLines: 2,
          maxLines: 3,
          showCounter: false,
        ),
        if (existing != null && kind == ContingentKind.contingent)
          const SheetFormToggleItem(
            key: 'convert',
            label: '转成我欠的钱（正式进「一共欠多少」）',
            initialValue: false,
          ),
        SheetFormNoteItem(
          key: 'hint',
          text: kind == ContingentKind.contingent
              ? '默认不算进「一共欠多少」，也不进「真正属于你的钱」。转成正式欠款后才进总账。'
              : '这些都不算资产、也不抵扣欠款，只是让你知道出事时有人兜底。软件不评价保障够不够。',
          centered: true,
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        final Map<String, Object?> m = base.toMap()..['id'] = base.id;
        m['title'] = v.text('title').trim();
        m['max_amount'] = _num(v, 'max_amount');
        m['condition_text'] = v.text('condition_text').trim();
        m['eta'] = v.text('eta').trim();
        m['note'] = v.text('note').trim();
        final ContingentRecord row = ContingentRecord.fromMap(m);
        final AzWriteController write = context.read<AzWriteController>();
        if (v.flag('convert') && existing != null) {
          await write.convertContingentToDebt(
            item: row,
            debt: LiabilityRecord(
              type: LiabilityType.other,
              name: row.title,
              purpose: DebtPurpose.t6,
              principal: row.maxAmount,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          return;
        }
        await write.saveContingent(row);
      },
    ),
  );
}

/// ④ 「更新一下现在值多少」（6.4）：填一次价，留一次痕，历史不覆盖。
Future<void> showAzValuationSheet(
  BuildContext context,
  AssetRecord asset,
) async {
  final FormSheetController ctl = FormSheetController();
  await AppSheetShell.show<void>(
    context,
    header: _header('更新一下现在值多少', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '记下这个价',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'value',
          label: '现在大概值多少',
          initialValue: asset.latestValue?.toStringAsFixed(0) ?? '',
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '现在大概值多少');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormNoteItem(
          key: 'hint',
          text: '这是你 ${MoneyFormat.yuan0(asset.cost)} 买入时花的钱。'
              '填了新价之后会标「这是你 X 天前自己填的」，软件不联网，不会自动变；'
              '每次更新都留痕，历史不覆盖。',
          centered: true,
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        await context.read<AzWriteController>().updateValuation(
              asset,
              _num(v, 'value'),
            );
      },
    ),
  );
}

/// ⑤ 记一笔买入 / 卖出（6.5）。卖出数量超过持仓由 Controller 拦下。
Future<void> showAzTradeSheet(
  BuildContext context,
  AssetRecord asset,
  TradeDirection direction,
) async {
  final FormSheetController ctl = FormSheetController();
  final bool buy = direction == TradeDirection.buy;
  await AppSheetShell.show<void>(
    context,
    header: _header(buy ? '记一笔买入' : '记一笔卖出', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: buy ? '一共从卡里出去这些，对吗？' : '这次到手这些，对吗？',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'unit_price',
          label: '每个多少钱',
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '每个多少钱');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormSingleLineTextItem(
          key: 'quantity',
          label: buy ? '买了多少' : '卖了多少',
          hint: '股数 / 份数',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, buy ? '买了多少' : '卖了多少');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormSingleLineTextItem(
          key: 'fee',
          label: buy ? '另外交了多少钱' : '另外扣了多少钱',
          initialValue: '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'occurred_at',
          label: '哪天买卖的',
          initialValue: _todayText(),
          hint: _kDateHint,
        ),
        const SheetFormNoteItem(
          key: 'hint',
          text: '买入只是「现金换成东西」，不算「这个月花了多少」；'
              '卖出到手的钱也不算收入。只有卖掉那一次才结算赚没赚。',
          centered: true,
        ),
        const SheetFormNoteItem(
          key: 'boundary',
          text: '本轮只登记买卖批次并结算赚亏，不改账户余额、不写账户流水；'
              '卡里扣的钱 / 回的钱等记账模块接上账户流水才会自动记。',
          centered: true,
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        await context.read<AzWriteController>().recordTrade(
              asset: asset,
              direction: direction,
              unitPrice: _num(v, 'unit_price'),
              quantity: _num(v, 'quantity'),
              fee: _num(v, 'fee'),
              occurredAt: _date(v.text('occurred_at')),
            );
      },
    ),
  );
}

/// ⑥ 记一笔还款（7.8 / 7.12）。只登记「这一期还了」，本金与账户余额
/// 要成对变动，本轮不动金额，界面已写明这句边界。
Future<void> showAzRepaySheet(
  BuildContext context,
  LiabilityRecord debt,
  List<RepayPlanRecord> plans,
) async {
  final FormSheetController ctl = FormSheetController();
  await AppSheetShell.show<void>(
    context,
    header: _header('记一笔还款', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '记下这一期',
      items: <SheetFormItem>[
        if (plans.isNotEmpty)
          SheetFormCustomItem(
            key: 'plan_id',
            label: '还的是哪一期',
            builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
                _InlineSelect(
              options: <_SelectOption>[
                for (final RepayPlanRecord p in plans)
                  _SelectOption(
                    p.id.toString(),
                    '第 ${p.termNo} 期 · ${MoneyFormat.yuan0(p.total)}',
                  )
              ],
              initial: plans.first.id.toString(),
              onChanged: onChanged,
            ),
          ),
        SheetFormSingleLineTextItem(
          key: 'amount',
          label: '这次还了多少',
          initialValue: debt.monthlyPay.toStringAsFixed(0),
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '这次还了多少');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormSingleLineTextItem(
          key: 'reason',
          label: '备注 / 这次怎么还的',
          hint: '全额 / 最低 / 分期 / 部分 / 提前',
        ),
        const SheetFormNoteItem(
          key: 'hint',
          text: '本金只是把现金换成少欠一点，不算花掉的钱；利息与费用才是真花掉的。'
              '还款本身不进「记支出」。',
          centered: true,
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        if (plans.isEmpty) {
          throw ArgumentError('这一笔还没有逐期计划，先去编辑里填上期数');
        }
        final String picked = v.get<String>('plan_id') ?? '${plans.first.id}';
        await context.read<AzWriteController>().markPlanPaid(
              planId: int.tryParse(picked) ?? plans.first.id!,
              actualAmount: _num(v, 'amount'),
              reason: v.text('reason').trim(),
            );
      },
    ),
  );
}

/// ⑦ 「算一下提前还」两步：先用表单收金额（[FormSheetContent] 无 onSubmit
/// 时会把值回传给 show 的返回值），再用 [OverviewSheetContent] 把四件事
/// 一次摆出来。两步是**前后两个弹层**，不是弹窗里套弹窗。
Future<void> showAzPrepaySheet(
  BuildContext context,
  LiabilityRecord debt,
) async {
  final FormSheetController ctl = FormSheetController();
  final SheetFormValues? values =
      await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '提前还 ${debt.name}',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '算一下',
        emphasized: true,
        onTap: ctl.submit,
      ),
    ),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '算一下',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'amount',
          label: '打算提前还多少',
          hint: '还剩 ${MoneyFormat.yuan0(debt.principal)} 没还',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '打算提前还多少');
            return e.isEmpty ? null : e;
          },
        ),
      ],
    ),
  );
  if (values == null) return;
  final double amount = _num(values, 'amount');
  if (amount <= 0) return;

  final AzController az = context.read<AzController>();
  final AzPrepay p = AzMath.prepayPlan(
    az.data,
    context.read<AccountController>().all,
    debt,
    amount > debt.principal ? debt.principal : amount,
  );
  await AppSheetShell.show<void>(
    context,
    header: SheetHeader(
      title: '提前还，要看四件事',
      centered: true,
      leading: const SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: <SheetMetric>[
          SheetMetric(label: '① 能省多少利息', value: MoneyFormat.yuan0(p.saveInterest)),
          SheetMetric(label: '② 违约金 / 剩余手续费', value: MoneyFormat.yuan0(p.penalty)),
          SheetMetric(label: '扣完实际净省', value: MoneyFormat.yuan0(p.netSave)),
        ],
        changeLabel: p.safe ? '可以还' : '先别急',
        updatedAt:
            '③ 还完手上还剩能花的钱 ${MoneyFormat.yuan0(p.cashAfter)}，够撑 ${p.months.toStringAsFixed(1)} 个月必须花的钱。'
            '④ ${p.safe ? '建议先留够 3 个月，再拿多出来的还。' : '建议先留够 3 个月再还，应急金不够时别急着省利息。'}'
            '按实际一年 ${(p.realRate * 100).toStringAsFixed(1)}% 估算，各家算法不一样，以账单为准。',
        actionLabel: '知道了',
        onAction: () => SheetActions.close(sheetContext),
      ),
    ),
  );
}

/// ⑧ 「算不算进总账」（6.3 / 6.7）：一个只影响家底账的开关。
/// 用 SelectSheetContent 而不是新组件；异步写盘成功才关弹层。
Future<void> showAzCountedSheet(
  BuildContext context,
  AssetRecord asset,
) async {
  await AppSheetShell.show<String>(
    context,
    header: const SheetHeader(
      title: '算不算进「真正属于你的钱」',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: SelectSheetContent<String>(
      options: const <SheetOption<String>>[
        SheetOption<String>(value: 'yes', label: '算进总账', icon: AppIcons.check),
        SheetOption<String>(value: 'no', label: '不算进总账', icon: AppIcons.block),
      ],
      initialValue: asset.counted ? 'yes' : 'no',
      actionLabel: '就这么定',
      onApplyAsync: (String value) async {
        final Map<String, Object?> m = asset.toMap()..['id'] = asset.id;
        m['counted'] = value == 'yes' ? 1 : 0;
        m['counted_reason'] = value == 'yes'
            ? ''
            : '日常用的东西，你自己关掉了「算进总账」，随时可以打开';
        await context.read<AzWriteController>().saveAsset(
              AssetRecord.fromMap(m),
            );
      },
    ),
  );
}

/// ⑨ 删除确认（10.7 回收站 30 天）。异步写盘成功才关弹层。
Future<void> showAzDeleteSheet(
  BuildContext context, {
  required String title,
  required String description,
  required Future<void> Function() onConfirm,
}) async {
  await AppSheetShell.show<void>(
    context,
    header: const SheetHeader(
      title: '放进回收站',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: ConfirmSheetContent(
      title: title,
      description: description,
      secondaryLabel: '再想想',
      primaryLabel: '确认删除',
      intent: SheetIntent.danger,
      footnote: '30 天内可以恢复，不是真的删掉。',
      onPrimaryAsync: onConfirm,
    ),
  );
}

/// ⑩ 选资产大类（10.5 只选一次、带图标的类型选择）。
/// 新增资产时一步到位：这里回传大类，调用方再打开同一张表单并预选。
Future<AssetClass?> showAzAssetClassSheet(BuildContext context) =>
    AppSheetShell.show<AssetClass>(
      context,
      header: const SheetHeader(
        title: '你新增的是什么？',
        subtitle: '只选一次，选完把要填的几项一次填完',
        trailing: SheetCloseButton(),
      ),
      child: CategorySheetContent<AssetClass>(
        categories: <SheetCategory<AssetClass>>[
          for (final AssetClass c in AssetClass.values)
            SheetCategory<AssetClass>(
              value: c,
              label: c.label,
              icon: _classIcon(c.iconKey),
            )
        ],
        hint: '卡里的钱和动不了的钱记在账户页，这里只记别的。',
      ),
    );

IconData _classIcon(String key) => switch (key) {
      'finance' => AppIcons.finance,
      'investment' => AppIcons.investment,
      'housing' => AppIcons.housing,
      'car' => AppIcons.car,
      'gift' => AppIcons.gift,
      _ => AppIcons.other,
    };

String _todayText() {
  final DateTime d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
