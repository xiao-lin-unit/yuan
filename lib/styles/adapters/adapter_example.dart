// 图表：整页没有 Color(0xFF...) 或裸 fontSize
// import 'package:table_calendar/table_calendar.dart';
//
// import 'app_calendar_style.dart';
// import 'app_chart_style.dart';
//
// final s = AppChartStyle.of(context);
// LineChart
// (
//   s.lineChart(
//   incomeSpots: weekly.income, expenseSpots: weekly.expense,
//   bottomLabels: const ['一','二','三','四','五','六','日'],
//   tooltipLabel: (v) => '¥ ${v.toInt()}', maxY: 3000,
// ));
//
// // 日历：业务只给语义标记，不给颜色
// final c = AppCalendarStyle.of(context);
// TableCalendar<CalendarMark>(
//   calendarStyle: c.calendarStyle,
//   headerStyle: c.headerStyle,
//   daysOfWeekStyle: c.daysOfWeekStyle,
//   calendarBuilders: CalendarBuilders<CalendarMark>(
//     markerBuilder: (_, day, marks) => c.markers(marks),
//   ),
//   eventLoader: (day) => dao.marksOn(day),
// );