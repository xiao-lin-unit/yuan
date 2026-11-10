import 'package:flutter/material.dart';

import 'sheet_models.dart';

/// 声明式表单的**数据契约**。
///
/// 使用方只描述「每一项叫什么（label）、用什么控件、初值是什么」，
/// 不写任何颜色 / 字号 / 圆角 / 间距，也不自己创建 TextEditingController。
/// 控件的选择、布局节奏、样式、状态管理与值收集全部由
/// `FormSheetContent` 统一负责。
///
/// 与 `sheet_models.dart` 的分工：
/// - 那里是「展示型内容组件」（概览 / 确认 / 选择…）的数据；
/// - 这里是「可编辑表单」的数据，且是 sealed 类型层级，
///   公共组件用穷尽 switch 分发，新增控件类型时编译期就会提示补渲染。
sealed class SheetFormItem {
  const SheetFormItem({
    required this.key,
    this.label,
    this.dividerAbove = false,
  });

  /// 字段标识，用于 [SheetFormValues] 取值。同一表单内必须唯一。
  final String key;

  /// 左侧标签。头像这类居中控件通常传 null（由组件自行决定不渲染标签行）。
  final String? label;

  /// 该项上方是否插入一条全局分隔线（原型里「标签」与「设为公开」之间）。
  final bool dividerAbove;
}

/// 单行 / 多行文本输入。
///
/// [validator] 返回非空字符串表示校验失败，错误文案由公共组件渲染在字段内。
final class SheetFormTextItem extends SheetFormItem {
  const SheetFormTextItem({
    required super.key,
    required super.label,
    this.initialValue = '',
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.showClearButton = false,
    this.showCounter = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    super.dividerAbove,
  });

  final String initialValue;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool showClearButton;
  final bool showCounter;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String value)? validator;
  final ValueChanged<String>? onChanged;
}

/// 头像 / 单图字段。
///
/// 公共组件负责整圆容器、相机角标、点击热区与尺寸（原型 ③ 的样式），
/// 具体图片控件由 [builder] 填充 —— 这样表单组件不依赖任何业务图片分类，
/// 账单凭证、分类图标等以后都能复用同一项类型。
///
/// [initialValue] 必须显式传入「未改动」哨兵（业务层用 `imageUndefined`）；
/// [builder] 的 `onChanged` 回调 `ImageCandidate` 或 `null`，公共组件只转存，
/// 不解释其含义。
final class SheetFormAvatarItem extends SheetFormItem {
  const SheetFormAvatarItem({
    required super.key,
    required this.initialValue,
    required this.builder,
    super.label,
    this.onTap,
    super.dividerAbove,
  });

  final Object? initialValue;

  /// [size] 由公共组件按全局令牌注入，业务层不写死头像尺寸。
  final Widget Function(
    BuildContext context,
    ValueChanged<Object?> onChanged,
    double size,
  ) builder;
  final VoidCallback? onTap;
}

/// 胶囊标签组（可多选）。
///
/// 标签值统一用 [Object]（String / enum 均可），避免把泛型参数渗到公共组件。
final class SheetFormTagsItem extends SheetFormItem {
  const SheetFormTagsItem({
    required super.key,
    required super.label,
    required this.options,
    this.initialSelected = const <Object>{},
    super.dividerAbove,
  });

  final List<SheetTag<Object>> options;
  final Set<Object> initialSelected;
}

/// 开关行。
final class SheetFormToggleItem extends SheetFormItem {
  const SheetFormToggleItem({
    required String key,
    required String? label,
    this.initialValue = false,
    bool dividerAbove = true,
  }) : super(key: key, label: label, dividerAbove: dividerAbove);

  final bool initialValue;
}

/// 完全自定义项的逃生口：使用方给内容，公共组件负责标签行与上下节奏。
/// 用于日期选择、金额输入等尚未纳入标准控件类型的情况。
final class SheetFormCustomItem extends SheetFormItem {
  const SheetFormCustomItem({
    required super.key,
    required this.builder,
    super.label,
    super.dividerAbove,
  });

  /// [onChanged] 让自定义控件也能把值写回表单，由公共组件统一收集。
  final Widget Function(BuildContext context, ValueChanged<Object?> onChanged)
      builder;
}

/// 底部说明小字（「头像仅保存在本设备，不会上传云端。」）。
final class SheetFormNoteItem extends SheetFormItem {
  const SheetFormNoteItem({
    required String key,
    required this.text,
    this.centered = false,
    this.align = TextAlign.end,
    bool dividerAbove = false,
  }) : super(key: key, label: null, dividerAbove: dividerAbove);

  final String text;
  final bool centered;

  /// 默认右对齐（原型「头像仅保存在本设备」的排版）
  final TextAlign align;
}

/// 提交时交给业务层的**类型化取值容器**。
///
/// 业务层不再持有 controller，也不再自己拼临时变量；
/// 只按 [SheetFormItem.key] 取值即可。
@immutable
class SheetFormValues {
  const SheetFormValues(this._values);

  final Map<String, Object?> _values;

  /// 文本值（未填返回空串）
  String text(String key) {
    final Object? v = _values[key];
    return v is String ? v : '';
  }

  /// 开关值
  bool flag(String key) => _values[key] == true;

  /// 标签选中集合
  Set<Object> tags(String key) {
    final Object? v = _values[key];
    return v is Set ? Set<Object>.unmodifiable(v.cast<Object>()) : const <Object>{};
  }

  /// 原始值（头像这类非文本项用）
  Object? raw(String key) => _values[key];

  /// 泛型取值
  T? get<T extends Object>(String key) {
    final Object? v = _values[key];
    return v is T ? v : null;
  }

  bool contains(String key) => _values.containsKey(key);

  Map<String, Object?> toMap() => Map<String, Object?>.unmodifiable(_values);

  @override
  String toString() => 'SheetFormValues(${_values.keys.join(', ')})';
}
