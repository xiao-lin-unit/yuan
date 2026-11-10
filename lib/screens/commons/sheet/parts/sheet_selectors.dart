import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/color_math.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有常量（只服务本文件）────────────────────────────────
const double _kTagHeight = 40;
const double _kTagHPadding = AppSpacing.md;
const double _kTagGap = AppSpacing.xs;
const double _kOptionContainerRadius = AppRadius.card;
const double _kOptionIconGap = AppSpacing.md;
const double _kOptionHPadding = AppSpacing.md;
const double _kTileGap = AppSpacing.sm;
const double _kTileLabelGap = AppSpacing.xs;

/// 胶囊标签组：选中项浅紫底 + 主色文字 + 勾，未选浅灰底。
/// 复用在「编辑资料」的标签行与「分类选择」的最近使用行。
class SheetTagGroup<T> extends StatelessWidget {
  const SheetTagGroup({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final List<SheetTag<T>> tags;
  final Set<T> selected;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);
    return Wrap(
      spacing: _kTagGap,
      runSpacing: _kTagGap,
      children: <Widget>[
        for (final tag in tags)
          _TagPill(
            label: tag.label,
            selected: selected.contains(tag.value),
            tint: p.selectedTint,
            plainTint: p.unselectedTint,
            selectedStyle: text.chipLabelSelected,
            plainStyle: text.chipLabel,
            onTap: () => onToggle(tag.value),
          ),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.selected,
    required this.tint,
    required this.plainTint,
    required this.selectedStyle,
    required this.plainStyle,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color tint;
  final Color plainTint;
  final TextStyle selectedStyle;
  final TextStyle plainStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tint : plainTint,
      borderRadius: BorderRadius.circular(AppSheetRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSheetRadius.pill),
        onTap: onTap,
        child: Container(
          height: _kTagHeight,
          padding: const EdgeInsets.symmetric(horizontal: _kTagHPadding),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Icon(
                  AppIcons.check,
                  size: AppIconSize.small,
                  color: selectedStyle.color,
                ),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Text(
                label,
                style: selected ? selectedStyle : plainStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单选列表：一个圆角容器包住若干行，选中行浅紫底 + 实心对勾圆，
/// 未选行右侧空心圈，行间细分隔线。
class SheetOptionList<T> extends StatelessWidget {
  const SheetOptionList({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SheetOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kOptionContainerRadius),
      child: Container(
        decoration: BoxDecoration(
          color: p.glassColor,
          borderRadius: BorderRadius.circular(_kOptionContainerRadius),
          border: Border.all(
            color: p.glassBorder,
            width: AppBorder.thin,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < options.length; i++) ...<Widget>[
              _OptionRow<T>(
                option: options[i],
                selected: options[i].value == value,
                p: p,
                text: text,
                onTap: () => onChanged(options[i].value),
              ),
              if (i < options.length - 1)
                Divider(
                  height: AppBorder.thin,
                  thickness: AppBorder.thin,
                  color: p.dividerColor,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.p,
    required this.text,
    required this.onTap,
  });

  final SheetOption<T> option;
  final bool selected;
  final SheetPalette p;
  final SheetText text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? p.selectedTint : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppSheetSize.optionRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kOptionHPadding,
            ),
            child: Row(
              children: <Widget>[
                _OptionLeading(option: option, selected: selected, p: p),
                const SizedBox(width: _kOptionIconGap),
                Expanded(
                  child: Text(
                    option.label,
                    style: selected
                        ? text.optionLabelSelected
                        : text.optionLabel,
                  ),
                ),
                Icon(
                  selected
                      ? AppIcons.radioChecked
                      : AppIcons.radioUnchecked,
                  size: AppSheetSize.optionRadioSize,
                  color: selected ? p.cs.primary : p.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 选项行的 leading：有代表色就画色点，否则画语义图标。
///
/// 色点尺寸 / 描边 / 选中环全部来自全局令牌与 [SheetPalette]，
/// 使用方只提供「这个选项代表什么颜色」这一份数据。
class _OptionLeading<T> extends StatelessWidget {
  const _OptionLeading({
    required this.option,
    required this.selected,
    required this.p,
  });

  final SheetOption<T> option;
  final bool selected;
  final SheetPalette p;

  @override
  Widget build(BuildContext context) {
    final Color? swatch = option.swatch;
    if (swatch != null) {
      return Container(
        width: AppSheetSize.optionSwatchSize,
        height: AppSheetSize.optionSwatchSize,
        decoration: BoxDecoration(
          color: swatch,
          shape: BoxShape.circle,
          border: Border.all(
            // 按 WCAG 相对亮度自动选黑/白：8 个种子色深浅不一，
            // 固定白环在浅色上会糊掉，固定黑环在深色上又看不清。
            color: selected
                ? ColorMath.onColorFor(swatch)
                : p.dividerColor.withValues(alpha: AppOpacity.outline),
            width: selected ? AppBorder.focused : AppBorder.thin,
          ),
          boxShadow: selected ? p.primaryGlow : null,
        ),
      );
    }
    return Icon(
      option.icon!,
      size: AppIconSize.medium,
      color: selected ? p.cs.primary : p.mutedText,
    );
  }
}

/// 分类网格：圆角方形浅色底 + 彩色线性图标 + 下方文字，
/// 选中项实心主色底 + 反色图标 + 光晕，文字变主色。
class SheetCategoryGrid<T> extends StatelessWidget {
  const SheetCategoryGrid({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.columns = AppSheetSize.categoryColumns,
  });

  final List<SheetCategory<T>> categories;
  final T? selected;
  final ValueChanged<T> onSelected;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tileWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth - (columns - 1) * _kTileGap) / columns
            : AppSheetSize.categoryTileSize;
        return Wrap(
          spacing: _kTileGap,
          runSpacing: _kTileGap,
          children: <Widget>[
            for (var i = 0; i < categories.length; i++)
              SizedBox(
                width: tileWidth,
                child: _CategoryTile<T>(
                  category: categories[i],
                  index: i,
                  selected: categories[i].value == selected,
                  p: p,
                  text: text,
                  onTap: () => onSelected(categories[i].value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile<T> extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.index,
    required this.selected,
    required this.p,
    required this.text,
    required this.onTap,
  });

  final SheetCategory<T> category;
  final int index;
  final bool selected;
  final SheetPalette p;
  final SheetText text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = p.categoryTone(index);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSheetSize.categoryTileSize,
            height: AppSheetSize.categoryTileSize,
            decoration: BoxDecoration(
              color: selected ? p.cs.primary : p.categoryTileTone(index),
              borderRadius: BorderRadius.circular(AppSheetRadius.tile),
              border: Border.all(
                color: selected
                    ? Colors.transparent
                    : tone.withValues(alpha: AppOpacity.outline),
                width: AppBorder.thin,
              ),
              boxShadow: selected ? p.primaryGlow : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              category.icon,
              size: AppSheetSize.categoryIconSize,
              color: selected ? p.onPrimaryGradient : tone,
            ),
          ),
          const SizedBox(height: _kTileLabelGap),
          Text(
            category.label,
            textAlign: TextAlign.center,
            style: selected
                ? text.categoryLabelSelected
                : text.categoryLabel,
          ),
        ],
      ),
    );
  }
}
