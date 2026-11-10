import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_selectors.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 原型 ⑥「分类网格」：标题 + 圆形关闭 + 说明 + 「最近使用」胶囊 +
/// 「全部 / N 个」小标题 + 4 列彩色图标网格 + 底部提示。
///
/// 点击任一分格即完成选择（原型提示「点击分类即可完成选择」），
/// 不需要额外主按钮；选中项由组件内部持有并立即外抛 + 关闭。
/// 分类颜色由 `SheetPalette.categoryTone(index)` 从主色等距旋转派生，
/// 12 个格子天然协调，换主题 / 切明暗时整体平移。
class CategorySheetContent<T> extends StatefulWidget {
  const CategorySheetContent({
    super.key,
    required this.title,
    required this.categories,
    this.subtitle,
    this.recent = const [],
    this.recentLabel = '最近使用',
    this.allLabel = '全部',
    this.hint,
    this.initialSelected,
    this.onSelected,
  });

  final String title;
  final String? subtitle;
  final List<SheetCategory<T>> categories;
  final List<SheetCategory<T>> recent;
  final String recentLabel;
  final String allLabel;
  final String? hint;
  final T? initialSelected;
  final ValueChanged<T>? onSelected;

  @override
  State<CategorySheetContent<T>> createState() =>
      _CategorySheetContentState<T>();
}

class _CategorySheetContentState<T> extends State<CategorySheetContent<T>> {
  T? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  void _choose(T value) {
    setState(() => _selected = value);
    widget.onSelected?.call(value);
    Navigator.maybePop(context, value);
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
          trailing: const SheetCloseButton(),
        ),
        if (widget.recent.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSheetSize.sectionGap),
          SheetSectionLabel(label: widget.recentLabel),
          const SizedBox(height: AppSpacing.sm),
          SheetTagGroup<T>(
            tags: <SheetTag<T>>[
              for (final c in widget.recent)
                SheetTag<T>(value: c.value, label: c.label),
            ],
            selected: <T>{
              if (_selected != null) _selected as T,
            },
            onToggle: _choose,
          ),
        ],
        const SizedBox(height: AppSheetSize.sectionGap),
        SheetSectionLabel(
          label: widget.allLabel,
          count: '${widget.categories.length} 个',
        ),
        const SizedBox(height: AppSpacing.md),
        SheetCategoryGrid<T>(
          categories: widget.categories,
          selected: _selected,
          onSelected: _choose,
        ),
        if (widget.hint != null) ...<Widget>[
          const SizedBox(height: AppSheetSize.sectionGap),
          SheetCaption(text: widget.hint!, centered: true),
        ],
      ],
    );
  }
}
