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
  // 只算未软删的行（回收站里的可以重新登记），编辑时排除自己这一条；
  // 空代码不参与 —— 表单允许「可不填」，不填就不该互相撞车。
  final Set<String> usedCodes = <String>{
    for (final AssetRecord a in context.read<AzController>().data.assets)
      if (!a.isDeleted && a.id != existing?.id && a.code.trim().isNotEmpty)
        a.code.trim(),
  };
  final AssetRecord base = existing ??
      AssetRecord(
        assetClass: cls,
        name: '',
        cost: 1,
        // 6.7：贵重物件默认不算进总账，车与其它类默认算。
        counted: cls != AssetClass.valuable,
        // 按大类给一个合理的「多久能变成现金」默认值：房产几个月、
        // 生意很难，其余默认几天；用户仍可在表单里改（需求 2.1 / 5.1）。
        liquidity: _defaultLiquidity(cls),
        createdAt: now,
        updatedAt: now,
      );

  // 【6.3 通用字段 · 构造期】「用哪张卡买的」「这笔钱是借来买的吗」
  // 两个下拉的可选项。只列未删除的；已关联但后来被删的记录补一个占位，
  // 保证编辑时能回显旧值，不被下拉悄悄改成第一项（6.9 不静默改数）。
  final int? linkedAccount = base.linkAccountId;
  final int? linkedDebt = base.linkDebtId;
  final List<_SelectOption> accountOptions = <_SelectOption>[
    const _SelectOption('', '没记'),
  ];
  bool accountFound = linkedAccount == null;
  for (final a in context.read<AccountController>().all) {
    if (a.isDeleted || a.id == null) continue;
    accountOptions.add(_SelectOption(a.id!.toString(), a.name));
    if (a.id == linkedAccount) accountFound = true;
  }
  if (!accountFound && linkedAccount != null) {
    accountOptions.add(
      _SelectOption(linkedAccount.toString(), '原来那张卡已删除'),
    );
  }
  final List<_SelectOption> debtOptions = <_SelectOption>[
    const _SelectOption('', '没借'),
  ];
  bool debtFound = linkedDebt == null;
  LiabilityRecord? linkedDebtRow;
  for (final d in context.read<AzController>().data.activeLiabilities) {
    if (d.isDeleted || d.id == null) continue;
    debtOptions.add(_SelectOption(d.id!.toString(), d.name));
    if (d.id == linkedDebt) {
      debtFound = true;
      linkedDebtRow = d;
    }
  }
  if (!debtFound && linkedDebt != null) {
    debtOptions.add(
      _SelectOption(linkedDebt.toString(), '原来那笔债已删除'),
    );
  }
  // 6.6「现在还欠多少」只读：表单是构造期静态，这里显示已关联负债的
  // 当前剩余本金；实时值仍在详情页看，不在表单里做动态刷新。
  final String? debtBalanceNote = linkedDebtRow == null
      ? null
      : '现在还欠 ${MoneyFormat.yuan0(linkedDebtRow!.principal)}，只读';

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
      items: _assetItems(
        cls,
        base,
        usedCodes,
        existing == null,
        accountOptions,
        debtOptions,
        debtBalanceNote,
      ),
      onSubmit: (SheetFormValues v) async {
        final Map<String, Object?> m = base.toMap()..['id'] = base.id;
        m['asset_class'] = cls.code;
        m['icon_key'] = cls.iconKey;
        if (v.contains('name')) m['name'] = v.text('name').trim();
        if (v.contains('cost')) m['cost'] = _num(v, 'cost', base.cost);
        // 6.5.1：投资「新增」由首笔买入算出一共花了多少（含费用），
        // 写进已有的 cost / unit_price / quantity 列，并生成首笔批次。
        // 编辑档案时这三项不显示，v.contains 为 false，原值原样保留，
        // 不会去改已经存在的买卖记录。
        final bool firstBuy = cls.isInvestment &&
            existing == null &&
            v.contains('unit_price') &&
            v.contains('quantity');
        double firstPrice = 0;
        double firstQty = 0;
        double firstFee = 0;
        if (firstBuy) {
          firstPrice = _num(v, 'unit_price');
          firstQty = _num(v, 'quantity');
          firstFee = _num(v, 'trade_fee');
          m['cost'] = firstPrice * firstQty + firstFee;
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
        if (v.contains('exit_cost')) {
          m['exit_cost'] = _num(v, 'exit_cost');
        }
        if (v.contains('liquidity')) {
          m['liquidity'] = int.tryParse(
                v.get<String>('liquidity') ?? '${base.liquidity.dbValue}',
              ) ??
              base.liquidity.dbValue;
        }
        if (v.contains('stability')) {
          m['stability'] = v.get<String>('stability') ?? base.stability.dbValue;
        }
        if (v.contains('use_mode')) {
          m['use_mode'] = v.get<String>('use_mode') ?? base.useMode;
        }
        if (v.contains('depreciation_note')) {
          m['depreciation_note'] = v.text('depreciation_note').trim();
        }
        if (v.contains('counted')) m['counted'] = v.flag('counted') ? 1 : 0;
        if (v.contains('intention')) {
          m['intention'] = v.text('intention').trim();
        }
        if (v.contains('note')) m['note'] = v.text('note').trim();
        // 6.3 通用字段：什么时候买的 / 用哪张卡买的 / 这笔钱是借来买的吗。
        // 下拉用户没点时 get<String> 为 null，回退到原值，不静默清空（6.9）。
        if (v.contains('buy_date')) {
          final DateTime? d = _date(v.text('buy_date'));
          m['created_at'] = (d ?? base.createdAt).millisecondsSinceEpoch;
        }
        if (v.contains('link_account_id')) {
          final String? raw = v.get<String>('link_account_id');
          if (raw == null) {
            m['link_account_id'] = base.linkAccountId;
          } else if (raw.isEmpty) {
            m['link_account_id'] = null;
          } else {
            m['link_account_id'] = int.tryParse(raw) ?? base.linkAccountId;
          }
        }
        if (v.contains('link_debt_id')) {
          final String? raw = v.get<String>('link_debt_id');
          if (raw == null) {
            m['link_debt_id'] = base.linkDebtId;
          } else if (raw.isEmpty) {
            m['link_debt_id'] = null;
          } else {
            m['link_debt_id'] = int.tryParse(raw) ?? base.linkDebtId;
          }
        }
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

/// 按大类给「多久能变成现金」的默认值（只在新增时用，编辑保留原值）。
/// 房产几个月、生意很难，其余默认几天；都可以在表单里再改。
Liquidity _defaultLiquidity(AssetClass cls) => switch (cls) {
      AssetClass.property => Liquidity.months,
      AssetClass.business => Liquidity.hard,
      AssetClass.loan => Liquidity.months,
      AssetClass.misc => Liquidity.months,
      _ => Liquidity.days,
    };

/// 【资产大类 → 表单项】6.1「选完某一类，只展开这一类专属的几项」的落地表。
///
/// 【先定规格再落地】九类逐项的「现实 → 设计原文 → 字段 → 落库列」见
/// 《资产新增_全类型规格核对表.md》。本函数按那张表一次性实现，不再按
/// 被点名的类型打补丁。依据：
///   · 6.3 所有资产共用字段（含「什么时候买的 / 用哪张卡买的 / 这笔钱是
///     借来买的吗 / 要不要算进总账」）—— 九类都要有，不是某几类专属；
///   · 6.5.1 投资买入：名字+代码、哪天买的、单价/净值、股数/份数、
///     另外交了多少钱、钱从哪张卡出、备注，一共花 = 单价×数量+费用；
///   · 6.6 房产十字段（含关联房贷、现在还欠多少只读、证照、卖要扣）；
///   · 6.7 车 / 贵重物 / 生意 / 借出款各自的专属字段（上牌年月、有没有
///     凭证、去年分了多少、收回来多少、可能收不回）；
///   · 6.2 大类构成决定子形态（A3 含应收退款/押金/待报销，A8 含电动车，
///     A9 含数码设备，A6 含年金）；
///   · 附二白话对照表、6.9 防错、10.9 准确性铁律。
///
/// 【界面短名按现实语义】现实里没有「成本 / 现值 / 月入」这种账本词：
/// 借出款说「借了多少 / 还剩多少 / 每月收」，房子说「一共花 / 月租 /
/// 每月交」，车说「落地价 / 月养 / 一年掉」。每个 label 都按类给白话短名，
/// 一律 ≤ 4 字；细节进 hint 与静态小字。
///
/// 【全部沿用已有列】created_at / link_account_id / link_debt_id /
/// use_mode / depreciation_note / intention / counted 都是 az_assets 原本
/// 就有的列，不升 DB 版本、不改 DDL。use_mode 与 depreciation_note 跨类
/// 复用，因此详情页展示 label 同步按类改（见 asset_detail_screen.dart）。
///
/// 【追加购买，本轮不做】首次买入在新增里一次录完；后续追加才放详情页。
/// 详情页的按钮一行未碰，等账户单写点联动时再收敛成投资专属入口。
List<SheetFormItem> _assetItems(
  AssetClass cls,
  AssetRecord base,
  Set<String> usedCodes,
  bool isNew,
  List<_SelectOption> accountOptions,
  List<_SelectOption> debtOptions,
  String? debtBalanceNote,
) {
  final bool invest = cls.isInvestment;
  final bool property = cls == AssetClass.property;
  final bool vehicle = cls == AssetClass.vehicle;
  final bool valuable = cls == AssetClass.valuable;
  final bool loan = cls == AssetClass.loan;
  final bool business = cls == AssetClass.business;

  // ── 逐类字段开关（对应规格核对表第 3 节矩阵，不再只照顾被点名的类）──
  final bool hasIncome = loan || property || business;
  final bool hasHoldCost = property || vehicle;
  final bool hasExitCost =
      invest || property || vehicle || valuable || business;
  final bool hasUseMode = loan || property;
  final bool hasDepreciation = vehicle || valuable;
  final bool hasDebtLink = property || vehicle;
  // 6.3「所有资产共用的字段」：日期、付款卡、算不算、备注，九类全给；
  // 投资类不手填 cost / latest_value / monthly_*，由买卖批次提供金额。
  const bool hasDate = true;
  const bool hasAccount = true;
  const bool hasCounted = true;
  final bool hasValue = !invest;
  final bool hasIntention = !invest;

  // ── 界面短名：按这一类在现实里怎么叫，不沿用通用账本词 ──────────
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
  // 6.3「什么时候买的」按现实叫法：借出款是借出去那天，车是上牌日。
  final String dateLabel = switch (cls) {
    AssetClass.loan => '哪天借',
    AssetClass.business => '哪天投',
    AssetClass.vehicle => '上牌日',
    AssetClass.property => '哪天买',
    _ => '买入日',
  };
  final String valueLabel = loan ? '还剩多少' : '现在值';
  final String incomeLabel = switch (cls) {
    AssetClass.property => '月租',
    AssetClass.business => '分红',
    _ => '每月收',
  };
  final String outLabel = vehicle ? '月养' : '每月交';
  final String exitLabel = switch (cls) {
    AssetClass.stock => '赎回费',
    AssetClass.fund => '赎回费',
    AssetClass.otherInvest => '赎回费',
    AssetClass.property => '卖要扣',
    AssetClass.valuable => '卖要扣',
    AssetClass.vehicle => '过户费',
    AssetClass.business => '退股扣',
    _ => '卖要扣',
  };
  final String liquidityLabel = switch (cls) {
    AssetClass.loan => '多久还',
    AssetClass.property => '多久卖',
    AssetClass.vehicle => '多久卖',
    AssetClass.valuable => '多久卖',
    _ => '变现',
  };
  final String depreciationLabel =
      valuable ? '凭证' : '一年掉';
  final String debtLabel = property ? '房贷' : '车贷';
  // 6.5.1：A4 单价/股数，A5 净值/份数，A6 按份额记。
  final String priceLabel = cls == AssetClass.fund ? '净值' : '单价';
  final String quantityLabel =
      cls == AssetClass.stock ? '股数' : '份数';

  // 按大类给的白话提示：细节只进 hint / 静态小字，不撑长 label。
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
    AssetClass.loan => '实际给出去的钱，不是借条面额',
    AssetClass.property => '含首付、契税、中介、装修',
    AssetClass.vehicle => '不是裸车价，是落地一共花的',
    AssetClass.valuable => '当时买花的钱',
    AssetClass.business => '投进去多少',
    _ => _kAmountHint,
  };
  final String? valueHint = switch (cls) {
    AssetClass.loan => '收回一部分就改这个数',
    AssetClass.property => '一年改一次就行',
    AssetClass.vehicle => '卖二手车大概能拿多少',
    AssetClass.business => '自己填的，不是查来的',
    AssetClass.valuable => '自己填的，不是查来的',
    _ => null,
  };
  final String? noteHint = switch (cls) {
    AssetClass.loan => '借条、转账、利息约定写这儿',
    AssetClass.property => '产权、合同、交割写这儿',
    AssetClass.vehicle => '发票、改装、事故、违章写这儿',
    AssetClass.valuable => '发票、证书、克重、配件写这儿',
    AssetClass.business => '协议、分红、账目、聊天记录写这儿',
    _ => null,
  };
  final String intentionLabel = switch (cls) {
    AssetClass.loan => '约定还日',
    AssetClass.property => '证照',
    AssetClass.vehicle => '手续',
    AssetClass.valuable => '放在哪',
    AssetClass.business => '占多少',
    _ => '用途',
  };
  final String? intentionHint = switch (cls) {
    AssetClass.loan => '说好什么时候还，可空',
    AssetClass.property => '产权、共有、押证写一句',
    AssetClass.vehicle => '上牌、绿本、保单',
    AssetClass.valuable => '家里、保险箱',
    AssetClass.business => '写个大概就行，不做股权登记',
    _ => null,
  };
  final String monthlyInHint = switch (cls) {
    AssetClass.property => '每月到账；自住填 0',
    AssetClass.business => '最近一次分红折成每月，不保证有',
    _ => '每月收多少；没约定利息就填 0',
  };
  final String exitHint = switch (cls) {
    AssetClass.stock => '卖出大概扣多少',
    AssetClass.fund => '卖出大概扣多少',
    AssetClass.otherInvest => '卖出大概扣多少',
    AssetClass.property => '中介费、税费估算',
    AssetClass.vehicle => '过户、违章处理',
    AssetClass.valuable => '回收扣的手续费',
    AssetClass.business => '退伙、转让的摩擦',
    _ => '手续费',
  };
  final String depreciationHint = valuable
      ? '发票、证书、原包装写一句'
      : '例如 12%，只是备注，不参与计算';
  final String? depreciationInitial =
      hasDepreciation ? base.depreciationNote : null;

  // A3 借出情形（6.2 的四类构成）；值直接存中文，详情页能白话回显。
  // A7 沿用房贷原型里的 self/rent/empty/business 四档。
  final String useModeLabel = loan ? '借出情形' : '用途';
  final List<_SelectOption> useModeOptions = loan
      ? const <_SelectOption>[
          _SelectOption('', '熟人临时周转'),
          _SelectOption('借条借款', '借条借款'),
          _SelectOption('押金保证金', '押金保证金'),
          _SelectOption('垫付待报销', '垫付待报销'),
        ]
      : const <_SelectOption>[
          _SelectOption('', '自己住'),
          _SelectOption('rent', '租给别人'),
          _SelectOption('empty', '空着'),
          _SelectOption('business', '做生意用'),
        ];

  // 每类 2~3 句白话：把这一类现实里最容易填错的地方讲清，静态小字。
  // 不是「统一模板套一句」，内容按 6.2 / 6.5 / 6.6 / 6.7 逐类写。
  final List<String> typeNotes = switch (cls) {
    AssetClass.loan => <String>[
        '没写利息，就先按没利息记',
        '借出 − 还剩 = 已经收回来的',
        '可能收不回，就把「算不算」关掉',
      ],
    AssetClass.stock => <String>[
        '一共花 = 单价 × 股数 + 费用',
        '按买入价；平时不算涨跌',
        '买卖不写流水，暂不扣卡里的钱',
      ],
    AssetClass.fund => <String>[
        '一共花 = 净值 × 份数 + 费用',
        '份额可以填小数；确认净值以账单为准',
        '按买入价；平时不算涨跌',
      ],
    AssetClass.otherInvest => <String>[
        '一共花 = 单价 × 份数 + 费用',
        '国债、年金有约定票息，暂不按月进账算',
        '按买入价；平时不算涨跌',
      ],
    AssetClass.property => <String>[
        '月供不用填在这儿，那笔在欠款里算过了',
        '现在值一年改一次就行',
        '真要卖，还要扣中介费和税费',
      ],
    AssetClass.vehicle => <String>[
        '车一年比一年不值钱；软件不会自动改这里的数',
        '落地价含购置税、保险、上牌',
        '卖之前要过户、清违章',
      ],
    AssetClass.valuable => <String>[
        '金饰的工费和牌子，卖的时候不算钱',
        '默认不算进总账，你自己打开',
      ],
    AssetClass.business => <String>[
        '投了多少是事实，现在值多少是自己填的',
        '分红不保证有，先按「说不准」',
      ],
    _ => <String>['说不清的放这儿，不参与每月进出'],
  };

  return <SheetFormItem>[
    // ① 名字（6.2 / 6.3 / 6.7；按类叫「借给谁 / 哪套房 / 哪辆车」）
    SheetFormSingleLineTextItem(
      key: 'name',
      label: nameLabel,
      initialValue: base.name,
      hint: nameHint,
      validator: (String v) => v.trim().isEmpty ? '请填$nameLabel' : null,
    ),
    // ② 借出情形 / 用途（A3 按 6.2 的四类构成，A7 按 6.6 四档）
    if (hasUseMode)
      SheetFormCustomItem(
        key: 'use_mode',
        label: useModeLabel,
        builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
            _InlineSelect(
          options: useModeOptions,
          initial: base.useMode,
          onChanged: onChanged,
        ),
      ),
    // ③ 一共花了多少（6.3；非投资手填，投资由首笔买入自动算）
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
    // ④ 6.5.1 首次买入：每个多少钱 / 买了多少 / 另外交了多少钱。
    // 只在「新增」露出；编辑档案不重放首笔批次，避免改已有买卖记录。
    if (invest && isNew) ...<SheetFormItem>[
      SheetFormSingleLineTextItem(
        key: 'unit_price',
        label: priceLabel,
        hint: cls == AssetClass.fund ? '每份多少钱' : '每个多少钱',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String e = _positive(v, priceLabel);
          return e.isEmpty ? null : e;
        },
      ),
      SheetFormSingleLineTextItem(
        key: 'quantity',
        label: quantityLabel,
        hint: cls == AssetClass.fund
            ? '份额，可以填小数'
            : (cls == AssetClass.stock ? '股数' : '份数'),
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
        hint: cls == AssetClass.fund
            ? '申购费等，不填按 0'
            : '佣金、过户费等，不填按 0',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (String v) {
          final String t = v.trim();
          if (t.isEmpty) return null;
          final double? f = double.tryParse(t);
          return (f == null || f < 0) ? '费用不能是负数' : null;
        },
      ),
    ],
    // ⑤ 代码（用户硬需求：A4/A5/A6 同码禁止二次新增）
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
    // ⑥ 什么时候买的（6.3 全类必填；A8 是上牌日、A3 是哪天借）
    if (hasDate)
      SheetFormSingleLineTextItem(
        key: 'buy_date',
        label: dateLabel,
        initialValue: _ymd(base.createdAt),
        hint: '例如 2026-11-22',
        validator: (String v) =>
            _date(v) == null ? '填 2026-11-22 这种日期' : null,
      ),
    // ⑦ 现在大概值多少（6.4 默认不填；A3 是「还剩多少」）
    if (hasValue)
      SheetFormSingleLineTextItem(
        key: 'latest_value',
        label: valueLabel,
        initialValue: base.latestValue?.toStringAsFixed(0) ?? '',
        hint: valueHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    // ⑧ 每月进 / 稳不稳（6.3；只有 A3/A7/A10 现实里有进账）
    if (hasIncome)
      SheetFormSingleLineTextItem(
        key: 'monthly_in',
        label: incomeLabel,
        initialValue: base.monthlyIn.toStringAsFixed(0),
        hint: monthlyInHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    if (hasIncome)
      SheetFormCustomItem(
        key: 'stability',
        label: '稳不稳',
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
    // ⑨ 每月出（6.3 / 6.6 / 6.7；房产不含月供，车是月养）
    if (hasHoldCost)
      SheetFormSingleLineTextItem(
        key: 'monthly_out',
        label: outLabel,
        initialValue: base.monthlyOut.toStringAsFixed(0),
        hint: vehicle
            ? '保险、油电、保养、停车摊月'
            : '物业、供暖、保险、维修摊月；月供不填',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    // ⑩ 提前取要扣多少（6.3 / 6.6 / 6.7，按类叫卖要扣 / 过户费 / 赎回费）
    if (hasExitCost)
      SheetFormSingleLineTextItem(
        key: 'exit_cost',
        label: exitLabel,
        initialValue: base.exitCost.toStringAsFixed(0),
        hint: exitHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    // ⑪ 多久能变成现金（6.3 全类必填）
    SheetFormCustomItem(
      key: 'liquidity',
      label: liquidityLabel,
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
    // ⑫ 这笔钱是借来买的吗（6.3 / 6.6 / 原型 linkDebt）+ 现在还欠多少只读
    if (hasDebtLink)
      SheetFormCustomItem(
        key: 'link_debt_id',
        label: debtLabel,
        builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
            _InlineSelect(
          options: debtOptions,
          initial: base.linkDebtId?.toString() ?? '',
          onChanged: onChanged,
        ),
      ),
    if (hasDebtLink && debtBalanceNote != null)
      SheetFormNoteItem(
        key: 'debt_balance',
        text: debtBalanceNote!,
        centered: true,
      ),
    // ⑬ 一年掉多少 / 有没有凭证（6.7；同一 TEXT 列按类复用）
    if (hasDepreciation)
      SheetFormSingleLineTextItem(
        key: 'depreciation_note',
        label: depreciationLabel,
        initialValue: depreciationInitial ?? '',
        hint: depreciationHint,
      ),
    // ⑭ 按类的一句话：约定还日 / 证照 / 手续 / 放在哪 / 占多少 / 用途
    if (hasIntention)
      SheetFormSingleLineTextItem(
        key: 'intention',
        label: intentionLabel,
        hint: intentionHint,
        initialValue: base.intention,
      ),
    // ⑮ 用哪张卡买的（6.3 全类；只记录，不改余额，见下方静态句）
    if (hasAccount)
      SheetFormCustomItem(
        key: 'link_account_id',
        label: '付款卡',
        builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
            _InlineSelect(
          options: accountOptions,
          initial: base.linkAccountId?.toString() ?? '',
          onChanged: onChanged,
        ),
      ),
    // ⑯ 要不要算进总账（6.3 全类必填；6.7「可能收不回」由用户决定）
    if (hasCounted)
      SheetFormToggleItem(
        key: 'counted',
        label: '算不算',
        initialValue: base.counted,
      ),
    // ⑰ 随便写（6.3 备注；照片/凭证无列，见说明里的待拍板项）
    SheetFormMultiLineTextItem(
      key: 'note',
      label: '随便写',
      hint: noteHint,
      initialValue: base.note,
      minLines: 2,
      maxLines: 3,
      showCounter: false,
    ),
    const SheetFormNoteItem(
      key: 'account_hint',
      text: '选哪张卡只是记下来，暂不改卡里的钱',
      centered: true,
    ),
    // ⑱ 每类 2~3 句现实白话（按 6.2 / 6.5 / 6.6 / 6.7 逐类写，不是模板）
    for (int i = 0; i < typeNotes.length; i++)
      SheetFormNoteItem(
        key: 'type_note_$i',
        text: typeNotes[i],
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
