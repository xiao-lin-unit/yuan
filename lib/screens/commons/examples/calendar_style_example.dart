import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../styles/adapters/app_calendar_style.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../scaffold/app_page_scaffold.dart';

// ── 样例私有内容（只服务本页）──────────────────────────────────
const String _kPageTitle = '日历样式样例';
final DateTime _kFirstDay = DateTime.utc(2026, 1, 1);
final DateTime _kLastDay = DateTime.utc(2026, 12, 31);

/// 可直接放进「账本 / 分析」页的月视图样例。
///
/// 关键点：整页没有写任何颜色、圆角、字号；
/// 选中态、今天态、打点色、头部、星期栏全部由 [AppCalendarStyle]
/// 从当前 ColorScheme + AppThemeTokens 取。切换主题色或明暗时日历自动跟随。
///
/// 接入真实数据时，把 `_kEvents` 换成按日期聚合的账单列表：
/// ```dart
/// List<CalendarMark> loader(DateTime day) => dao
///     .billsOn(day)
///     .map((b) => b.isIncome ? CalendarMark.income : CalendarMark.expense)
///     .toList();
/// ```
///
/// 中文星期/月份需要 `flutter_localizations`（见说明文档），
/// 本样例不设 locale，直接用系统默认，保证加完依赖即可运行。
class CalendarStyleExample extends StatefulWidget {
  const CalendarStyleExample({super.key});

  @override
  State<CalendarStyleExample> createState() => _CalendarStyleExampleState();
}

class _CalendarStyleExampleState extends State<CalendarStyleExample> {
  DateTime _focusedDay = DateTime.utc(2026, 11, 10);
  DateTime? _selectedDay = DateTime.utc(2026, 11, 10);

  static final Map<DateTime, List<CalendarMark>> _kEvents =
      <DateTime, List<CalendarMark>>{
    DateTime.utc(2026, 11, 3): const <CalendarMark>[CalendarMark.expense],
    DateTime.utc(2026, 11, 5): const <CalendarMark>[
      CalendarMark.income,
      CalendarMark.expense,
    ],
    DateTime.utc(2026, 11, 10): const <CalendarMark>[
      CalendarMark.income,
      CalendarMark.income,
    ],
    DateTime.utc(2026, 11, 14): const <CalendarMark>[CalendarMark.expense],
    DateTime.utc(2026, 11, 21): const <CalendarMark>[
      CalendarMark.expense,
      CalendarMark.expense,
      CalendarMark.income,
    ],
    DateTime.utc(2026, 11, 28): const <CalendarMark>[CalendarMark.income],
  };

  List<CalendarMark> _loader(DateTime day) => _kEvents[
          DateTime.utc(day.year, day.month, day.day)] ??
      const <CalendarMark>[];

  @override
  Widget build(BuildContext context) {
    final s = AppCalendarStyle.of(context);
    final cs = Theme.of(context).colorScheme;

    return AppPageScaffold(
      title: _kPageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: AppDecorations.card(context),
            child: TableCalendar<CalendarMark>(
              firstDay: _kFirstDay,
              lastDay: _kLastDay,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              }),
              onPageChanged: (focused) => _focusedDay = focused,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              eventLoader: _loader,
              calendarStyle: s.calendarStyle,
              headerStyle: s.headerStyle,
              daysOfWeekStyle: s.daysOfWeekStyle,
              calendarBuilders: CalendarBuilders<CalendarMark>(
                markerBuilder: (context, day, marks) => s.markers(marks),
              ),
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: AppDecorations.item(context),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _selectedDay == null
                        ? '点选日期查看当日流水'
                        : '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}'
                            ' · 共 ${_loader(_selectedDay!).length} 笔',
                    style: context.appText.body,
                  ),
                ),
                Container(
                  width: AppComponentSize.calendarMarkerSize + 2,
                  height: AppComponentSize.calendarMarkerSize + 2,
                  decoration: BoxDecoration(
                    color: s.markerIncome,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text('收入', style: context.appText.caption),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: AppComponentSize.calendarMarkerSize + 2,
                  height: AppComponentSize.calendarMarkerSize + 2,
                  decoration: BoxDecoration(
                    color: s.markerExpense,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text('支出', style: context.appText.caption),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '打点颜色取自 AppThemeTokens 的语义色，换主题时自动重算。',
            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
