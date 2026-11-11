import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_buttons.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_inputs.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_selectors.dart';
import 'package:yuan/screens/commons/sheet/sheet_form_items.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 表单顶栏「保存」按钮的显式触发器。
///
/// 【本项目唯一一处「跨组件触发内部动作」的动态逻辑，把工作逻辑写清楚】
///
/// 为什么需要它：
///   · 壳的 header 是**静态** Widget 槽位（构造期定死、固定在滚动区外）；
///   · 但「点保存 → 校验 → await onSubmit → 成功才关闭」必须留在
///     [FormSheetContent] 内部：它持有 FormState、各 TextEditingController、
///     _saving 防连点标记，外部拿不到这些。
///   · 所以用一个小句柄，把「调用方 header 里的静态按钮」接到「内部提交方法」。
///
/// 工作逻辑（只有 3 步；没有 InheritedWidget / Notifier / 跨帧回调）：
///   1. 调用方 new 一个 controller，同一个实例同时传给
///      header 的保存按钮（`onTap: controller.submit`）和
///      [FormSheetContent.controller]；
///   2. initState 把内部 `_submit` 包一层赋给 `controller._submit`，
///      dispose 时置空；
///   3. 点按钮 → `controller.submit()` → 内部走原来的 await 提交链路。
///
/// 未传 controller、或组件已销毁时 submit 是空操作，不会崩。
/// 如果不想用这个句柄：把保存按钮留在内容里、只保留底部渐变主按钮即可，
/// 那样全静态，但表单顶栏就没有「保存」了。
class FormSheetController {
  VoidCallback? _submit;

  void submit() => _submit?.call();
}

/// 原型 ③「表单编辑」的**公共表单组件**。
///
/// 职责边界（通用 / 私有分开）：
/// - 本组件只做「编排 + 状态 + 值收集」：遍历 [items]、按控件类型分发、
///   管理 TextEditingController / 标签 / 开关 / 图片值、校验、防连点提交、
///   分隔线与渐变主按钮。
/// - 顶栏（标题 + 取消 + 保存）由调用方**静态**传给
///   `AppSheetShell.show(header: SheetHeader(...))`，壳固定在顶端；
///   「保存」按钮通过 [FormSheetController] 触发本组件内部的提交。
/// - 每一项长什么样由 `parts/` 里的通用零件决定（全部引用全局令牌）；
///   使用方只传 [SheetFormItem]，描述「label + 控件类型 + 初值 + 校验」，
///   **不写样式、不创建 controller、不碰 Navigator**。
/// - 因此新增一种控件类型时，只需在 `sheet_form_items.dart` 加一个 sealed
///   子类、在本文件的 `_buildItem` 补一个 case，业务侧零改动。
///
/// 提交语义沿用前面修过的 await 链路：
/// 先 `validate()`，再 `await onSubmit(values)`；保存中禁用重复点击，
/// 抛异常时保留弹窗并提示，成功后才通过 [SheetActions.close] 请求关闭
/// （内容组件不直接操作 Navigator，可脱离 Sheet 复用）。
class FormSheetContent extends StatefulWidget {
  const FormSheetContent({
    super.key,
    required this.items,
    this.submitLabel = '提交修改',
    this.submit = false,
    this.onSubmit,
    this.loading = false,
    this.controller,
  });

  /// 表单项声明（label + 控件类型 + 配置），顺序即渲染顺序。
  final List<SheetFormItem> items;

  final String submitLabel;

  /// 底部主按钮提交。不传时只做校验并回传值（预览 / 只读场景）。
  final Future<void> Function(SheetFormValues values)? onSubmit;

  /// 外部控制的保存态（与内部 `_saving` 合并）
  final bool loading;

  /// 顶栏「保存」按钮的触发器。工作逻辑见 [FormSheetController] 注释。
  final FormSheetController? controller;

  /// 是否显示底部渐变主按钮（顶栏「保存」走 controller，两者可并存）。
  final bool submit;

  @override
  State<FormSheetContent> createState() => _FormSheetContentState();
}

class _FormSheetContentState extends State<FormSheetContent> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// 文本项：key -> controller
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  /// 非文本项：key -> 当前值
  final Map<String, Object?> _values = <String, Object?>{};

  bool _saving = false;

  bool get _busy => _saving || widget.loading;

  @override
  void initState() {
    super.initState();
    _resetFromItems();
    // [FormSheetController] 工作逻辑第 2 步：把内部提交方法挂到句柄上。
    widget.controller?._submit = () => unawaited(_submit());
  }

  @override
  void didUpdateWidget(covariant FormSheetContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了 controller 就把旧的解绑、新的绑上（正常弹层不会换，这里只是兜底）。
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._submit = null;
      widget.controller?._submit = () => unawaited(_submit());
    }
    // 仅在「字段集合真的变了」时重置，避免普通 rebuild 冲掉用户已输入的内容
    if (!_sameItemKeys(oldWidget.items, widget.items)) {
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      _values.clear();
      _resetFromItems();
      // FormFieldState 仍持有旧 validator / 旧值，帧后重置一次最稳妥
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.reset();
      });
    }
  }

  static bool _sameItemKeys(List<SheetFormItem> a, List<SheetFormItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }

  void _resetFromItems() {
    for (final item in widget.items) {
      switch (item) {
        case SheetFormSingleLineTextItem(
            :final String key,
            :final String initialValue
          ):
          _controllers[key] = TextEditingController(text: initialValue);
        case SheetFormMultiLineTextItem(
            :final String key,
            :final String initialValue
          ):
          _controllers[key] = TextEditingController(text: initialValue);
        case SheetFormAvatarItem(:final String key, :final Object? initialValue):
          _values[key] = initialValue;
        case SheetFormTagsItem(:final String key, :final Set<Object> initialSelected):
          _values[key] = Set<Object>.of(initialSelected);
        case SheetFormToggleItem(:final String key, :final bool initialValue):
          _values[key] = initialValue;
        case SheetFormCustomItem(:final String key):
          _values[key] = null;
        case SheetFormNoteItem(:final String key):
          _values[key] = null;
      }
    }
  }

  @override
  void dispose() {
    // 弹层关闭后，顶栏按钮不应再触发已销毁的提交逻辑。
    widget.controller?._submit = null;
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── 值收集 ────────────────────────────────────────────────────
  SheetFormValues _collect() {
    final map = <String, Object?>{};
    for (final item in widget.items) {
      switch (item) {
        case SheetFormSingleLineTextItem(
            :final String key,
            :final String initialValue
          ):
          map[key] = _controllers[key]?.text ?? initialValue;
        case SheetFormMultiLineTextItem(
            :final String key,
            :final String initialValue
          ):
          map[key] = _controllers[key]?.text ?? initialValue;
        case SheetFormAvatarItem(:final String key):
          map[key] = _values[key];
        case SheetFormTagsItem(:final String key):
          final v = _values[key];
          map[key] = v is Set<Object> ? Set<Object>.of(v) : <Object>{};
        case SheetFormToggleItem(:final String key, :final bool initialValue):
          map[key] = _values[key] is bool ? _values[key] : initialValue;
        case SheetFormCustomItem(:final String key):
          map[key] = _values[key];
        case SheetFormNoteItem(:final String key):
          map[key] = _values[key];
      }
    }
    return SheetFormValues(map);
  }

  void _setValue(String key, Object? value) {
    if (!mounted) return;
    setState(() => _values[key] = value);
  }

  // ── 提交 ──────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_busy) return;
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;

    final values = _collect();
    final handler = widget.onSubmit;

    if (handler == null) {
      if (mounted) SheetActions.close(context, values);
      return;
    }

    setState(() => _saving = true);
    try {
      await handler(values);
      if (mounted) SheetActions.close(context, values);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── 渲染分发 ──────────────────────────────────────────────────
  Widget _buildItem(SheetFormItem item) {
    return switch (item) {
      SheetFormSingleLineTextItem() => SheetSingleLineFormField(
          label: item.label ?? '',
          controller: _controllers[item.key]!,
          hintText: item.hint,
          maxLength: item.maxLength,
          showClearButton: item.showClearButton,
          keyboardType: item.keyboardType,
          textInputAction: item.textInputAction,
          validator: item.validator == null
              ? null
              : (v) => item.validator!(v ?? ''),
          onChanged: item.onChanged,
        ),
      SheetFormMultiLineTextItem() => SheetMultiLineFormField(
          label: item.label ?? '',
          controller: _controllers[item.key]!,
          hintText: item.hint,
          maxLength: item.maxLength,
          maxLines: item.maxLines,
          minLines: item.minLines,
          showClearButton: item.showClearButton,
          showCounter: item.showCounter,
          keyboardType: item.keyboardType,
          textInputAction: item.textInputAction,
          validator: item.validator == null
              ? null
              : (v) => item.validator!(v ?? ''),
          onChanged: item.onChanged,
        ),
      SheetFormAvatarItem() => SheetAvatarField(
          size: AppSheetSize.avatarSize,
          onTap: item.onTap,
          image: item.builder(
            context,
            (v) => _setValue(item.key, v),
            AppSheetSize.avatarSize,
          ),
        ),
      SheetFormTagsItem() => SheetFormLabeledRow(
          label: item.label,
          child: SheetTagGroup<Object>(
            tags: item.options,
            selected: (_values[item.key] is Set<Object>)
                ? _values[item.key] as Set<Object>
                : const <Object>{},
            onToggle: (Object value) {
              final next = Set<Object>.of(
                (_values[item.key] is Set<Object>)
                    ? _values[item.key] as Set<Object>
                    : const <Object>{},
              );
              if (!next.remove(value)) next.add(value);
              _setValue(item.key, next);
            },
          ),
        ),
      SheetFormToggleItem() => SheetSwitchRow(
          label: item.label ?? '',
          value: (_values[item.key] is bool)
              ? _values[item.key] as bool
              : item.initialValue,
          onChanged: (v) => _setValue(item.key, v),
        ),
      SheetFormCustomItem() => SheetFormLabeledRow(
          label: item.label,
          child: item.builder(context, (v) => _setValue(item.key, v)),
        ),
      SheetFormNoteItem() => SheetCaption(
          text: item.text,
          centered: item.centered,
          align: item.centered ? TextAlign.center : item.align,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < widget.items.length; i++) ...<Widget>[
            if (i > 0)
              SizedBox(
                height: (widget.items[i] is SheetFormAvatarItem ||
                        widget.items[i - 1] is SheetFormAvatarItem)
                    ? AppSheetSize.sectionGap
                    : AppSheetSize.itemGap,
              ),
            if (widget.items[i].dividerAbove) ...<Widget>[
              Divider(
                height: 1,
                thickness: AppBorder.thin,
                color: p.dividerColor,
              ),
              const SizedBox(height: AppSheetSize.itemGap),
            ],
            _buildItem(widget.items[i]),
          ],
          if (widget.submit) ...[
            const SizedBox(height: AppSheetSize.sectionGap),
            SheetGradientButton(
              label: widget.submitLabel,
              // 保持非 null 以留住渐变与光晕；loading 由公共组件负责禁用点击
              onPressed: () => unawaited(_submit()),
              loading: _busy,
            ),
          ]


        ],
      ),
    );
  }
}
