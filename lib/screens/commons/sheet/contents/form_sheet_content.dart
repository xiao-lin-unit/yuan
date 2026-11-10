import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_buttons.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_inputs.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_selectors.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 原型 ③「表单编辑」：三栏顶栏（取消 / 标题 / 保存）+ 圆形头像与相机角标
/// + 若干表单行 + 标签胶囊组 + 分隔线 + 开关行 + 底部渐变主按钮。
///
/// 标签选中态与开关值由组件内部持有（纯 UI 状态），通过回调交给业务层；
/// 字段文本由 `TextFormField` 自持有并通过 [SheetFieldSpec.onChanged] 外抛。
/// 这样业务层不用为了「点一下标签」再建一个 Controller。
class FormSheetContent<T> extends StatefulWidget {
  const FormSheetContent({
    super.key,
    required this.title,
    required this.fields,
    required this.tags,
    required this.submitLabel,
    this.cancelLabel = '取消',
    this.saveLabel = '保存',
    this.tagLabel = '标签',
    this.avatar,
    this.onAvatarTap,
    this.initialSelectedTags,
    this.onTagsChanged,
    this.switchRow,
    this.onCancel,
    this.onSave,
    this.onSubmit,
    this.loading = false,
  });

  final String title;
  final List<SheetFieldSpec> fields;
  final List<SheetTag<T>> tags;
  final String submitLabel;
  final String cancelLabel;
  final String saveLabel;
  final String tagLabel;
  final Widget? avatar;
  final VoidCallback? onAvatarTap;
  final Set<T>? initialSelectedTags;
  final ValueChanged<Set<T>>? onTagsChanged;
  final SheetSwitchSpec? switchRow;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;
  final VoidCallback? onSubmit;
  final bool loading;

  @override
  State<FormSheetContent<T>> createState() => _FormSheetContentState<T>();
}

class _FormSheetContentState<T> extends State<FormSheetContent<T>> {
  late Set<T> _selectedTags;
  late bool _switchValue;

  @override
  void initState() {
    super.initState();
    _selectedTags = Set<T>.of(widget.initialSelectedTags ?? <T>{});
    _switchValue = widget.switchRow?.value ?? false;
  }

  void _toggleTag(T value) {
    setState(() {
      if (_selectedTags.contains(value)) {
        _selectedTags.remove(value);
      } else {
        _selectedTags.add(value);
      }
    });
    widget.onTagsChanged?.call(Set<T>.unmodifiable(_selectedTags));
  }

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SheetHeader(
          title: widget.title,
          centered: true,
          leading: SheetTextAction(
            label: widget.cancelLabel,
            onTap: widget.onCancel ?? () => Navigator.maybePop(context),
          ),
          trailing: SheetTextAction(
            label: widget.saveLabel,
            emphasized: true,
            onTap: widget.onSave ?? widget.onSubmit ?? () {},
          ),
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        SheetAvatarField(
          image: widget.avatar,
          onTap: widget.onAvatarTap,
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        for (var i = 0; i < widget.fields.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSheetSize.itemGap),
          SheetFormField(spec: widget.fields[i]),
        ],
        if (widget.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSheetSize.sectionGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Text(widget.tagLabel, style: text.optionLabel),
              ),
              Expanded(
                child: SheetTagGroup<T>(
                  tags: widget.tags,
                  selected: _selectedTags,
                  onToggle: _toggleTag,
                ),
              ),
            ],
          ),
        ],
        if (widget.switchRow != null) ...<Widget>[
          const SizedBox(height: AppSheetSize.sectionGap),
          Divider(
            height: AppBorder.thin,
            thickness: AppBorder.thin,
            color: p.dividerColor,
          ),
          SheetSwitchRow(
            spec: SheetSwitchSpec(
              label: widget.switchRow!.label,
              value: _switchValue,
              onChanged: (value) {
                setState(() => _switchValue = value);
                widget.switchRow!.onChanged(value);
              },
            ),
          ),
        ],
        const SizedBox(height: AppSheetSize.sectionGap),
        SheetGradientButton(
          label: widget.submitLabel,
          onPressed: widget.onSubmit,
          loading: widget.loading,
        ),
      ],
    );
  }
}
