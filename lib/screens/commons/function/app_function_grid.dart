import 'package:material_ui/material_ui.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import 'app_floating_actions.dart';

/// 详情页的**横排功能入口**（图标在上、文字在下，一行 5 个等分）。
///
/// 以前这些操作藏在右下角悬浮按钮里：点「更多」才展开一列小圆钮，名称
/// 只有长按 tooltip 能看到。参考的基金详情页把它们平铺在首屏——每条
/// 功能都是「一个细线性图标 + 一行小字」，一眼看全、一步点到。
///
/// 数据契约直接复用 [AppFloatingAction]（纯 label / icon / onPressed），
/// 三个详情页已有的分派表一个字都不用改；`emphasized` 在这里忽略：
/// 参考页里五个图标同色同重，谁都不该抢主角数字的戏。
///
/// 【职能归位】图标取 `cs.primary` 而不是固定蓝 `tokens.info`：
/// 按「主色管品牌与操作 / 中性色管信息 / 固定蓝管状态·导航·分类」的分工，
/// 这些是可点击的**操作入口**，和品牌头、弹层主按钮同属操作层；固定蓝留
/// 给底导、Tab 下划线、快筛选中、分类胶囊、统计格选中这些状态标记。
/// 上一版把功能格归进固定蓝是职能判断错了，本轮随品牌头一起改回来。
///
/// 超过 [columns] 个自动换行，末行补空占位保持每格等宽，不会拉成
/// 「两个格子各占半屏」。行与行之间只用一条发丝线分隔。
class AppFunctionGrid extends StatelessWidget {
  const AppFunctionGrid({
    super.key,
    required this.actions,
    this.columns = 5,
  });

  final List<AppFloatingAction> actions;

  /// 每行格数；参考页是 5 个。信用卡账户有 7 项，会自动排成 5 + 2。
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    final int perRow = columns < 1 ? 1 : columns;

    final List<List<AppFloatingAction>> rows = <List<AppFloatingAction>>[];
    for (int i = 0; i < actions.length; i += perRow) {
      final int end =
          i + perRow > actions.length ? actions.length : i + perRow;
      rows.add(actions.sublist(i, end));
    }

    // InkWell 的水波纹必须画在一层 Material 上；容器装饰交给 Ink，
    // 否则只有 Container + BoxDecoration 时点击反馈会消失。
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: AppDecorations.card(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int r = 0; r < rows.length; r++) ...<Widget>[
              if (r > 0)
                Divider(
                  height: 1,
                  thickness: AppBorder.thin,
                  color: t.divider,
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final AppFloatingAction action in rows[r])
                    _cell(action, cs.primary, cs.onSurfaceVariant),
                  // 多行时给末行补空位，保持每格宽度与满行一致、左对齐
                  // 不拉伸；只有一行（如资产页 2 项）则按实际数量均分，
                  // 不让两个格子只占左侧、右边空一大片。
                  if (rows.length > 1)
                    for (int k = rows[r].length; k < perRow; k++)
                      const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(
    AppFloatingAction action,
    Color iconColor,
    Color labelColor,
  ) =>
      Expanded(
        child: InkWell(
          onTap: action.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xxs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(action.icon, size: AppIconSize.large, color: iconColor),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.categoryLabel.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
