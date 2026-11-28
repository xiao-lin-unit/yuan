import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../database/ledger/az_record.dart';
import '../../database/ledger/az_schema.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../screens/commons/sheet/app_sheet_shell.dart';
import '../../screens/commons/sheet/contents/category_sheet_content.dart';
import '../../screens/commons/sheet/contents/confirm_sheet_content.dart';
import '../../screens/commons/sheet/contents/form_sheet_content.dart';
import '../../screens/commons/sheet/parts/sheet_primitives.dart';
import '../../screens/commons/sheet/sheet_form_items.dart';
import '../../screens/commons/sheet/sheet_models.dart';
import '../../service/account_controller.dart';
import 'widgets/az_cards.dart';

// ── 页面私有文案（样式一律走全局层）─────────────────────────────
const String _kTypeHint = '按类型组排列，选一次类型后只填这一类专属字段。';
const String _kFormNote = '金额按元填写，可带两位小数；日期填 YYYY-MM-DD；不填的金额按 0 记。';
const String _kDeleteDesc = '删除后进入回收站，主表与次表记录都会保留，只是不再显示。';

/// 一次新增 / 编辑提交上来的字段值。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】承载动态表单填出的主表字段与次表字段，交给 AzWriteController 写库。
/// 【使用限制】不可变；键必须来自 AzSchema.editableColumns；金额一律 String；日期列已转成毫秒整数。
/// 【入参与结果】构造收 mainValues / subValues；消费方只读字段。
/// 【异常与调用方处理】不抛异常；空 Map 表示没有可编辑字段，调用方按「只建主表」处理。
class AzEntryDraft {
  const AzEntryDraft({required this.mainValues, required this.subValues});

  final Map<String, Object?> mainValues;
  final Map<String, Object?> subValues;
}

/// 一次还款动作的用户输入（只装动作，金额拆分与罚费由软件算）。
/// 【所属模块】screens/ledger · 还款弹层
/// 【实现功能】承载实还金额与「是否提前还款 / 是否还本期 / 是否有违约金 / 结清规则」等动作开关。
/// 【使用限制】不可变；金额单位元；settleRule 用草案的英文 code；软件不判断用户是否一次性还清。
/// 【入参与结果】构造收各动作字段；消费方只读字段并交给 AzRepaymentService。
/// 【异常与调用方处理】不抛异常；非法组合由负债服务在事务内校验并上抛。
class AzRepaySheetResult {
  const AzRepaySheetResult({
    required this.amount,
    required this.prepay,
    required this.payCurrentTerm,
    required this.hasPenalty,
    required this.settleAll,
    required this.partialMode,
    required this.repayAccountId,
    this.settleRule,
    this.ruleRatio,
    this.serviceFee,
  });

  final double amount;
  /// 付款账户 id；由弹层下拉给出，交给 AzRepaymentService 写账户出账。
  final int? repayAccountId;
  final bool prepay;
  final bool payCurrentTerm;
  final bool hasPenalty;
  final bool settleAll;
  final String partialMode;
  final String? settleRule;
  final double? ruleRatio;
  final double? serviceFee;
}

/// 枚举列的默认值（与 az_controller 的写入兜底一致）。
const Map<String, String> _kEnumDefault = <String, String>{
  'status': 'normal',
  'state': 'pending',
  'record_source': 'user',
  'repay_method': 'equal_principal',
  'term_unit': 'month',
  'direction': 'out',
};

/// 枚举值 → 中文显示（存库仍用英文 code，业务层按 code 校验）。
const Map<String, String> _kEnumLabels = <String, String>{
  'equal_principal': '等额本金',
  'equal_installment': '等额本息',
  'interest_first': '先息后本',
  'lump_sum': '到期一次性还本付息',
  'revolving': '随借随还',
  'month': '按月',
  'quarter': '按季',
  'year': '按年',
  'day': '按天',
  'week': '按周（每周六）',
  'normal': '正常',
  'overdue': '逾期',
  'settled': '已结清',
  'waive_unbilled': '免收未出账手续费',
  'charge_all_remaining': '收齐剩余各期手续费',
  'charge_one_more': '只加收一期手续费',
  'ratio_of_remaining': '按剩余本金比例收',
  'extra_service_fee': '另收一笔服务费',
};

/// 日期列：界面按 YYYY-MM-DD 录入，写库转毫秒整数（DDL 是 INTEGER）。
const Set<String> _kDateCols = <String>{
  'start_date',
  'end_date',
  'due_at',
  'repaid_at',
  'drawn_at',
};

/// 分期提前结清规则（与 AzSchema.tableColumns 的 options 完全一致）。
const List<String> _kSettleRules = <String>[
  'waive_unbilled',
  'charge_all_remaining',
  'charge_one_more',
  'ratio_of_remaining',
  'extra_service_fee',
];

/// ⑤ 新增第一步：按类型组选类型。与账户页 `showAccountKindPicker` 同构。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】弹出按 AzSchema.groups 顺序排好的类型选择表，取消返回 null，选中返回 AzTypeSpec。
/// 【使用限制】side 只能是 'asset' / 'liability'；页面拿到 null 时不得继续新增流程。
/// 【入参与结果】收 context 与 side；返回 Future<AzTypeSpec?>，调用方必须 await 并判 mounted。
/// 【异常与调用方处理】不抛异常；弹层被系统关闭返回 null；调用方需自行判空、判 mounted。
Future<AzTypeSpec?> showAzTypeSheet(BuildContext context, {required String side}) {
  final List<SheetCategory<AzTypeSpec>> categories = <SheetCategory<AzTypeSpec>>[];
  for (final AzTypeGroup g in AzSchema.groups) {
    if (g.side != side) continue;
    for (final AzTypeSpec t in AzSchema.typesOfGroup(g.key)) {
      categories.add(SheetCategory<AzTypeSpec>(
        value: t,
        label: '${g.label} · ${t.label}',
        icon: azTypeIcon(t),
      ));
    }
  }
  return AppSheetShell.show<AzTypeSpec>(
    context,
    header: SheetHeader(
      title: side == 'asset' ? '新增资产' : '新增负债',
      subtitle: '请选择类型',
      centered: true,
      leading: const SheetCloseButton(),
    ),
    child: CategorySheetContent<AzTypeSpec>(
      categories: categories,
      allLabel: '全部类型',
      hint: _kTypeHint,
    ),
  );
}

/// ① 新增 / 编辑：声明式动态表单，主表 + 对应次表一次填完。
/// 表单项由 AzSchema.editableColumns 生成，样式全部交给 FormSheetContent 与全局令牌。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】为选中类型渲染主表与次表的全部可录入列，提交后把 SheetFormValues 转成 AzEntryDraft；编辑时带出已有值。
/// 【使用限制】判别列、系统列、软件计算列不出现；金额按 String 提交、空金额写 '0'；日期按 YYYY-MM-DD 录入、写库转毫秒；表单不写库。
/// 【入参与结果】收 context / spec / 可选 initialData 与 editId；返回 Future<AzEntryDraft?>，取消返回 null。
/// 【异常与调用方处理】不抛异常；写库异常由 AzWriteController 上抛，表单不吞；调用方必须判 null 与 mounted。
Future<AzEntryDraft?> showAzEntrySheet(
  BuildContext context,
  AzTypeSpec spec, {
  AzData? initialData,
  int? editId,
}) async {
  final AzRecord? main = (initialData == null || editId == null)
      ? null
      : _findMain(initialData, spec.side, editId);
  final AzRecord? sub = (initialData == null || editId == null)
      ? null
      : initialData.subFor(editId, spec.subTable);

  final List<AzColumn> mainCols = AzSchema.editableColumns(spec.mainTable);
  final List<AzColumn> subCols = AzSchema.editableColumns(spec.subTable);
  final FormSheetController controller = FormSheetController();

  final SheetFormValues? values = await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: editId == null ? '新增${spec.label}' : '编辑${spec.label}',
      subtitle: '${spec.label} · 请填写下面的信息',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: controller.submit,
      ),
    ),
    child: FormSheetContent(
      controller: controller,
      items: <SheetFormItem>[
        ..._itemsFor(mainCols, main),
        if (subCols.isNotEmpty)
          const SheetFormNoteItem(
            key: '_sub_divider',
            text: '以下为该类型专属信息。',
            centered: false,
          ),
        ..._itemsFor(subCols, sub),
        const SheetFormNoteItem(key: '_note', text: _kFormNote),
      ],
    ),
  );
  if (values == null) return null;
  return AzEntryDraft(
    mainValues: _collect(mainCols, values),
    subValues: _collect(subCols, values),
  );
}

/// 还款动作弹层：常规还本期 / 主动提前还款 / 分期提前结清共用一张表。
/// 【所属模块】screens/ledger · 还款弹层
/// 【实现功能】带出当期应还额作默认金额，收集实还金额与全部动作开关，取消返回 null。
/// 【使用限制】只收集动作输入，不做金额拆分、不判断该不该收违约金；结清规则五值由业务层校验。
/// 【入参与结果】收 context / 名称 / 是否分期 / 建议金额 / 主表已绑定账户 id；返回 Future<AzRepaySheetResult?>，调用方必须判 null 与 mounted。
/// 【异常与调用方处理】不抛异常；无可用账户时 repayAccountId 为 null，调用方须提示先建账户；写库异常由 AzRepaymentService 上抛。
Future<AzRepaySheetResult?> showAzRepaySheet(
  BuildContext context, {
  required String name,
  required bool isInstallment,
  required double suggestedAmount,
  int defaultAccountId = 0,
}) async {
  // 新增负债时 link_account_id 是可选技术列，用户几乎不会填；若还款时只回落
  // 主表，resolveRepayAccountIn 会抛错、整笔还款 100% 失败。这里直接从账户
  // 账本给出可选账户，信用卡不作为贷款扣款账户（IF-Z23）。
  final List<AccountRecord> accounts = context
      .read<AccountController>()
      .all
      .where((AccountRecord a) =>
          a.deletedAt == null && !a.archived && a.kind != AccountKind.credit)
      .toList(growable: false);
  final FormSheetController controller = FormSheetController();
  final SheetFormValues? values = await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '还一笔',
      subtitle: name,
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '确认还款',
        emphasized: true,
        onTap: controller.submit,
      ),
    ),
    child: FormSheetContent(
      controller: controller,
      items: <SheetFormItem>[
        SheetFormCustomItem(
          key: 'repayAccountId',
          label: '付款账户 *',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _AccountField(
            accounts: accounts,
            initial: defaultAccountId,
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'amount',
          label: '本次实还金额 *',
          initialValue: suggestedAmount.toStringAsFixed(2),
          hint: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          showClearButton: true,
          validator: (String v) {
            final double? d = double.tryParse(v.trim());
            if (d == null || d <= 0) return '请填大于 0 的金额';
            return null;
          },
        ),
        SheetFormNoteItem(
          key: '_repay_hint',
          text: '当期应还约 ${suggestedAmount.toStringAsFixed(2)} 元；'
              '多还的部分按提前还款冲本金。',
          centered: false,
        ),
        const SheetFormToggleItem(
          key: 'prepay',
          label: '这是主动提前还款 / 提前结清',
          initialValue: false,
          dividerAbove: true,
        ),
        if (!isInstallment) ...<SheetFormItem>[
          const SheetFormToggleItem(
            key: 'payCurrent',
            label: '先还完本期本金 + 利息 + 费用',
            initialValue: true,
            dividerAbove: true,
          ),
          const SheetFormToggleItem(
            key: 'hasPenalty',
            label: '本次有提前还款违约金',
            initialValue: false,
            dividerAbove: true,
          ),
        ],
        if (isInstallment) ...<SheetFormItem>[
          const SheetFormToggleItem(
            key: 'settleAll',
            label: '全额提前结清',
            initialValue: false,
            dividerAbove: true,
          ),
          SheetFormCustomItem(
            key: 'settleRule',
            label: '提前结清规则',
            builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
                _ChoiceField(
              options: _kSettleRules,
              initial: _kSettleRules.first,
              labels: _kEnumLabels,
              onChanged: onChanged,
            ),
          ),
          const SheetFormSingleLineTextItem(
            key: 'ruleRatio',
            label: '比例（5% 填 0.05）',
            initialValue: '',
            hint: '选「按剩余本金比例收」时填',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SheetFormSingleLineTextItem(
            key: 'serviceFee',
            label: '另收服务费金额',
            initialValue: '',
            hint: '选「另收一笔服务费」时填',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ],
    ),
  );
  if (values == null) return null;
  final double amount = double.tryParse(values.text('amount').trim()) ?? 0;
  if (amount <= 0) return null;
  final Object? rawAccount = values.raw('repayAccountId');
  final int? repayAccountId = rawAccount is int
      ? rawAccount
      : int.tryParse(rawAccount?.toString().trim() ?? '');
  return AzRepaySheetResult(
    amount: amount,
    repayAccountId: repayAccountId,
    prepay: values.flag('prepay'),
    payCurrentTerm: values.flag('payCurrent'),
    hasPenalty: values.flag('hasPenalty'),
    settleAll: values.flag('settleAll'),
    partialMode: 'B',
    settleRule: values.text('settleRule').trim().isEmpty
        ? null
        : values.text('settleRule').trim(),
    ruleRatio: double.tryParse(values.text('ruleRatio').trim()),
    serviceFee: double.tryParse(values.text('serviceFee').trim()),
  );
}

AzRecord? _findMain(AzData data, String side, int id) {
  final List<AzRecord> all = side == 'asset' ? data.assets : data.liabilities;
  for (final AzRecord r in all) {
    if (r.id == id) return r;
  }
  return null;
}

/// 列 → 声明式表单项。枚举走中文下拉、日期走 YYYY-MM-DD、其余走单行文本（金额/整数改数字键盘）。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】按列元数据生成表单项；枚举显示中文但存英文 code；日期列编辑时把毫秒回显成日期串。
/// 【使用限制】软件计算列已由 AzSchema.editableColumns 排除；表单不写库。
/// 【入参与结果】收列清单与可选已有记录；返回 List<SheetFormItem>。
/// 【异常与调用方处理】不抛异常；未知录入种类按文本处理。
List<SheetFormItem> _itemsFor(List<AzColumn> cols, AzRecord? record) {
  final List<SheetFormItem> out = <SheetFormItem>[];
  for (final AzColumn c in cols) {
    final String raw = record == null ? '' : record.text(c.name);
    final String initial = _kDateCols.contains(c.name)
        ? _formatDate(raw)
        : raw;
    if (c.kind == AzInputKind.choice) {
      final String def = _kEnumDefault[c.name] ??
          (c.options.isEmpty ? '' : c.options.first);
      out.add(SheetFormCustomItem(
        key: c.name,
        label: c.label,
        builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
            _ChoiceField(
          options: c.options,
          initial: initial.isNotEmpty && c.options.contains(initial)
              ? initial
              : def,
          labels: _kEnumLabels,
          onChanged: onChanged,
        ),
      ));
    } else {
      out.add(SheetFormSingleLineTextItem(
        key: c.name,
        label: c.required ? '${c.label} *' : c.label,
        initialValue: initial,
        hint: _hintFor(c),
        showClearButton: true,
        keyboardType: _kDateCols.contains(c.name) || c.kind == AzInputKind.text
            ? null
            : const TextInputType.numberWithOptions(decimal: true),
        validator: _validatorFor(c),
      ));
    }
  }
  return out;
}

String? _hintFor(AzColumn c) {
  if (_kDateCols.contains(c.name)) return 'YYYY-MM-DD';
  if (c.kind == AzInputKind.money) return '0.00';
  if (c.kind == AzInputKind.integer) return '整数';
  return null;
}

String? Function(String)? _validatorFor(AzColumn c) {
  if (c.name == 'name') {
    return (String v) => v.trim().isEmpty ? '名称必填' : null;
  }
  if (_kDateCols.contains(c.name)) {
    return (String v) {
      final String s = v.trim();
      if (s.isEmpty) return null;
      if (_parseDate(s) == null) return '日期请填 YYYY-MM-DD';
      return null;
    };
  }
  if (c.kind == AzInputKind.money) {
    return (String v) {
      final String s = v.trim();
      if (s.isEmpty) return null;
      final double? d = double.tryParse(s);
      if (d == null || d < 0) return '金额请填不小于 0 的数字';
      return null;
    };
  }
  return null;
}

/// 表单值 → 写库 Map。整数列空写 0，金额列空写 '0'，枚举列空回退默认值，日期列转毫秒。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】把 SheetFormValues 按列种类转换成可直接写 DDL 的值。
/// 【使用限制】金额一律 String；日期一律 int 毫秒；不在这里做业务校验。
/// 【入参与结果】收列清单与表单值；返回写库 Map。
/// 【异常与调用方处理】不抛异常；非法日期按 0 处理，由业务层拒绝保存。
Map<String, Object?> _collect(List<AzColumn> cols, SheetFormValues values) {
  final Map<String, Object?> out = <String, Object?>{};
  for (final AzColumn c in cols) {
    final String raw = values.text(c.name).trim();
    if (_kDateCols.contains(c.name)) {
      out[c.name] = _parseDate(raw) ?? 0;
      continue;
    }
    switch (c.kind) {
      case AzInputKind.integer:
        out[c.name] = int.tryParse(raw) ?? 0;
      case AzInputKind.money:
        out[c.name] = raw.isEmpty ? '0' : raw;
      case AzInputKind.choice:
        out[c.name] = raw.isEmpty
            ? (_kEnumDefault[c.name] ?? (c.options.isEmpty ? '' : c.options.first))
            : raw;
      case AzInputKind.text:
        out[c.name] = raw;
    }
  }
  return out;
}

/// YYYY-MM-DD → 当日 0 点的毫秒时间戳；也兼容已经是毫秒的旧值。
int? _parseDate(String raw) {
  if (raw.isEmpty) return null;
  final int? ms = int.tryParse(raw);
  if (ms != null && ms > 100000000000) return ms;
  final List<String> parts = raw.split('-');
  if (parts.length != 3) return null;
  final int? y = int.tryParse(parts[0]);
  final int? m = int.tryParse(parts[1]);
  final int? d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d).millisecondsSinceEpoch;
}

/// 毫秒时间戳 → YYYY-MM-DD 回显；空值返回空串。
String _formatDate(String raw) {
  if (raw.isEmpty) return '';
  final int? ms = int.tryParse(raw);
  if (ms == null || ms <= 0) return '';
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  final String mm = d.month.toString().padLeft(2, '0');
  final String dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// ③ 删除确认，与账户页 `showAccountDeleteSheet` 同一套 ConfirmSheetContent。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】弹出危险操作确认表，点「确认删除」后 await 传入的删除动作，成功才关闭。
/// 【使用限制】onDelete 的异常由 ConfirmSheetContent 捕获并提示，弹层保持打开；关闭后页面需判 mounted。
/// 【入参与结果】收 context / name / onDelete；返回 Future<void>，调用方必须 await（确认与取消都正常结束）。
/// 【异常与调用方处理】onDelete 抛异常时弹层保持打开并提示；调用方需自行处理失败提示。
Future<void> showAzDeleteSheet(
  BuildContext context, {
  required String name,
  required Future<void> Function() onDelete,
}) async {
  await AppSheetShell.show<void>(
      context,
      header: const SheetHeader(
        title: '删除记录',
        centered: true,
        leading: SheetCancelAction(),
      ),
      child: ConfirmSheetContent(
        title: '删除「$name」？',
        description: _kDeleteDesc,
        secondaryLabel: '取消',
        primaryLabel: '确认删除',
        icon: AppIcons.trash,
        intent: SheetIntent.danger,
        footnote: '删除后进入回收站，30 天内可恢复。',
        onPrimaryAsync: () async {
          await onDelete();
        },
      ),
  );
}

/// 付款账户下拉：把「账户 id」变成人能看懂的账户名，避免用户手填技术主键。
/// 【所属模块】screens/ledger · 还款弹层
/// 【实现功能】列出未删除、未归档、非信用卡的账户，默认选中主表已绑定账户或第一个；首帧把选中 id 写回表单。
/// 【使用限制】无可用账户时渲染提示文本且不回传值；不写库。
/// 【入参与结果】构造收 accounts / initial / onChanged；无返回值。
/// 【异常与调用方处理】不抛异常；调用方判 repayAccountId 为空后提示先建账户。
class _AccountField extends StatefulWidget {
  const _AccountField({
    required this.accounts,
    required this.initial,
    required this.onChanged,
  });

  final List<AccountRecord> accounts;
  final int initial;
  final ValueChanged<Object?> onChanged;

  @override
  State<_AccountField> createState() => _AccountFieldState();
}

class _AccountFieldState extends State<_AccountField> {
  int? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.accounts.any((AccountRecord a) => a.id == widget.initial)
        ? widget.initial
        : (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accounts.isEmpty) {
      return const Text('还没有可用账户，请先到「账户」页新建一个流动资金账户。');
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _value,
        isExpanded: true,
        items: <DropdownMenuItem<int>>[
          for (final AccountRecord a in widget.accounts)
            DropdownMenuItem<int>(value: a.id, child: Text(a.name)),
        ],
        onChanged: (int? v) {
          if (v == null) return;
          setState(() => _value = v);
          widget.onChanged(v);
        },
      ),
    );
  }
}

/// 枚举下拉（SheetFormCustomItem 的逃生口）：显示中文，写回英文 code。
/// 初值在首帧之后写回表单，避免 build 阶段触发父组件 setState。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】渲染枚举下拉，选中项以中文显示、以原始 code 回传。
/// 【使用限制】options 为空时渲染空占位；labels 缺省时直接显示 code。
/// 【入参与结果】构造收 options / initial / labels / onChanged；无返回值。
/// 【异常与调用方处理】不抛异常；回调异常由调用方处理。
class _ChoiceField extends StatefulWidget {
  const _ChoiceField({
    required this.options,
    required this.initial,
    required this.onChanged,
    this.labels = const <String, String>{},
  });

  final List<String> options;
  final String initial;
  final ValueChanged<Object?> onChanged;
  final Map<String, String> labels;

  @override
  State<_ChoiceField> createState() => _ChoiceFieldState();
}

class _ChoiceFieldState extends State<_ChoiceField> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: widget.options.contains(_value) ? _value : widget.options.first,
        isExpanded: true,
        items: <DropdownMenuItem<String>>[
          for (final String o in widget.options)
            DropdownMenuItem<String>(
              value: o,
              child: Text(widget.labels[o] ?? o),
            ),
        ],
        onChanged: (String? v) {
          if (v == null) return;
          setState(() => _value = v);
          widget.onChanged(v);
        },
      ),
    );
  }
}
