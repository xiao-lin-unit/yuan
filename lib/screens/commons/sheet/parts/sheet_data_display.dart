import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/app_typography.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有常量（只服务本文件）────────────────────────────────
const double _kCardPadding = AppSpacing.sm;
const double _kCardInnerGap = AppSpacing.sm;
const double _kTrendMinBarHeight = 12;
const double _kTrendLabelGap = AppSpacing.xs;
const double _kTrendBaselineGap = AppSpacing.xxs;
const double _kTrendBarTopRadius = AppSheetSize.trendBarWidth / 2;

/// 指标卡：细描边圆角容器，上小标签、下大号主色数值 + 可选单位。
class SheetMetricCard extends StatelessWidget {
  const SheetMetricCard({super.key, required this.metric});

  final SheetMetric metric;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);
    return Container(
      constraints: const BoxConstraints(
        minHeight: AppSheetSize.metricCardMinHeight,
      ),
      padding: const EdgeInsets.all(_kCardPadding),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSheetRadius.metricCard),
        border: Border.all(
          color: p.glassBorder,
          width: AppBorder.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(metric.label, style: text.metricLabel),
          const SizedBox(height: _kCardInnerGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(metric.value, style: text.metricValue),
                if (metric.unit != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xxs),
                  Text(metric.unit!, style: text.metricUnit),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行并排指标卡（原型里 3 张）。
class SheetMetricRow extends StatelessWidget {
  const SheetMetricRow({super.key, required this.metrics});

  final List<SheetMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < metrics.length; i++) ...<Widget>[
          if (i > 0)
            const SizedBox(width: AppSheetSize.metricCardGap),
          Expanded(child: SheetMetricCard(metric: metrics[i])),
        ],
      ],
    );
  }
}

/// 7 根趋势柱：未选灰柱、高亮柱走主色竖向渐变，底部基线 + 星期标签。
///
/// 这里刻意不用 fl_chart —— 原型是极简装饰性柱图，无坐标轴 / tooltip /
/// 交互需求，用纯 Container 画更轻，也不会把图表库的默认蓝色带进来。
/// 需要真实分析的折线 / 饼图时，仍走 `styles/adapters/app_chart_style.dart`。
class SheetTrendBars extends StatelessWidget {
  const SheetTrendBars({
    super.key,
    required this.points,
    this.height = AppSheetSize.trendHeight,
  });

  final List<SheetTrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);
    final double maxValue = points.isEmpty
        ? 1
        : points
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
            .clamp(0.001, 1.0)
            .toDouble();
    final double barAreaHeight = height - AppIconSize.large - _kTrendLabelGap;

    final LinearGradient highlightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        p.cs.primary,
        p.primaryGradient.colors.last.withValues(alpha: 0.55),
      ],
    );

    return SizedBox(
      height: height,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: barAreaHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final point in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxs,
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _Bar(
                          height: (point.value / maxValue) * barAreaHeight,
                          highlighted: point.highlighted,
                          inactiveColor: p.inactiveBar,
                          gradient: highlightGradient,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: AppSheetSize.trendBaselineWidth,
            color: p.dividerColor,
            margin: const EdgeInsets.only(top: _kTrendBaselineGap),
          ),
          const SizedBox(height: _kTrendLabelGap),
          Row(
            children: <Widget>[
              for (final point in points)
                Expanded(
                  child: Text(
                    point.label,
                    textAlign: TextAlign.center,
                    style: point.highlighted
                        ? AppTypography.trendLabel.copyWith(
                            color: p.cs.primary,
                            fontWeight: FontWeight.w600,
                          )
                        : text.trendLabel,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.highlighted,
    required this.inactiveColor,
    required this.gradient,
  });

  final double height;
  final bool highlighted;
  final Color inactiveColor;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSheetSize.trendBarWidth,
      height: height < _kTrendMinBarHeight ? _kTrendMinBarHeight : height,
      decoration: BoxDecoration(
        gradient: highlighted ? gradient : null,
        color: highlighted ? null : inactiveColor,
        borderRadius: BorderRadius.circular(_kTrendBarTopRadius),
      ),
    );
  }
}
