import 'package:flutter/material.dart';

import '../../../database/category/category_record.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../../commons/icon/app_icon_badge.dart';
import '../../commons/icons/app_icons.dart';
import '../../commons/image/app_image.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kTileIconSize = 36;
const double _kTileIconGlyph = 20;
const double _kMiniActionHeight = 30;
const double _kMiniActionMinWidth = 34;
const double _kCardGap = 10;
const double _kHiddenOpacity = 0.5;

/// 分类管理页的一行。业务私有组件：只服务本页面，样式仍全部引用全局令牌，
/// 颜色只从 ColorScheme / AppThemeTokens 取，不写死任何 hex。
///
/// 结构：拖拽手柄 → 圆形图标（可点开编辑器）→ 【名称独占一行】+
/// 【排序 + 徽章 Wrap】→ 操作区（序号 / 在用 / 编辑 / 删除）。
///
/// 【布局说明】名称原来和「预设 / 已隐藏 / 语义」几个固定宽度徽章挤在
/// 同一个 Row 里：隐藏项多一个「已隐藏」徽章就会把整行撑出约 43dp，
/// Flutter 在右侧画出 "RIGHT OVERFLOWED BY ... PIXELS" 竖排溢出提示，
/// 名称也常被 ellipsis 挤没。现在拆成两行：
///   ① 名称单独一行，只受 Expanded 的宽度约束，必然显示得出来；
///   ② 排序数字与所有徽章放进 [Wrap]，徽章多时自动折行，横向永不溢出。
/// 修改时间按需求不再在这行展示，元信息只留「排序 N」。
class CategoryListTile extends StatelessWidget {
  const CategoryListTile({
    super.key,
    required this.record,
    required this.displayIndex,
    required this.dragIndex,
    required this.onEdit,
    required this.onToggleHidden,
    required this.onOrderTap,
    required this.onDelete,
  });

  final CategoryRecord record;

  /// 页面上显示的第几位（1-based），原型里的排序按钮文案。
  final int displayIndex;

  /// 传给 ReorderableDragStartListener 的列表下标。
  final int dragIndex;

  final VoidCallback onEdit;
  final VoidCallback onToggleHidden;
  final VoidCallback onOrderTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.appText;

    return Opacity(
      opacity: record.hidden ? _kHiddenOpacity : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Container(
          decoration: AppDecorations.item(context),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: dragIndex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  child: Icon(
                    AppIcons.dragHandle,
                    size: AppIconSize.medium,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: _kCardGap),
              GestureDetector(
                onTap: onEdit,
                child: _Leading(record: record),
              ),
              const SizedBox(width: _kCardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // ① 名称：独占一行，保证始终可见
                    Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.menuTitle,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // ② 排序 + 徽章：Wrap 自动折行，不再横向溢出
                    Wrap(
                      spacing: AppSpacing.xxs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          '排序 ${displayIndex + 1}',
                          style: text.caption,
                        ),
                        _Badge(
                          label: record.preset ? '预设' : '自定义',
                          background: record.preset
                              ? cs.surfaceContainerHighest
                              : cs.primaryContainer,
                          foreground: record.preset
                              ? cs.onSurfaceVariant
                              : cs.onPrimaryContainer,
                        ),
                        if (record.hidden)
                          _Badge(
                            label: '已隐藏',
                            background: cs.tertiaryContainer,
                            foreground: cs.onTertiaryContainer,
                          ),
                        if (record.kind == CategoryKind.expense &&
                            record.necessity != CategoryNecessity.unset)
                          _Badge(
                            label: record.necessity.label,
                            background: cs.primaryContainer,
                            foreground: cs.onPrimaryContainer,
                          ),
                        if (record.kind == CategoryKind.income &&
                            record.stability != CategoryStability.unset)
                          _Badge(
                            label: record.stability.label,
                            background: cs.tertiaryContainer,
                            foreground: cs.onTertiaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              _MiniAction(
                label: '${displayIndex + 1}',
                onTap: onOrderTap,
                tooltip: '填序号改排序',
              ),
              _MiniAction(
                label: record.hidden ? '已隐藏' : '在用',
                onTap: onToggleHidden,
                emphasized: !record.hidden,
                tooltip: record.hidden ? '恢复显示' : '隐藏',
              ),
              _MiniAction(
                label: '编辑',
                onTap: onEdit,
                tooltip: '编辑分类',
              ),
              _MiniAction(
                label: record.preset ? '×' : '删',
                onTap: onDelete,
                danger: !record.preset,
                tooltip: record.preset ? '预设分类不能删除' : '删除分类',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 圆形分类图标：内置矢量 / 上传图片 / 名称首字三种形态。
///
/// 原型里右下角有个相机角标，按本轮需求删除：整个图标就是一块干净的圆，
/// 点它照旧打开编辑器（点击热区由外层 GestureDetector 提供）。
class _Leading extends StatelessWidget {
  const _Leading({required this.record});

  final CategoryRecord record;

  @override
  Widget build(BuildContext context) {
    final Widget core = switch (record.icon.kind) {
      CategoryIconKind.image when record.icon.imageRef != null => AppImage(
          ref: record.icon.imageRef,
          size: _kTileIconSize,
          shape: ImageShape.circle,
          placeholder: _TextFallback(record: record),
        ),
      CategoryIconKind.icon => AppIconBadge(
          icon: AppIcons.categoryIcon(record.icon.value),
          size: _kTileIconSize,
          iconSize: _kTileIconGlyph,
          toneKey: record.name,
        ),
      _ => _TextFallback(record: record),
    };

    return SizedBox(
      width: _kTileIconSize,
      height: _kTileIconSize,
      child: ClipOval(child: core),
    );
  }
}

class _TextFallback extends StatelessWidget {
  const _TextFallback({required this.record});

  final CategoryRecord record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String label = record.icon.value.isNotEmpty
        ? record.icon.value
        : (record.name.isEmpty ? '·' : record.name.substring(0, 1));
    return Container(
      width: _kTileIconSize,
      height: _kTileIconSize,
      alignment: Alignment.center,
      color: cs.surfaceContainerHighest,
      child: Text(label, style: context.appText.caption),
    );
  }
}

/// 小徽章（预设 / 已隐藏 / 必须花的…）。颜色全由调用方从 ColorScheme 取。
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: foreground),
        ),
      );
}

/// 操作区的小按钮。原型是灰底圆角小方块；这里用 surfaceContainerHighest
/// 随明暗自动取色，强调态用 primaryContainer，危险态用 error 色。
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.onTap,
    required this.tooltip,
    this.emphasized = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final String tooltip;
  final bool emphasized;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color background = emphasized
        ? cs.primaryContainer
        : cs.surfaceContainerHighest;
    final Color foreground = danger
        ? cs.error
        : emphasized
            ? cs.onPrimaryContainer
            : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: _kMiniActionMinWidth,
              minHeight: _kMiniActionHeight,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
