import 'package:flutter/material.dart';

/// Sheet 内容组件的**数据契约**。
///
/// 这些类只描述「要展示什么」，不含任何颜色、字号、圆角、间距；
/// 所有视觉表现由 `lib/styles/sheet_tokens.dart` 与 `parts/` 里的通用零件负责。
/// 业务层（DAO / Controller）只需构造这些对象，不需要 import 任何样式文件。

/// 概览指标卡：标签 + 数值 + 可选单位。
@immutable
class SheetMetric {
  const SheetMetric({
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
}

/// 趋势柱：标签 + 归一化数值（0..1）+ 是否高亮。
@immutable
class SheetTrendPoint {
  const SheetTrendPoint({
    required this.label,
    required this.value,
    this.highlighted = false,
  }) : assert(value >= 0 && value <= 1);

  final String label;
  final double value;
  final bool highlighted;
}

/// 单选列表项。
@immutable
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// 分类网格项。颜色由 `SheetPalette.categoryTone(index)` 按位置派生，
/// 业务层不传颜色，只传语义图标。
@immutable
class SheetCategory<T> {
  const SheetCategory({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// 胶囊标签项。
@immutable
class SheetTag<T> {
  const SheetTag({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

/// 表单行：左侧 label + 右侧可编辑值，支持单行 / 多行。
@immutable
class SheetFieldSpec {
  const SheetFieldSpec({
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final String value;
  final int maxLines;
  final ValueChanged<String>? onChanged;
}

/// 开关行。
@immutable
class SheetSwitchSpec {
  const SheetSwitchSpec({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
}

/// 底栏文字动作（播放列表 / 定时关闭之类）。
@immutable
class SheetFooterAction {
  const SheetFooterAction({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;
}

/// 确认弹层的语义类型：决定图标徽章与危险按钮的取色。
enum SheetIntent { neutral, danger, warning, success }
