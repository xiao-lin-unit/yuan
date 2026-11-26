import 'package:material_ui/material_ui.dart';

import '../../database/ledger/az_record.dart';
import '../../database/ledger/az_schema.dart';

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

/// 先选类型（按类型组列出），再进动态表单。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】弹出按 AzSchema.groups 归好组的类型选择框，返回用户选中的 AzTypeSpec；取消返回 null。
/// 【使用限制】side 只能是 'asset' / 'liability'；页面拿到 null 时不得继续新增流程。
/// 【入参与结果】收 context 与 side；返回 Future<AzTypeSpec?>，调用方必须 await 并判 mounted。
/// 【异常与调用方处理】不抛异常；弹层被系统关闭返回 null；调用方需自行判空、判 mounted。
Future<AzTypeSpec?> showAzTypeSheet(BuildContext context, {required String side}) {
  return showDialog<AzTypeSpec>(
    context: context,
    builder: (BuildContext ctx) {
      final List<Widget> items = <Widget>[];
      for (final AzTypeGroup g in AzSchema.groups) {
        if (g.side != side) continue;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(g.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ));
        for (final AzTypeSpec t in AzSchema.typesOfGroup(g.key)) {
          items.add(SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(t),
            child: Text('${t.code}（${t.label}）'),
          ));
        }
      }
      return SimpleDialog(
        title: Text(side == 'asset' ? '新增资产：先选类型' : '新增负债：先选类型'),
        children: <Widget>[
          SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Column(children: items)),
          ),
        ],
      );
    },
  );
}

/// 按 AzSchema 列元数据生成主表 + 次表的动态表单。
/// 【所属模块】screens/ledger · 新增表单
/// 【实现功能】为选中的类型渲染主表与对应次表的全部可录入列（文本 / 整数 / 金额 / 枚举），提交时转成 AzEntryDraft；编辑时带出已有值。
/// 【使用限制】判别列、系统列、软件计算列不出现；金额按 TEXT 字符串提交，空金额写 '0'；不得在表单里写库。
/// 【入参与结果】收 context / spec / 可选 initialData 与 editId；返回 Future<AzEntryDraft?>，取消或名称为空时返回 null（名称为空会留在弹层并提示）。
/// 【异常与调用方处理】不抛异常；调用方必须判 null 与 mounted；写库异常由 AzWriteController 上抛，表单不吞。
Future<AzEntryDraft?> showAzEntrySheet(
  BuildContext context,
  AzTypeSpec spec, {
  AzData? initialData,
  int? editId,
}) {
  return showDialog<AzEntryDraft>(
    context: context,
    builder: (BuildContext ctx) => _AzEntryDialog(
      spec: spec,
      initialData: initialData,
      editId: editId,
    ),
  );
}

class _AzEntryDialog extends StatefulWidget {
  const _AzEntryDialog({required this.spec, this.initialData, this.editId});

  final AzTypeSpec spec;
  final AzData? initialData;
  final int? editId;

  @override
  State<_AzEntryDialog> createState() => _AzEntryDialogState();
}

class _AzEntryDialogState extends State<_AzEntryDialog> {
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  final Map<String, String> _choices = <String, String>{};
  final Map<String, String> _enumDefault = <String, String>{
    'status': 'normal',
    'state': 'pending',
    'record_source': 'user',
    'repay_method': 'equal_principal',
    'term_unit': 'month',
    'direction': 'out',
  };
  String _error = '';

  late final List<AzColumn> _mainCols;
  late final List<AzColumn> _subCols;

  @override
  void initState() {
    super.initState();
    _mainCols = AzSchema.editableColumns(widget.spec.mainTable);
    _subCols = AzSchema.editableColumns(widget.spec.subTable);
    final AzData? d = widget.initialData;
    final AzRecord? main = d == null || widget.editId == null
        ? null
        : _findMain(d, widget.editId!);
    final AzRecord? sub = d == null || widget.editId == null
        ? null
        : d.subFor(widget.editId!, widget.spec.subTable);
    for (final List<AzColumn> group in <List<AzColumn>>[_mainCols, _subCols]) {
      for (final AzColumn c in group) {
        final AzRecord? src = group == _mainCols ? main : sub;
        final String initial = src == null ? '' : src.text(c.name);
        if (c.kind == AzInputKind.choice) {
          _choices[c.name] = initial.isNotEmpty && c.options.contains(initial)
              ? initial
              : (_enumDefault[c.name] ?? (c.options.isEmpty ? '' : c.options.first));
        } else {
          _controllers[c.name] = TextEditingController(text: initial);
        }
      }
    }
  }

  AzRecord? _findMain(AzData d, int id) {
    final List<AzRecord> all = widget.spec.side == 'asset' ? d.assets : d.liabilities;
    for (final AzRecord r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Object? _valueOf(AzColumn c) {
    switch (c.kind) {
      case AzInputKind.choice:
        return _choices[c.name] ?? '';
      case AzInputKind.integer:
        final String s = _controllers[c.name]?.text.trim() ?? '';
        return int.tryParse(s) ?? 0;
      case AzInputKind.money:
        final String s = _controllers[c.name]?.text.trim() ?? '';
        return s.isEmpty ? '0' : s;
      case AzInputKind.text:
        return _controllers[c.name]?.text ?? '';
    }
  }

  Map<String, Object?> _collect(List<AzColumn> cols) => <String, Object?>{
        for (final AzColumn c in cols) c.name: _valueOf(c),
      };

  @override
  Widget build(BuildContext context) {
    final List<Widget> fields = <Widget>[
      Text('${widget.spec.code}（${widget.spec.label}）· 主表',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      ..._mainCols.map((AzColumn c) => _field(c)),
      const SizedBox(height: 12),
      Text('${widget.spec.label} · 次表',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      ..._subCols.map((AzColumn c) => _field(c)),
      if (_error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error, style: const TextStyle(color: Colors.red)),
        ),
    ];
    return AlertDialog(
      title: Text(widget.editId == null ? '新增${widget.spec.label}' : '编辑${widget.spec.label}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields)),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final Map<String, Object?> main = _collect(_mainCols);
            if ((main['name'] ?? '').toString().trim().isEmpty) {
              setState(() => _error = '名称必填');
              return;
            }
            Navigator.of(context).pop(AzEntryDraft(
              mainValues: main,
              subValues: _collect(_subCols),
            ));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _field(AzColumn c) {
    if (c.kind == AzInputKind.choice) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InputDecorator(
          decoration: InputDecoration(labelText: c.label, border: const OutlineInputBorder()),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _choices[c.name],
              isExpanded: true,
              items: <DropdownMenuItem<String>>[
                for (final String o in c.options)
                  DropdownMenuItem<String>(value: o, child: Text(o)),
              ],
              onChanged: (String? v) => setState(() => _choices[c.name] = v ?? ''),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _controllers[c.name],
        decoration: InputDecoration(
          labelText: c.required ? '${c.label} *' : c.label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: c.kind == AzInputKind.text
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
