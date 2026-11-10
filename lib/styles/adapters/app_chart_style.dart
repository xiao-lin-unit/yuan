import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_typography.dart';
import '../color_math.dart';
import '../theme_tokens.dart';

/// fl_chart 的**唯一**样式适配层。
///
/// 为什么需要它：fl_chart 不读 `ThemeData` 的组件主题，所有颜色都由
/// `LineChartData / BarChartData / PieChartData` 自己带。若每个页面各写一遍
/// `Colors.blue` / `Colors.grey`，换主题色或切暗色时图表就会掉队。
///
/// 本层把「取色」与「组装」全部收进来：
/// - 颜色只来自 `ColorScheme` 与 `AppThemeTokens`（收入 / 支出 / 容器 / 分割线）；
/// - 圆角、描边、间距、透明度只来自 `AppRadius / AppBorder / AppSpacing / AppOpacity`；
/// - 字号只来自 `AppTypography`。
///
/// 业务页面只负责提供数据，不写任何颜色和尺寸：
/// ```dart
/// final s = AppChartStyle.of(context);
/// LineChart(s.lineChart(incomeSpots: ..., expenseSpots: ..., bottomLabels: ...));
/// ```
///
/// 换主题时 `AppChartStyle.of(context)` 重新取到新的 ColorScheme 与 tokens，
/// 图表自动跟随，不需要回头改图表代码。
class AppChartStyle {
  AppChartStyle(this.cs, this.tokens);

  final ColorScheme cs;
  final AppThemeTokens tokens;

  static AppChartStyle of(BuildContext context) => AppChartStyle(
        Theme.of(context).colorScheme,
        context.tokens,
      );

  // ── 语义色（业务只认这些名字，不认 hex）──────────────────────
  Color get income => tokens.income;
  Color get expense => tokens.expense;
  Color get warning => tokens.warning;
  Color get info => tokens.info;
  Color get grid => tokens.divider.withValues(alpha: AppOpacity.outline);
  Color get axisLabel => cs.onSurfaceVariant;
  Color get tooltipBackground => cs.inverseSurface;
  Color get tooltipText => cs.onInverseSurface;
  Color get track => cs.surfaceContainerHighest;
  Color get surface => tokens.card;

  TextStyle get axisTextStyle =>
      AppTypography.caption.copyWith(color: axisLabel);
  TextStyle get tooltipTextStyle =>
      AppTypography.labelSmall.copyWith(color: tooltipText);

  // ── 通用坐标 / 网格 / 边框 ──────────────────────────────────
  FlGridData gridData({double interval = 1, bool drawVertical = false}) =>
      FlGridData(
        show: true,
        drawVerticalLine: drawVertical,
        horizontalInterval: interval,
        verticalInterval: interval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: grid,
          strokeWidth: AppBorder.thin,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: grid,
          strokeWidth: AppBorder.thin,
        ),
      );

  FlBorderData borderData() => FlBorderData(
        show: true,
        border: Border.all(color: grid, width: AppBorder.thin),
      );

  /// 统一的四边标题：只显示左轴与底轴，右/上轴关闭。
  FlTitlesData titlesData({
    required List<String> bottomLabels,
    String Function(double value)? leftLabel,
    double interval = 1,
  }) {
    Widget bottomBuilder(double value, TitleMeta meta) {
      final i = value.toInt();
      if (i < 0 || i >= bottomLabels.length) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(bottomLabels[i], style: axisTextStyle),
      );
    }

    return FlTitlesData(
      show: true,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: leftLabel != null,
          interval: interval,
          reservedSize: 44,
          getTitlesWidget: (value, meta) =>
              Text(leftLabel?.call(value) ?? '', style: axisTextStyle),
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: interval,
          reservedSize: 28,
          getTitlesWidget: bottomBuilder,
        ),
      ),
    );
  }

  LineTouchData lineTouchData({String Function(double value)? label}) {
    final formatter = label ?? (value) => value.toStringAsFixed(0);
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => tooltipBackground,
        tooltipBorderRadius: BorderRadius.circular(AppRadius.small),
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        tooltipMargin: AppSpacing.xs,
        tooltipBorder: BorderSide.none,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (spots) => spots
            .map((spot) => LineTooltipItem(
                  formatter(spot.y),
                  tooltipTextStyle,
                ))
            .toList(),
      ),
    );
  }

  BarTouchData barTouchData({String Function(double value)? label}) {
    final formatter = label ?? (value) => value.toStringAsFixed(0);
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => tooltipBackground,
        tooltipBorderRadius: BorderRadius.circular(AppRadius.small),
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        tooltipMargin: AppSpacing.xs,
        tooltipBorder: BorderSide.none,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
          formatter(rod.toY),
          tooltipTextStyle,
        ),
      ),
    );
  }

  // ── 图元 ────────────────────────────────────────────────────
  LineChartBarData lineBar({
    required List<FlSpot> spots,
    required Color color,
    double width = 2,
    bool showArea = true,
  }) =>
      LineChartBarData(
        spots: spots,
        color: color,
        barWidth: width,
        isCurved: true,
        curveSmoothness: 0.25,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: showArea,
          color: color.withValues(alpha: AppOpacity.disabledContainer),
        ),
      );

  BarChartRodData barRod({
    required double toY,
    required Color color,
    double? maxY,
    double width = AppSpacing.md,
  }) =>
      BarChartRodData(
        toY: toY,
        color: color,
        width: width,
        borderRadius: BorderRadius.circular(AppRadius.small),
        backDrawRodData: maxY == null
            ? null
            : BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: track,
              ),
      );

  PieChartSectionData pieSection({
    required double value,
    required Color color,
    required String title,
    double radius = 48,
  }) =>
      PieChartSectionData(
        value: value,
        color: color,
        radius: radius,
        title: title,
        // 扇区文字要按扇区底色自动选黑/白，不能写死白色
        titleStyle: AppTypography.labelSmall.copyWith(
          color: ColorMath.onColorFor(color),
        ),
        cornerRadius: AppRadius.small,
      );

  // ── 整图组装 ────────────────────────────────────────────────
  LineChartData lineChart({
    required List<FlSpot> incomeSpots,
    required List<FlSpot> expenseSpots,
    required List<String> bottomLabels,
    String Function(double value)? leftLabel,
    String Function(double value)? tooltipLabel,
    double gridInterval = 1,
    double? maxY,
  }) =>
      LineChartData(
        gridData: gridData(interval: gridInterval),
        titlesData: titlesData(
          bottomLabels: bottomLabels,
          leftLabel: leftLabel,
          interval: gridInterval,
        ),
        borderData: borderData(),
        minX: 0,
        maxX: (bottomLabels.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: <LineChartBarData>[
          lineBar(spots: incomeSpots, color: income),
          lineBar(spots: expenseSpots, color: expense),
        ],
        lineTouchData: lineTouchData(label: tooltipLabel),
        backgroundColor: surface,
      );

  BarChartData barChart({
    required List<double> values,
    required List<String> bottomLabels,
    Color? color,
    double? maxY,
    double gridInterval = 1,
    String Function(double value)? leftLabel,
    String Function(double value)? tooltipLabel,
  }) =>
      BarChartData(
        gridData: gridData(interval: gridInterval),
        titlesData: titlesData(
          bottomLabels: bottomLabels,
          leftLabel: leftLabel,
          interval: gridInterval,
        ),
        borderData: borderData(),
        minY: 0,
        maxY: maxY,
        barGroups: <BarChartGroupData>[
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                barRod(
                  toY: values[i],
                  color: color ?? income,
                  maxY: maxY,
                ),
              ],
            ),
        ],
        barTouchData: barTouchData(label: tooltipLabel),
        backgroundColor: surface,
      );

  PieChartData pieChart({
    required List<PieChartSectionData> sections,
    double centerSpaceRadius = AppSpacing.xl,
  }) =>
      PieChartData(
        sections: sections,
        sectionsSpace: AppSpacing.xxs,
        centerSpaceRadius: centerSpaceRadius,
        centerSpaceColor: Colors.transparent,
        startDegreeOffset: -90,
        borderData: FlBorderData(show: false),
      );
}
