import 'package:material_ui/material_ui.dart';

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
import 'widgets/az_cards.dart';

// ── 页面私有文案（样式一律走全局层）─────────────────────────────
const String _kTypeHint = '按类型组排列，选一次类型后只填这一类专属字段。';
const String _kFormNote = '金额按元填写，可带两位小数；不填的金额按 0 记。';
const String _kDeleteDesc = '删除后进入回收站，主表与次表记录都会保留，只是不再显示。';

/// 一次新增 / 编辑提交上来的字段值。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】承载动态表单填出的主表字段与次表字段，交给 AzWriteController 写库。
/// 【使用限制】不可变；键必须来自 AzSchema.editableColumns；金额一律 String。
/// 【入参与结果】构造收 mainValues / subValues；消费方只读字段。
/// 【异常与调用方处理】不抛异常；空 Map 表示没有可编辑字段，调用方按「只建主表」处理。
class AzEntryDraft {
  const AzEntryDraft({required this.mainValues, required this.subValues});

  final Map<String, Object?> mainValues;
  final Map<String, Object?> subValues;
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
/// 【使用限制】判别列、系统列、软件计算列不出现；金额按 String 提交、空金额写 '0'；表单不写库。
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
      subtitle: '${spec.code}（${spec.label}）· 主表 + 次表',
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
            text: '以下内容写进该类型专属的次表。',
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

AzRecord? _findMain(AzData data, String side, int id) {
  final List<AzRecord> all = side == 'asset' ? data.assets : data.liabilities;
  for (final AzRecord r in all) {
    if (r.id == id) return r;
  }
  return null;
}

/// 列 → 声明式表单项。枚举走自定义下拉，其余走单行文本（金额/整数改数字键盘）。
List<SheetFormItem> _itemsFor(List<AzColumn> cols, AzRecord? record) {
  final List<SheetFormItem> out = <SheetFormItem>[];
  for (final AzColumn c in cols) {
    final String initial = record == null ? '' : record.text(c.name);
    if (c.kind == AzInputKind.choice) {
      final String def = _kEnumDefault[c.name] ??
          (c.options.isEmpty ? '' : c.options.first);
      out.add(SheetFormCustomItem(
        key: c.name,
        label: c.label,
        builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
            _ChoiceField(
          options: c.options,
          initial: initial.isNotEmpty && c.options.contains(initial) ? initial : def,
          onChanged: onChanged,
        ),
      ));
    } else {
      out.add(SheetFormSingleLineTextItem(
        key: c.name,
        label: c.required ? '${c.label} *' : c.label,
        initialValue: initial,
        hint: c.kind == AzInputKind.money ? '0.00' : null,
        showClearButton: true,
        keyboardType: c.kind == AzInputKind.text
            ? null
            : const TextInputType.numberWithOptions(decimal: true),
        validator: c.name == 'name'
            ? (String v) => v.trim().isEmpty ? '名称必填' : null
            : null,
      ));
    }
  }
  return out;
}

/// 表单值 → 写库 Map。整数列空写 0，金额列空写 '0'，枚举列空回退默认值。
Map<String, Object?> _collect(List<AzColumn> cols, SheetFormValues values) {
  final Map<String, Object?> out = <String, Object?>{};
  for (final AzColumn c in cols) {
    final String raw = values.text(c.name).trim();
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
        leading: const SheetCancelAction(),
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

/// 枚举下拉（SheetFormCustomItem 的逃生口）。
/// 初值在首帧之后写回表单，避免 build 阶段触发父组件 setState。
class _ChoiceField extends StatefulWidget {
  const _ChoiceField({
    required this.options,
    required this.initial,
    required this.onChanged,
  });

  final List<String> options;
  final String initial;
  final ValueChanged<Object?> onChanged;

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
            DropdownMenuItem<String>(value: o, child: Text(o)),
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
