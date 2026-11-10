import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_buttons.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_selectors.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/sheet_tokens.dart';

/// 原型 ⑤「单选列表」：标题 + 说明 + 圆角容器内的选项列表 +
/// 底部渐变「应用」按钮。
///
/// 泛型 [T] 用 `==` 比较，建议传 String / enum 这类可比较值。
/// 选中态由组件内部持有，点「应用」时把值交给 [onApply] 并关闭弹层。
class SelectSheetContent<T> extends StatefulWidget {
  const SelectSheetContent({
    super.key,
    required this.title,
    required this.options,
    required this.actionLabel,
    this.subtitle,
    this.initialValue,
    this.onChanged,
    this.onApply,
  });

  final String title;
  final String? subtitle;
  final List<SheetOption<T>> options;
  final String actionLabel;
  final T? initialValue;
  final ValueChanged<T?>? onChanged;
  final ValueChanged<T>? onApply;

  @override
  State<SelectSheetContent<T>> createState() => _SelectSheetContentState<T>();
}

class _SelectSheetContentState<T> extends State<SelectSheetContent<T>> {
  late T? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _select(T value) {
    setState(() => _value = value);
    widget.onChanged?.call(value);
  }

  void _apply() {
    final value = _value;
    if (value == null) return;
    widget.onApply?.call(value);
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SheetHeader(
          title: widget.title,
          subtitle: widget.subtitle,
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        SheetOptionList<T>(
          options: widget.options,
          value: _value,
          onChanged: _select,
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        SheetGradientButton(
          label: widget.actionLabel,
          onPressed: _value == null ? null : _apply,
        ),
      ],
    );
  }
}
