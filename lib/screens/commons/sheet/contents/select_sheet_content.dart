import 'dart:async';

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
/// 选中态由组件内部持有，**点「应用」确认后**才把值交给使用方。
///
/// 提交链路与表单组件一致（这点很关键）：
/// [onApplyAsync] 会被 `await` 完成，写盘 / 持久化成功才关闭弹层；
/// 抛异常则 SnackBar 提示且弹窗保持打开，保存中禁用重复点击。
/// 主题切换这类「先写 SharedPreferences 再改内存」的操作必须走它，
/// 不能把 Future 丢给同步 [onApply]，否则界面先关、写入失败无人知。
/// 两个回调都不传时（纯预览）直接回传选中值。
class SelectSheetContent<T> extends StatefulWidget {
  const SelectSheetContent({
    super.key,
    required this.title,
    required this.options,
    this.actionLabel = '应用',
    this.action = true,
    this.subtitle,
    this.initialValue,
    this.onChanged,
    this.onApply,
    this.onApplyAsync,
  });

  final String title;
  final String? subtitle;
  final List<SheetOption<T>> options;
  final String actionLabel;
  final bool action;
  final T? initialValue;
  final ValueChanged<T?>? onChanged;

  /// 同步确认回调（简单场景 / 兼容旧调用）
  final ValueChanged<T>? onApply;

  /// 异步确认回调（需要写盘、网络、await 的场景）；优先于 [onApply]
  final Future<void> Function(T value)? onApplyAsync;

  @override
  State<SelectSheetContent<T>> createState() => _SelectSheetContentState<T>();
}

class _SelectSheetContentState<T> extends State<SelectSheetContent<T>> {
  late T? _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 初始值不在选项里（例如外部存了自定义主题 key）时按「未选择」处理，
    // 按钮保持禁用，避免把无效值回传给业务层。
    final initial = widget.initialValue;
    _value = widget.options.any((o) => o.value == initial) ? initial : null;
  }

  void _select(T value) {
    if (_saving) return;
    setState(() => _value = value);
    widget.onChanged?.call(value);
  }

  Future<void> _apply() async {
    if (_saving) return;
    final value = _value;
    if (value == null) return;

    setState(() => _saving = true);
    try {
      final asyncHandler = widget.onApplyAsync;
      if (asyncHandler != null) {
        await asyncHandler(value);
      } else {
        widget.onApply?.call(value);
      }
      // 只有确认成功才关闭，并把选中值回传给 AppSheetShell.show<T>
      if (mounted) unawaited(Navigator.maybePop<T>(context, value));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('应用失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        if (widget.action) ...[
          const SizedBox(height: AppSheetSize.sectionGap),
          SheetGradientButton(
            label: widget.actionLabel,
            onPressed: _value == null ? null : () => unawaited(_apply()),
            loading: _saving,
          ),
        ]
      ],
    );
  }
}
