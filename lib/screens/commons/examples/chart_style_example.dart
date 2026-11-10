import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../styles/adapters/app_chart_style.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../scaffold/app_page_scaffold.dart';

// ── 样例私有内容（只服务本页；样式一律走全局层）────────────────
const String _kPageTitle = '图表样式样例';
const List<double> _kIncome = <double>[1200, 1800, 1500, 2200, 1900, 2600, 2300];
const List<double> _kExpense = <double>[800, 1100, 900, 1300, 1000, 1500, 1200];
const List<String> _kWeek = <String>['一', '二', '三', '四', '五', '六', '日'];
const double _kChartHeight = 200;
const double _kMaxY = 3000;

/// 可直接放进「分析」页的样例。
///
/// 关键点：整页没有出现任何 `Color(0xFF...)` / `fontSize:` / `BorderRadius`，
/// 颜色与尺寸全部由 [AppChartStyle] 从当前 ColorScheme + AppThemeTokens 取。
/// 在「主题」里循环切换 8 个预设、或切到暗色，三张图会一起跟着变，
/// 不需要回来改一行图表代码。
///
/// 接入真实数据时，把 `_kIncome / _kExpense` 换成 DAO 查出来的聚合值即可：
/// ```dart
/// final values = await dao.weeklyTotals(weekStart);
/// LineChart(AppChartStyle.of(context).lineChart(
///   incomeSpots: values.income, expenseSpots: values.expense,
///   bottomLabels: values.labels,
/// ));
/// ```
class ChartStyleExample extends StatelessWidget {
  const ChartStyleExample({super.key});

  static List<FlSpot> _spots(List<double> values) => <FlSpot>[
        for (var i = 0; i < values.length; i++)
          FlSpot(i.toDouble(), values[i]),
      ];

  @override
  Widget build(BuildContext context) {
    final s = AppChartStyle.of(context);

    return AppPageScaffold(
      title: _kPageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ChartCard(
            title: '本周收支趋势',
            legend: <_LegendItem>[
              _LegendItem('收入', s.income),
              _LegendItem('支出', s.expense),
            ],
            child: SizedBox(
              height: _kChartHeight,
              child: LineChart(
                s.lineChart(
                  incomeSpots: _spots(_kIncome),
                  expenseSpots: _spots(_kExpense),
                  bottomLabels: _kWeek,
                  leftLabel: (v) => '${v.toInt()}',
                  tooltipLabel: (v) => '¥ ${v.toInt()}',
                  gridInterval: 1000,
                  maxY: _kMaxY,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          _ChartCard(
            title: '每日支出',
            child: SizedBox(
              height: _kChartHeight,
              child: BarChart(
                s.barChart(
                  values: _kExpense,
                  bottomLabels: _kWeek,
                  color: s.expense,
                  leftLabel: (v) => '${v.toInt()}',
                  tooltipLabel: (v) => '¥ ${v.toInt()}',
                  gridInterval: 1000,
                  maxY: _kMaxY,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          _ChartCard(
            title: '收支占比',
            child: SizedBox(
              height: _kChartHeight,
              child: PieChart(
                s.pieChart(
                  sections: <PieChartSectionData>[
                    s.pieSection(
                      value: _kIncome.reduce((a, b) => a + b),
                      color: s.income,
                      title: '收入',
                    ),
                    s.pieSection(
                      value: _kExpense.reduce((a, b) => a + b),
                      color: s.expense,
                      title: '支出',
                    ),
                    s.pieSection(
                      value: _kIncome.reduce((a, b) => a + b) -
                          _kExpense.reduce((a, b) => a + b),
                      color: s.info,
                      title: '结余',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem {
  const _LegendItem(this.label, this.color);

  final String label;
  final Color color;
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.legend = const <_LegendItem>[],
  });

  final String title;
  final Widget child;
  final List<_LegendItem> legend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.sectionHeader
                      .copyWith(color: cs.onSurface),
                ),
              ),
              for (final item in legend) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: AppComponentSize.calendarMarkerSize + 2,
                  height: AppComponentSize.calendarMarkerSize + 2,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  item.label,
                  style: context.appText.caption,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
