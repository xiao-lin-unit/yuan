import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
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
import '../../service/ledger/az_controller.dart';
import '../../utils/money_format.dart';
import '../commons/icons/app_icons.dart';

/// 资债模块的**表单类 Sheet**。
///
/// 【契约，一条都没破】所有弹层都走 `AppSheetShell.show` 这一个壳：
///   · header 构造期静态传入，统一 `SheetHeader(centered: true)` + 取消 / 保存；
///   · 修改 / 新增 → [FormSheetContent]（配 [FormSheetController]）；
///   · 未指定选择 → [SelectSheetContent]；确认 → [ConfirmSheetContent]；
///   · 仅展示 → [OverviewSheetContent]；带图标的类型选择 → 大类选择器见
///     本文件的 [showAzAssetClassSheet]；
///   · 其他操作 → 本文件里的「算一下提前还」用表单 + 概览两步，仍是既有组件。
/// **没有新建任何 XxxSheetContent**，也没有第二套弹层外壳。
///
/// 【一个功能只有一个入口】「万一要我还的钱」只在 [showAzContingentSheet]
/// 可编辑；「算不算进总账」只在 [showAzCountedSheet] 可切；估值口径只在
/// `az_sheets.dart` 的估值口径弹层里。情境设计参数与月末快照不在资债
/// 录入（8.2 / 13.12）。其余位置全是只读展示或跳转（13.13）。
///
/// 【静态优先 / 动态逻辑】Sheet 内容组件都是项目里现成的；本文件只有
/// 「打开弹层 + 把表单值写库」的函数。唯一一处自定义控件 [_InlineSelect]
/// 是私有 StatefulWidget，工作逻辑写在它紧邻的注释里。

const String _kAmountHint = '例如 12000';
const String _kDateHint = '例如 2027-03-15';

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
/// [subtitle] 只在「两步式新增」里回显刚选的大类 / 欠款类型；其它调用点
/// 不传，形态与原来逐像素一致。
Widget _header(
  String title,
  FormSheetController controller, {
  String? subtitle,
}) =>
    SheetHeader(
      title: title,
      subtitle: subtitle,
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: controller.submit,
      ),
    );

/// ① 新增 / 编辑一项资产（6.1 / 6.2 / 6.3）。
///
/// 【两步式·为什么】6.1 要求「一排图标只选一次，选完表单自动展开这一类
/// 专属的几项，其余字段藏起来」。所以新增入口先弹 [showAzAssetClassSheet]，
/// 把选中的大类用 [presetClass] 传进来；本函数据此**构造期**生成 items，
/// 运行期不换字段 —— 仍是全静态，没有 StatefulWidget / Notifier。
/// 编辑时类型取 existing.assetClass，不再让用户改（10.5 只选一次）。
///
/// 【未显示的字段不丢】onSubmit 用 `v.contains(key)` 判断：这一项没出现在
/// 表单里就保留 base.toMap() 的原值，编辑老记录不会把已有数据清成空串。
/// 大类与字段的对应关系见 [_assetItems]，每类只列自己用得上的那几项。
///
/// 【投资不按固定收付】A4/A5/A6 由买卖记录自动算（6.2 / 6.5），表单不出现
/// 月入 / 稳定性 / 月出，也不让用户填「预计一年赚多少」。老记录里若曾误填
/// 这类值，onSubmit 靠 `v.contains(key)` 保留原值、不清空不改数，AzMath 也
/// 不把它们算进流向账 —— 资债只记录，不推算收益。
Future<void> showAzAssetSheet(
  BuildContext context, {
  AssetRecord? existing,
  AssetClass? presetClass,
}) async {
  final FormSheetController ctl = FormSheetController();
  final DateTime now = DateTime.now();
  final AssetClass cls = existing?.assetClass ?? presetClass ?? AssetClass.misc;
  // 【代码唯一】构造期取一次共享账本快照：同一代码只允许登记一次。
  // 这是录入数据的查重，不是资产状态。空代码不参与；编辑时排除自己。
  final Set<String> usedCodes = <String>{
    for (final AssetRecord a in context.read<AzController>().data.assets)
      if (!a.isDeleted && a.id != existing?.id && a.code.trim().isNotEmpty)
        a.code.trim(),
  };
  // 【新增只录数据】状态列一律用底层默认值，不在新增里按类预设：
  // counted / liquidity / stability / use_mode / link_* 都不由表单决定。
  final AssetRecord base = existing ??
      AssetRecord(
        assetClass: cls,
        name: '',
        cost: 1,
        createdAt: now,
        updatedAt: now,
      );

  await AppSheetShell.show<void>(
    context,
    header: _header(
      existing == null ? '新增资产' : '编辑资产',
      ctl,
      subtitle: cls.label,
    ),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '保存',
      items: _assetItems(cls, base, usedCodes, existing == null),
      onSubmit: (SheetFormValues v) async {
        final Map<String, Object?> m = base.toMap()..['id'] = base.id;
        m['asset_class'] = cls.code;
        m['icon_key'] = cls.iconKey;
        if (v.contains('name')) m['name'] = v.text('name').trim();
        if (v.contains('cost')) m['cost'] = _num(v, 'cost', base.cost);
        // 投资「新增」：建档 + 首笔买入同事务。编辑档案时不显示这几个
        // 录入项，v.contains 为 false，原值原样保留。
        // 【股票 / 别的投资】已知价：填单价与数量，cost = 单价 × 数量 + 费用。
        // 【基金】金额申购：现实里用户下单时不知道净值，只知道「投了多少钱」
        //   和账单上「确认了多少份」；申购费是从这笔钱里扣的，不是额外加的。
        //   因此 cost 就是投进去的钱，确认净值由软件反算：
        //   净值 = (投了多少钱 − 申购费) ÷ 确认份额。
        //   反算后 unitPrice × quantity + fee 仍等于 cost，批次校验成立。
        final bool fund = cls == AssetClass.fund;
        final bool stockLike = cls.isInvestment && !fund;
        final bool firstBuy = existing == null &&
            ((stockLike &&
                    v.contains('unit_price') &&
                    v.contains('quantity')) ||
                (fund &&
                    v.contains('fund_amount') &&
                    v.contains('quantity')));
        double firstPrice = 0;
        double firstQty = 0;
        double firstFee = 0;
        if (firstBuy) {
          firstQty = _num(v, 'quantity');
          if (firstQty <= 0) {
            throw ArgumentError('份额要大于 0');
          }
          if (fund) {
            final double fundAmount = _num(v, 'fund_amount');
            final double fundFee = _num(v, 'fund_fee');
            if (fundFee < 0) {
              throw ArgumentError('申购费不能是负数');
            }
            if (fundAmount - fundFee <= 0) {
              throw ArgumentError('申购费不能比投进去的钱还多');
            }
            firstPrice = (fundAmount - fundFee) / firstQty;
            firstFee = fundFee;
            m['cost'] = fundAmount;
          } else {
            firstPrice = _num(v, 'unit_price');
            firstFee = _num(v, 'trade_fee');
            m['cost'] = firstPrice * firstQty + firstFee;
          }
          m['unit_price'] = firstPrice;
          m['quantity'] = firstQty;
          m['valuation_source'] = ValuationSource.cost.dbValue;
        }
        if (v.contains('code')) m['code'] = v.text('code').trim();
        if (v.contains('latest_value')) {
          final double? latest =
              double.tryParse(v.text('latest_value').trim());
          m['latest_value'] = latest;
          m['valued_at'] = latest == null
              ? base.valuedAt?.millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch;
          m['valuation_source'] = latest == null
              ? base.valuationSource.dbValue
              : ValuationSource.manual.dbValue;
        }
        if (v.contains('monthly_in')) {
          m['monthly_in'] = _num(v, 'monthly_in');
        }
        if (v.contains('monthly_out')) {
          m['monthly_out'] = _num(v, 'monthly_out');
        }
        if (v.contains('buy_date')) {
          final DateTime? d = _date(v.text('buy_date'));
          m['created_at'] = (d ?? base.createdAt).millisecondsSinceEpoch;
        }
        if (v.contains('intention')) {
          m['intention'] = v.text('intention').trim();
        }
        if (v.contains('depreciation_note')) {
          m['depreciation_note'] = v.text('depreciation_note').trim();
        }
        if (v.contains('second_note')) {
          m['depreciation_note'] = v.text('second_note').trim();
        }
        if (v.contains('note')) m['note'] = v.text('note').trim();
        final AssetRecord row = AssetRecord.fromMap(m);
        final AzWriteController write = context.read<AzWriteController>();
        if (firstBuy) {
          // 建档 + 首笔买入同一个事务，失败一起回滚，不会留下空标的。
          await write.saveInvestmentWithFirstBuy(
            record: row,
            unitPrice: firstPrice,
            quantity: firstQty,
            fee: firstFee,
          );
        } else {
          await write.saveAsset(row);
        }
      },
    ),
  );
}

/// 【资产大类 → 新增表单项】新增只录数据，不控制任何状态。
///
/// 口径（用户口径，优先于设计文档里 6.3 的通用字段表）：
///   · 只出现六类内容：名称、金额、数量、日期、备注、计息；
///   · 状态一律不在新增里出现：算不算 / 稳不稳 / 多久能拿回 / 用途 /
///     借出情形 / 关联房贷车贷 / 付款卡 / 已收回 / 可能收不回 ……
///     全部留到资产详情再做，本轮不碰详情页；
///   · 每类字段按自己现实里要填的东西定制，不是九类共用一张清单；
///   · A4 股票按「单价 × 股数 + 费用」；A5 基金按现实里的「金额申购、
///     份额赎回」单独一套：投了多少钱 + 申购费 + 确认份额，净值软件反算；
///     A6 别的投资沿用 A4 的已知价口径。三者不再共用同一份录入清单。
///   · 【退出费不在新增】赎回费 / 卖要扣 / 过户费 / 退股扣都是「将来卖
///     的时候大概扣多少」，卖出时才发生、才确定（基金还按持有期阶梯），
///     新增时不可能知道。exit_cost 一律用底层默认 0，留给详情维护。
///   · 状态列沿用底层默认值（counted / liquidity / stability / use_mode /
///     link_* 都不写），编辑时 v.contains 为 false 也不会静默改旧值。
///
/// 仍然沿用 az_assets 已有列，不升 DB 版本、不改 DDL：
///   intention / depreciation_note 是备注类 TEXT 列，按类放不同的文本；
///   created_at 是日期列，按类叫「哪天借 / 上牌日 / 哪天投」。
///
/// 【追加购买，本轮不做】首次买入在新增里一次录完；后续追加放详情页。
List<SheetFormItem> _assetItems(
  AssetClass cls,
  AssetRecord base,
  Set<String> usedCodes,
  bool isNew,
) {
  final bool invest = cls.isInvestment;
  final bool fund = cls == AssetClass.fund;
  final bool stockLike = invest && !fund;
  final bool loan = cls == AssetClass.loan;
  final bool business = cls == AssetClass.business;
  final bool property = cls == AssetClass.property;
  final bool vehicle = cls == AssetClass.vehicle;
  final bool valuable = cls == AssetClass.valuable;

  // 名称：按这一类在现实里怎么叫
  final String nameLabel = switch (cls) {
    AssetClass.loan => '借给谁',
    AssetClass.property => '哪套房',
    AssetClass.vehicle => '哪辆车',
    AssetClass.valuable => '什么东西',
    AssetClass.business => '哪门生意',
    _ => '名字',
  };
  final String costLabel = switch (cls) {
    AssetClass.loan => '借了多少',
    AssetClass.property => '一共花',
    AssetClass.vehicle => '落地价',
    AssetClass.valuable => '买时花',
    AssetClass.business => '投了多少',
    _ => '花了多少',
  };
  // 日期：一个真日期（买/借/投/上牌那天）
  final String dateLabel = switch (cls) {
    AssetClass.loan => '哪天借',
    AssetClass.business => '哪天投',
    AssetClass.vehicle => '上牌日',
    AssetClass.property => '哪天买',
    _ => '买入日',
  };
  // 备注类文本：每类放的东西不同，落 intention / depreciation_note
  final String noteLabel = switch (cls) {
    AssetClass.loan => '哪天还',
    AssetClass.property => '证照',
    AssetClass.vehicle => '手续',
    AssetClass.valuable => '放在哪',
    AssetClass.business => '占多少',
    _ => '',
  };
  final String? noteHint = switch (cls) {
    AssetClass.loan => '说好什么时候还，没约定就留空',
    AssetClass.property => '产权、共有、押证写一句',
    AssetClass.vehicle => '上牌、绿本、保单',
    AssetClass.valuable => '家里、保险箱',
    AssetClass.business => '写个大概就行',
    _ => null,
  };
  // 计息：只有「有约定利息/票息」的类才问，纯文本，不参与任何计算
  final bool hasInterest = loan || cls == AssetClass.otherInvest;
  final String interestLabel =
      cls == AssetClass.otherInvest ? '说好票息' : '说好利息';
  final String interestHint = cls == AssetClass.otherInvest
      ? '国债、年金写票息；没有就留空'
      : '借条上写的利息；没约定就留空';
  // 第二个备注：只有车和贵重物有（一年掉 / 凭证）
  final bool hasSecondNote = vehicle || valuable;
  final String secondNoteLabel = valuable ? '凭证' : '一年掉';
  final String secondNoteHint = valuable
      ? '发票、证书、原包装写一句'
      : '例如 12%，只记一句，不自动改价';

  // 金额类：按类取舍，不给残差类硬塞
  final bool hasLatestValue = !invest;
  final bool hasMonthlyIn = property; // 只有房产有租金这类进账金额
  final bool hasMonthlyOut = property || vehicle; // 房产持有成本 / 月养
  // 数量类：A4 按股，A5/A6 按份
  final String priceLabel = cls == AssetClass.fund ? '净值' : '单价';
  final String quantityLabel = cls == AssetClass.stock
      ? '股数'
      : (cls == AssetClass.fund ? '多少份' : '份数');

  final String nameHint = switch (cls) {
    AssetClass.loan => '借给老张的钱',
    AssetClass.stock => '例如 贵州茅台',
    AssetClass.fund => '例如 沪深300',
    AssetClass.otherInvest => '例如 三年国债',
    AssetClass.property => '出租的那套小房；车位单独写一条',
    AssetClass.vehicle => '家用车',
    AssetClass.valuable => '金条 100g',
    AssetClass.business => '和小李合开的店',
    _ => '自己起个名',
  };
  final String costHint = switch (cls) {
    AssetClass.loan => '实际给出去的钱',
    AssetClass.property => '含首付、契税、中介、装修',
    AssetClass.vehicle => '不是裸车价，是落地一共花的',
    AssetClass.valuable => '当时买花的钱',
    AssetClass.business => '投进去多少',
    _ => _kAmountHint,
  };
  final String? valueHint = switch (cls) {
    AssetClass.property => '一年改一次就行',
    AssetClass.vehicle => '卖二手车大概能拿多少',
    AssetClass.business => '自己填的，不是查来的',
    AssetClass.valuable => '自己填的，不是查来的',
    _ => null,
  };
  final String? remarkHint = switch (cls) {
    AssetClass.loan => '借条、转账记录写这儿',
    AssetClass.property => '产权、合同、交割写这儿',
    AssetClass.vehicle => '发票、改装、事故写这儿',
    AssetClass.valuable => '克重、成色、配件写这儿',
    AssetClass.business => '协议、去年分了多少、账目写这儿',
    _ => null,
  };
  final String mathHint = switch (cls) {
    AssetClass.stock => '一共花 = 单价 × 股数 + 费用',
    AssetClass.fund => '每份净值 = (投了多少 − 申购费) ÷ 多少份',
    _ => '一共花 = 单价 × 份数 + 费用',
  };

  return <SheetFormItem>[
    // ① 名称
    SheetFormSingleLineTextItem(
      key: 'name',
      label: nameLabel,
      initialValue: base.name,
      hint: nameHint,
      validator: (String v) => v.trim().isEmpty ? '请填$nameLabel' : null,
    ),
    // ② 金额：非投资手填，投资由首笔买入自动算
    if (!invest)
      SheetFormSingleLineTextItem(
        key: 'cost',
        label: costLabel,
        initialValue: base.cost.toStringAsFixed(0),
        hint: costHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String e = _positive(v, costLabel);
          return e.isEmpty ? null : e;
        },
      ),
    // ③ 已知价口径（A4 股票 / A6 别的投资）：填单价、数量、费用
    if (stockLike && isNew) ...<SheetFormItem>[
      SheetFormSingleLineTextItem(
        key: 'unit_price',
        label: priceLabel,
        hint: '每个多少钱',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String e = _positive(v, priceLabel);
          return e.isEmpty ? null : e;
        },
      ),
      SheetFormSingleLineTextItem(
        key: 'quantity',
        label: quantityLabel,
        hint: cls == AssetClass.stock ? '股数' : '份数',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String e = _positive(v, quantityLabel);
          return e.isEmpty ? null : e;
        },
      ),
      SheetFormSingleLineTextItem(
        key: 'trade_fee',
        label: '费用',
        initialValue: '0',
        hint: '佣金、手续费等，不填按 0',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String t = v.trim();
          if (t.isEmpty) return null;
          final double? f = double.tryParse(t);
          return (f == null || f < 0) ? '费用不能是负数' : null;
        },
      ),
    ],
    // ③′ 金额申购口径（A5 基金）：填金额、申购费、确认份额，净值软件反算
    if (fund && isNew) ...<SheetFormItem>[
      SheetFormSingleLineTextItem(
        key: 'fund_amount',
        label: '投了多少',
        hint: '申购时一共扣的钱',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String e = _positive(v, '投了多少');
          return e.isEmpty ? null : e;
        },
      ),
      SheetFormSingleLineTextItem(
        key: 'fund_fee',
        label: '申购费',
        initialValue: '0',
        hint: '从这笔钱里扣的，不填按 0',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String t = v.trim();
          if (t.isEmpty) return null;
          final double? f = double.tryParse(t);
          return (f == null || f < 0) ? '申购费不能是负数' : null;
        },
      ),
      SheetFormSingleLineTextItem(
        key: 'quantity',
        label: '多少份',
        hint: '账单上确认的份额，可以填小数',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String e = _positive(v, '多少份');
          return e.isEmpty ? null : e;
        },
      ),
    ],
    // ④ 代码：投资类同一代码只登记一次（数据查重）
    if (invest)
      SheetFormSingleLineTextItem(
        key: 'code',
        label: '代码',
        initialValue: base.code,
        hint: '可不填；填了不能重复',
        validator: (String v) {
          final String c = v.trim();
          if (c.isEmpty) return null;
          return usedCodes.contains(c) ? '这个代码已经登记过了' : null;
        },
      ),
    // ⑤ 日期：一个真日期
    SheetFormSingleLineTextItem(
      key: 'buy_date',
      label: dateLabel,
      initialValue: _ymd(base.createdAt),
      hint: '例如 2026-11-22',
      validator: (String v) =>
          _date(v) == null ? '填 2026-11-22 这种日期' : null,
    ),
    // ⑥ 金额：现在大概值多少（投资类由买卖记录给，不手填）
    if (hasLatestValue)
      SheetFormSingleLineTextItem(
        key: 'latest_value',
        label: '现在值',
        initialValue: base.latestValue?.toStringAsFixed(0) ?? '',
        hint: valueHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    // ⑦ 金额：租金（只有房产）
    if (hasMonthlyIn)
      SheetFormSingleLineTextItem(
        key: 'monthly_in',
        label: '月租',
        initialValue: base.monthlyIn.toStringAsFixed(0),
        hint: '每月到账；自住填 0',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    // ⑧ 金额：每月要花的钱（房产 / 车）
    if (hasMonthlyOut)
      SheetFormSingleLineTextItem(
        key: 'monthly_out',
        label: vehicle ? '月养' : '每月交',
        initialValue: base.monthlyOut.toStringAsFixed(0),
        hint: vehicle
            ? '保险、油电、保养、停车摊月'
            : '物业、供暖、保险、维修摊月；月供不填',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    // ⑨ 日期 / 备注：按类不同（哪天还 / 证照 / 手续 / 放在哪 / 占多少）
    if (noteLabel.isNotEmpty)
      SheetFormSingleLineTextItem(
        key: 'intention',
        label: noteLabel,
        hint: noteHint,
        initialValue: base.intention,
      ),
    // ⑩ 计息：只有借出款、别的投资有约定利息/票息
    if (hasInterest)
      SheetFormSingleLineTextItem(
        key: 'depreciation_note',
        label: interestLabel,
        hint: interestHint,
        initialValue: base.depreciationNote,
      ),
    // ⑪ 备注：车「一年掉」、贵重物「凭证」
    if (hasSecondNote)
      SheetFormSingleLineTextItem(
        key: 'second_note',
        label: secondNoteLabel,
        hint: secondNoteHint,
        initialValue: base.depreciationNote,
      ),
    // ⑫ 备注：随便写
    SheetFormMultiLineTextItem(
      key: 'note',
      label: '随便写',
      hint: remarkHint,
      initialValue: base.note,
      minLines: 2,
      maxLines: 3,
      showCounter: false,
    ),
    // 投资类金额是自动算出来的，给一句算式；其它类不再堆解释
    if (invest)
      SheetFormNoteItem(
        key: 'math_hint',
        text: mathHint,
        centered: true,
      ),
  ];
}

/// ② 新增 / 编辑一笔欠款（7.2 / 7.4 / 7.5）。
///
/// 与资产同一个「两步式」：新增先弹 [showAzLiabilityTypeSheet] 选一次类型，
/// 表单只显示这一类型用得上的字段。7.4 的「部分类型默认值」在这里落实：
///   · 信用卡 / 借的亲友钱 → 随借随还，不填每期还多少、期数、怎么还；
///   · 亲友钱默认不计息，额外给一个「要不要算利息」开关（7.2 T7）；
///   · 房贷 / 车贷 / 电商分期等 → 完整分期字段（月供、利息、费用、期数…）。
/// 类型与用途标签的默认值由 [_defaultPurpose] / base 构造期给出，用户可改。
/// 未显示的字段同样靠 `v.contains(key)` 保留原值，编辑不丢数据。
Future<void> showAzLiabilitySheet(
  BuildContext context, {
  LiabilityRecord? existing,
  LiabilityType? presetType,
}) async {
  final FormSheetController ctl = FormSheetController();
  final DateTime now = DateTime.now();
  final LiabilityType type =
      existing?.type ?? presetType ?? LiabilityType.other;
  final bool revolving =
      type == LiabilityType.creditCard || type == LiabilityType.personal;
  final LiabilityRecord base = existing ??
      LiabilityRecord(
        type: type,
        name: '',
        principal: 1,
        purpose: _defaultPurpose(type),
        interestOn: type != LiabilityType.personal,
        repayMethod: revolving
            ? RepayMethod.revolving
            : RepayMethod.equalPayment,
        createdAt: now,
        updatedAt: now,
      );
  await AppSheetShell.show<void>(
    context,
    header: _header(
      existing == null ? '新增欠款' : '编辑欠款',
      ctl,
      subtitle: type.label,
    ),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '保存',
      items: _liabilityItems(type, base),
      onSubmit: (SheetFormValues v) async {
        final Map<String, Object?> m = base.toMap()..['id'] = base.id;
        m['liability_type'] = type.dbValue;
        m['icon_key'] = type.iconKey;
        if (v.contains('name')) m['name'] = v.text('name').trim();
        if (v.contains('purpose')) {
          m['purpose'] = v.get<String>('purpose') ?? base.purpose.dbValue;
        }
        if (v.contains('principal')) {
          m['principal'] = _num(v, 'principal', base.principal);
          m['original_principal'] = base.originalPrincipal == 0
              ? m['principal']
              : base.originalPrincipal;
        }
        if (v.contains('interest_on')) {
          m['interest_on'] = v.flag('interest_on') ? 1 : 0;
        }
        if (v.contains('rate')) {
          m['rate'] = _num(v, 'rate', base.rate * 100) / 100;
        }
        if (v.contains('rate_type')) {
          m['rate_type'] = v.get<String>('rate_type') ?? base.rateType.dbValue;
        }
        if (v.contains('monthly_pay') &&
            v.contains('monthly_interest') &&
            v.contains('monthly_fee')) {
          final double pay = _num(v, 'monthly_pay');
          final double interest = _num(v, 'monthly_interest');
          final double fee = _num(v, 'monthly_fee');
          m['monthly_pay'] = pay;
          m['monthly_interest'] = interest;
          m['monthly_fee'] = fee;
          m['monthly_principal'] =
              (pay - interest - fee) > 0 ? pay - interest - fee : 0;
        }
        if (v.contains('repay_method')) {
          m['repay_method'] =
              v.get<String>('repay_method') ?? base.repayMethod.dbValue;
        }
        if (v.contains('pay_day')) {
          m['pay_day'] = int.tryParse(v.text('pay_day').trim());
        }
        if (v.contains('total_terms')) {
          m['total_terms'] = _count(v, 'total_terms');
        }
        if (v.contains('paid_terms')) {
          m['paid_terms'] = _count(v, 'paid_terms');
        }
        if (v.contains('end_date')) {
          m['end_date'] = _date(v.text('end_date'))?.millisecondsSinceEpoch;
        }
        if (v.contains('note')) m['note'] = v.text('note').trim();
        await context.read<AzWriteController>().saveLiability(
              LiabilityRecord.fromMap(m),
            );
      },
    ),
  );
}

/// 7.2：按类型带出用途标签默认值，用户仍可在表单里改。
DebtPurpose _defaultPurpose(LiabilityType t) => switch (t) {
      LiabilityType.mortgage => DebtPurpose.t1,
      LiabilityType.carLoan => DebtPurpose.t2,
      LiabilityType.personal => DebtPurpose.t7,
      _ => DebtPurpose.t4,
    };

/// 【欠款类型 → 表单项】7.4 的字段表按类型收窄：
///   · 公共：名字、用途、现在还欠多少、利率、利率会不会变、备注；
///   · 信用卡：7.7 规定「随借随还、账单日/还款日在信用卡账户里设」，
///     不显示每期还多少、期数、怎么还、到期日；
///   · 借的亲友钱：默认不计息，给「要不要算利息」开关，同样不显示分期字段；
///   · 其余 9 类（房贷 / 车贷 / 分期等）：完整分期字段。
/// 「实际一年要付多少」由 AzMath.realAnnualRate 从填的数算，用户不用懂年化。
List<SheetFormItem> _liabilityItems(LiabilityType t, LiabilityRecord base) {
  final bool revolving =
      t == LiabilityType.creditCard || t == LiabilityType.personal;
  return <SheetFormItem>[
    SheetFormSingleLineTextItem(
      key: 'name',
          label: '名称',
      initialValue: base.name,
          hint: '如：房贷',
          validator: (String v) => v.trim().isEmpty ? '请填名称' : null,
    ),
    SheetFormCustomItem(
      key: 'purpose',
          label: '用途',
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
          label: '欠款',
      initialValue: base.principal.toStringAsFixed(0),
      hint: _kAmountHint,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (String v) {
            final String e = _positive(v, '欠款');
        return e.isEmpty ? null : e;
      },
    ),
    if (t == LiabilityType.personal)
      SheetFormToggleItem(
        key: 'interest_on',
        label: '计息',
        initialValue: base.interestOn,
      ),
    SheetFormSingleLineTextItem(
      key: 'rate',
      label: t == LiabilityType.personal
          ? '年利率'
          : '利率',
      initialValue: (base.rate * 100).toStringAsFixed(2),
          hint: '如 3.10',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    ),
    SheetFormCustomItem(
      key: 'rate_type',
          label: '利率型',
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
    if (!revolving) ...<SheetFormItem>[
      SheetFormSingleLineTextItem(
        key: 'monthly_pay',
          label: '月供',
        initialValue: base.monthlyPay.toStringAsFixed(0),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      SheetFormSingleLineTextItem(
        key: 'monthly_interest',
          label: '利息',
        initialValue: base.monthlyInterest.toStringAsFixed(0),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      SheetFormSingleLineTextItem(
        key: 'monthly_fee',
          label: '手续费',
        initialValue: base.monthlyFee.toStringAsFixed(0),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      SheetFormCustomItem(
        key: 'repay_method',
          label: '方式',
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
          label: '还款日',
        initialValue: base.payDay?.toString() ?? '',
        keyboardType: TextInputType.number,
      ),
      SheetFormSingleLineTextItem(
        key: 'total_terms',
          label: '期数',
        initialValue: base.totalTerms.toString(),
        keyboardType: TextInputType.number,
      ),
      SheetFormSingleLineTextItem(
        key: 'paid_terms',
          label: '已还',
        initialValue: base.paidTerms.toString(),
        keyboardType: TextInputType.number,
      ),
      SheetFormSingleLineTextItem(
        key: 'end_date',
          label: '到期',
        initialValue: base.endDate == null
            ? ''
            : '${base.endDate!.year}-${base.endDate!.month.toString().padLeft(2, '0')}-${base.endDate!.day.toString().padLeft(2, '0')}',
        hint: _kDateHint,
      ),
    ],
    SheetFormMultiLineTextItem(
      key: 'note',
          label: '备注',
      initialValue: base.note,
      minLines: 2,
      maxLines: 3,
      showCounter: false,
    ),
    const SheetFormNoteItem(
      key: 'hint',
          text: '估算',
      centered: true,
    ),
  ];
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
      existing == null ? '记一笔' : '编辑',
      ctl,
    ),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '保存',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'title',
          label: kind == ContingentKind.contingent ? '事项' : '险种',
          initialValue: base.title,
          validator: (String v) => v.trim().isEmpty ? '请填名称' : null,
        ),
        SheetFormSingleLineTextItem(
          key: 'max_amount',
          label: '上限',
          initialValue: base.maxAmount.toStringAsFixed(0),
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'condition_text',
          label: kind == ContingentKind.contingent
              ? '触发条件'
              : '免责条件',
          initialValue: base.conditionText,
        ),
        SheetFormSingleLineTextItem(
          key: 'eta',
          label: '日期',
          initialValue: base.eta,
          hint: _kDateHint,
        ),
        SheetFormMultiLineTextItem(
          key: 'note',
          label: '备注',
          initialValue: base.note,
          minLines: 2,
          maxLines: 3,
          showCounter: false,
        ),
        if (existing != null && kind == ContingentKind.contingent)
          const SheetFormToggleItem(
            key: 'convert',
            label: '转欠款',
            initialValue: false,
          ),
        SheetFormNoteItem(
          key: 'hint',
          text: kind == ContingentKind.contingent
              ? '默认不计入'
              : '不抵扣欠款',
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
    header: _header('更新价格', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '存下',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'value',
          label: '现值',
          initialValue: asset.latestValue?.toStringAsFixed(0) ?? '',
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '现值');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormNoteItem(
          key: 'hint',
          text: '买入价 ${MoneyFormat.yuan0(asset.cost)}。',
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
    header: _header(buy ? '买入' : '卖出', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: buy ? '确认买入' : '确认卖出',
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'unit_price',
          label: '单价',
          hint: _kAmountHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '每个多少钱');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormSingleLineTextItem(
          key: 'quantity',
          label: buy ? '买入量' : '卖出量',
          hint: '数量',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, buy ? '买入量' : '卖出量');
            return e.isEmpty ? null : e;
          },
        ),
        SheetFormSingleLineTextItem(
          key: 'fee',
          label: buy ? '附加费' : '扣费',
          initialValue: '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SheetFormSingleLineTextItem(
          key: 'occurred_at',
          label: '日期',
          initialValue: _todayText(),
          hint: _kDateHint,
        ),
        const SheetFormNoteItem(
          key: 'hint',
          text: '买入不算支出，卖出不算收入。',
          centered: true,
        ),
        const SheetFormNoteItem(
          key: 'boundary',
          text: '暂不写流水。',
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
    header: _header('还款', ctl),
    child: FormSheetContent(
      controller: ctl,
      submit: true,
      submitLabel: '存下',
      items: <SheetFormItem>[
        if (plans.isNotEmpty)
          SheetFormCustomItem(
            key: 'plan_id',
            label: '期次',
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
          label: '金额',
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
          label: '备注',
          hint: '方式',
        ),
      ],
      onSubmit: (SheetFormValues v) async {
        if (plans.isEmpty) {
          throw ArgumentError('请先填期数');
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
/// 时会把值回传给 show 的返回值），再用 [OverviewSheetContent] 把已记录
/// 数据能算出的三件事摆出来。两步是**前后两个弹层**，不是弹窗套弹窗。
/// 「还完还能撑几个月」是情境设计（13.2）的推算，不在资债展示。
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
          label: '金额',
          hint: '还剩 ${MoneyFormat.yuan0(debt.principal)}',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final String e = _positive(v, '提前还额');
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
      title: '提前还',
      centered: true,
      leading: const SheetCancelAction(),
    ),
    child: Builder(
      builder: (BuildContext sheetContext) => OverviewSheetContent(
        metrics: <SheetMetric>[
          SheetMetric(label: '省利息', value: MoneyFormat.yuan0(p.saveInterest)),
          SheetMetric(label: '违约金', value: MoneyFormat.yuan0(p.penalty)),
          SheetMetric(label: '净省', value: MoneyFormat.yuan0(p.netSave)),
        ],
        changeLabel: '仅供参考',
        updatedAt:
            '还完手上还剩 ${MoneyFormat.yuan0(p.cashAfter)}。'
            '按实际一年 ${(p.realRate * 100).toStringAsFixed(1)}% 估算，以账单为准。',
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
      title: '计入总账',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: SelectSheetContent<String>(
      options: const <SheetOption<String>>[
        SheetOption<String>(value: 'yes', label: '计入', icon: AppIcons.check),
        SheetOption<String>(value: 'no', label: '不计入', icon: AppIcons.block),
      ],
      initialValue: asset.counted ? 'yes' : 'no',
      actionLabel: '确定',
      onApplyAsync: (String value) async {
        final Map<String, Object?> m = asset.toMap()..['id'] = asset.id;
        m['counted'] = value == 'yes' ? 1 : 0;
        m['counted_reason'] = value == 'yes' ? '' : '手动关闭';
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
      title: '回收站',
      centered: true,
      leading: SheetCancelAction(),
    ),
    child: ConfirmSheetContent(
      title: title,
      description: description,
      secondaryLabel: '再想想',
      primaryLabel: '确认删除',
      intent: SheetIntent.danger,
      footnote: '可恢复',
      onPrimaryAsync: onConfirm,
    ),
  );
}

/// ⑩ 选资产大类（6.1 一排图标、只选一次、不进二级菜单）。
/// 复用公共 [CategorySheetContent]（契约第 5 条），点一格立即回传并关弹层；
/// 调用方拿到大类后再打开只有这一类字段的表单，不套第二层菜单。
Future<AssetClass?> showAzAssetClassSheet(BuildContext context) =>
    AppSheetShell.show<AssetClass>(
      context,
      // 只有右侧关闭按钮、没有左侧取消，居中会把标题推偏；与主题选择
      // 弹层一致用左对齐（centered 默认 false）。
      header: const SheetHeader(
        title: '选类型',
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
      ),
    );

/// ⑩-2 选欠款类型（7.2 一排图标、只选一次）。与资产大类同一个公共组件，
/// 只换数据与标题；选中后由调用方打开该类型专属字段的表单。
Future<LiabilityType?> showAzLiabilityTypeSheet(BuildContext context) =>
    AppSheetShell.show<LiabilityType>(
      context,
      header: const SheetHeader(
        title: '选类型',
        trailing: SheetCloseButton(),
      ),
      child: CategorySheetContent<LiabilityType>(
        categories: <SheetCategory<LiabilityType>>[
          for (final LiabilityType t in LiabilityType.values)
            SheetCategory<LiabilityType>(
              value: t,
              label: t.label,
              icon: _classIcon(t.iconKey),
            )
        ],
      ),
    );

/// 语义 key → 图标。资产大类与欠款类型共用这一张表（与 azIcon 同一取舍），
/// 数据库只存 key；新增类型时在这里加一行即可，不用迁移数据。
IconData _classIcon(String key) => switch (key) {
      'finance' => AppIcons.finance,
      'investment' => AppIcons.investment,
      'housing' => AppIcons.housing,
      'rent' => AppIcons.rent,
      'car' => AppIcons.car,
      'gift' => AppIcons.gift,
      'basket' => AppIcons.basket,
      'study' => AppIcons.study,
      'homeImprovement' => AppIcons.homeImprovement,
      'accountCreditCard' => AppIcons.accountCreditCard,
      'insurance' => AppIcons.insurance,
      _ => AppIcons.other,
    };

/// 日期统一写成 yyyy-mm-dd：买入日 / 上牌日 / 哪天借的都用它回显。
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _todayText() => _ymd(DateTime.now());
