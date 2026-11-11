import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_buttons.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_data_display.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 原型 ①「展示 / 概览」：并排指标卡 + 趋势胶囊 + 极简柱图 +
/// 更新时间 + 底部渐变主操作。
///
/// 标题与「详情」动作由调用方**静态**传给
/// `AppSheetShell.show(header: SheetHeader(title: ..., trailing: SheetTextAction(...)))`，
/// 由壳固定在顶端；本组件只渲染会滚动的内容部分。
///
/// 组件只负责**布局与排版节奏**；颜色、字号、圆角、间距全部来自
/// `SheetPalette / SheetText / AppSheetSize / AppSpacing`。
/// 业务层只要把 DAO 聚合结果装进 [SheetMetric] 与 [SheetTrendPoint]。
class OverviewSheetContent extends StatelessWidget {
  const OverviewSheetContent({
    super.key,
    required this.metrics,
    required this.actionLabel,
    this.changeLabel,
    this.trend = const <SheetTrendPoint>[],
    this.updatedAt,
    this.onAction,
  });

  final List<SheetMetric> metrics;
  final String actionLabel;
  final String? changeLabel;
  final List<SheetTrendPoint> trend;
  final String? updatedAt;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SheetMetricRow(metrics: metrics),
        if (changeLabel != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: SheetChangePill(label: changeLabel!),
          ),
        ],
        if (trend.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          SheetTrendBars(points: trend),
        ],
        if (updatedAt != null) SheetCaption(text: updatedAt!),
        const SizedBox(height: AppSheetSize.sectionGap),
        SheetGradientButton(
          label: actionLabel,
          onPressed: onAction,
        ),
      ],
    );
  }
}
