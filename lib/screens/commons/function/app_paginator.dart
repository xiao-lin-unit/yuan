import 'package:material_ui/material_ui.dart';

import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../icons/app_icons.dart';

/// 通用分页条：**纯展示、无内部状态**（页码由使用方的 Controller 持有）。
///
/// 【工作逻辑，静态，一眼能读完】
///   ① pageCount <= 0 → 不渲染（无记录由页面的空态负责）；
///   ② 上一页 / 下一页在边界把 onPressed 置 null，Material 自动变淡；
///   ③ 中间的下拉直接选页，满足「切换到哪一页」；页码由外部保证在
///      1..pageCount，组件里仍 clamp 一次，防止误传导致 DropdownButton
///      的 value 不在 items 里而崩；
///   ④ 右侧文字固定展示「总条数 · 总页数 · 每页条数」。
///
/// 【为什么用 Wrap 而不是 Row】窄屏上四个控件加起来容易横向溢出
/// （分类列表那次 43px 溢出就是固定宽度 Row 造成的），Wrap 自动折行。
///
/// 【取舍】总页数很多时下拉会逐项生成 DropdownMenuItem；本地记账场景
/// 一年几百条、十年几千条（几百页）完全够用。真到上万页时把下拉换成
/// 「窗口页码按钮」即可，其余布局不用动。
class AppPaginator extends StatelessWidget {
  const AppPaginator({
    super.key,
    required this.page,
    required this.pageCount,
    required this.total,
    required this.pageSize,
    required this.onPageChanged,
  });

  /// 当前页，1-based。
  final int page;

  /// 总页数，0 表示无记录。
  final int pageCount;

  /// 当前筛选下的总条数。
  final int total;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 0) return const SizedBox.shrink();
    // 显式三段判断：num.clamp 静态返回 num，赋给 int 需 toInt()。
    final int current =
        page < 1 ? 1 : (page > pageCount ? pageCount : page);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: <Widget>[
        IconButton(
          icon: const Icon(AppIcons.chevronLeft, size: AppIconSize.medium),
          tooltip: '上一页',
          constraints: const BoxConstraints(
            minWidth: kMinTapTarget,
            minHeight: kMinTapTarget,
          ),
          padding: EdgeInsets.zero,
          onPressed:
              current > 1 ? () => onPageChanged(current - 1) : null,
        ),
        DropdownButton<int>(
          value: current,
          isDense: true,
          underline: const SizedBox.shrink(),
          iconSize: AppIconSize.small,
          style: context.appText.caption,
          items: <DropdownMenuItem<int>>[
            for (int i = 1; i <= pageCount; i++)
              DropdownMenuItem<int>(value: i, child: Text('第 $i 页')),
          ],
          onChanged: (int? v) {
            if (v != null && v != current) onPageChanged(v);
          },
        ),
        IconButton(
          icon: const Icon(AppIcons.chevronRight, size: AppIconSize.medium),
          tooltip: '下一页',
          constraints: const BoxConstraints(
            minWidth: kMinTapTarget,
            minHeight: kMinTapTarget,
          ),
          padding: EdgeInsets.zero,
          onPressed: current < pageCount
              ? () => onPageChanged(current + 1)
              : null,
        ),
        Text(
          '共 $total 条 · $pageCount 页 · 每页 $pageSize 条',
          style: context.appText.caption,
        ),
      ],
    );
  }
}
