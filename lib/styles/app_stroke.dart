import 'package:flutter/material.dart';

/// 全软件**唯一**的「划分性描边」真源。
///
/// 旧版做法是 `cs.outlineVariant` 实色 + 0.5 不透明度 + 1dp：
/// - 亮色下 outlineVariant 是中灰，线明显比卡片深 → 「颜色又很暗」；
/// - 暗色下它比容器还深，叠 0.5 alpha 后变成一条深沟 → 「区域界限太明显」；
/// - 1dp 在高分屏上等于 2~3 物理像素 → 「偏粗」。
///
/// 现在改为：**往背景里掺一点 onSurface 的中性色**。
/// 亮色得到极浅灰线（不暗），暗色得到略亮的线（不是深沟），
/// 两端都与容器底色同族，对比度天然低；再配 [AppStroke.width] 的
/// 0.6dp 发丝线，划分感只剩「轻轻一道」。
///
/// 所有容器描边、分隔线、选项容器、图片占位框都从这里取色，
/// 改一处即可整体调节，禁止组件里再写 `cs.outline` / `cs.outlineVariant`
/// / `cs.onSurfaceVariant` 当边框色。
abstract final class AppStroke {
  AppStroke._();

  /// 常规划分线宽：0.6dp（2x 屏 ≈1 物理像素，3x 屏 ≈2）。
  static const double width = 0.6;

  /// 需要明确可见的强调线（选中 / 聚焦 / 角标），仍比旧版 2dp 细。
  static const double emphasisWidth = 1.5;

  /// 中性色掺入比例：亮色 10% 黑、暗色 14% 白。
  static double _mix(ColorScheme cs) =>
      cs.brightness == Brightness.dark ? 0.14 : 0.10;

  /// 实色（不带 alpha），因为很多调用方会再叠一次
  /// `withValues(alpha: AppOpacity.outline)`，这里再带 alpha 会二次衰减。
  static Color colorFor(ColorScheme cs) =>
      Color.lerp(cs.surface, cs.onSurface, _mix(cs)) ?? cs.outlineVariant;

  static Color color(BuildContext context) =>
      colorFor(Theme.of(context).colorScheme);

  static BorderSide sideFor(ColorScheme cs) =>
      BorderSide(color: colorFor(cs), width: width);

  static BorderSide side(BuildContext context) =>
      sideFor(Theme.of(context).colorScheme);

  static Border allFor(ColorScheme cs) =>
      Border.all(color: colorFor(cs), width: width);

  static Border all(BuildContext context) =>
      allFor(Theme.of(context).colorScheme);
}
