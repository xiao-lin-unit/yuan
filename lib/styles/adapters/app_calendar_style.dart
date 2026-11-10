import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../screens/commons/icons/app_icons.dart';
import '../app_typography.dart';
import '../theme_tokens.dart';

// ── 适配层私有尺寸（只服务本文件）──────────────────────────────
const int _kMaxMarkers = 3;

/// 日历打点的语义类型：业务只描述「这是收入还是支出」，颜色由适配层决定。
enum CalendarMark { income, expense }

/// table_calendar 的**唯一**样式适配层。
///
/// table_calendar 不读 `ThemeData`，`CalendarStyle / HeaderStyle /
/// DaysOfWeekStyle` 里的颜色、圆角、间距都要显式给。若各页面各写一遍，
/// 换主题色或切暗色时日历就会掉队。
///
/// 本层把四件事收进来：
/// - 选中 / 今天 / 区间 / 禁用 / 外部日期的状态色，全部来自 `ColorScheme`；
/// - 打点色来自 `AppThemeTokens` 的收入 / 支出语义色；
/// - 圆角、描边、间距、图标尺寸全部来自全局令牌；
/// - 文字来自 `AppTypography`。
///
/// 业务页面只提供事件数据：
/// ```dart
/// final s = AppCalendarStyle.of(context);
/// TableCalendar<CalendarMark>(
///   calendarStyle: s.calendarStyle,
///   headerStyle: s.headerStyle,
///   daysOfWeekStyle: s.daysOfWeekStyle,
///   calendarBuilders: CalendarBuilders(
///     markerBuilder: (_, day, marks) => s.markers(marks),
///   ),
/// );
/// ```
class AppCalendarStyle {
  AppCalendarStyle(this.cs, this.tokens);

  final ColorScheme cs;
  final AppThemeTokens tokens;

  static AppCalendarStyle of(BuildContext context) => AppCalendarStyle(
        Theme.of(context).colorScheme,
        context.tokens,
      );

  // ── 语义色 ──────────────────────────────────────────────────
  Color get selected => cs.primary;
  Color get onSelected => cs.onPrimary;
  Color get today => cs.primaryContainer;
  Color get onToday => cs.onPrimaryContainer;
  Color get markerIncome => tokens.income;
  Color get markerExpense => tokens.expense;
  Color get divider => tokens.divider;
  Color get surface => tokens.card;
  Color get muted => cs.onSurfaceVariant;
  Color get disabled =>
      cs.onSurface.withValues(alpha: AppOpacity.disabled);

  BoxDecoration _circle(Color color) =>
      BoxDecoration(color: color, shape: BoxShape.circle);

  // ── 日期格 ──────────────────────────────────────────────────
  CalendarStyle get calendarStyle => CalendarStyle(
        isTodayHighlighted: true,
        outsideDaysVisible: false,
        defaultTextStyle:
            AppTypography.body.copyWith(color: cs.onSurface),
        weekendTextStyle:
            AppTypography.body.copyWith(color: cs.onSurface),
        selectedTextStyle:
            AppTypography.body.copyWith(color: onSelected, fontWeight: FontWeight.w600),
        todayTextStyle:
            AppTypography.body.copyWith(color: onToday, fontWeight: FontWeight.w600),
        disabledTextStyle: AppTypography.body.copyWith(color: disabled),
        outsideTextStyle: AppTypography.body.copyWith(color: disabled),
        holidayTextStyle: AppTypography.body.copyWith(color: muted),
        withinRangeTextStyle:
            AppTypography.body.copyWith(color: cs.onSurface),
        rangeStartTextStyle:
            AppTypography.body.copyWith(color: onSelected),
        rangeEndTextStyle:
            AppTypography.body.copyWith(color: onSelected),
        defaultDecoration: _circle(Colors.transparent),
        weekendDecoration: _circle(Colors.transparent),
        selectedDecoration: _circle(selected),
        todayDecoration: _circle(today),
        disabledDecoration: _circle(Colors.transparent),
        outsideDecoration: _circle(Colors.transparent),
        holidayDecoration: _circle(Colors.transparent),
        withinRangeDecoration: _circle(
          today.withValues(alpha: AppOpacity.disabledContainer),
        ),
        rangeStartDecoration: _circle(selected),
        rangeEndDecoration: _circle(selected),
        rowDecoration: const BoxDecoration(),
        tableBorder: TableBorder.all(
          color: divider.withValues(alpha: AppOpacity.outline),
          width: AppBorder.thin,
        ),
        tablePadding: const EdgeInsets.only(bottom: AppSpacing.md),
        cellMargin: const EdgeInsets.all(AppSpacing.xxs),
        cellPadding: EdgeInsets.zero,
        cellAlignment: Alignment.center,
        rangeHighlightColor: today,
        markerDecoration: _circle(markerIncome),
        markerSize: AppComponentSize.calendarMarkerSize,
        markerMargin:
            const EdgeInsets.symmetric(horizontal: AppSpacing.xxs / 4),
        markersMaxCount: _kMaxMarkers,
        canMarkersOverflow: false,
      );

  // ── 头部 ────────────────────────────────────────────────────
  HeaderStyle get headerStyle => HeaderStyle(
        titleCentered: true,
        formatButtonVisible: true,
        formatButtonShowsNext: false,
        leftChevronVisible: true,
        rightChevronVisible: true,
        titleTextStyle:
            AppTypography.sectionHeader.copyWith(color: cs.onSurface),
        formatButtonTextStyle:
            AppTypography.caption.copyWith(color: onToday),
        formatButtonDecoration: BoxDecoration(
          color: today,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        formatButtonPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        headerPadding:
            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        headerMargin: const EdgeInsets.only(bottom: AppSpacing.xs),
        leftChevronPadding: const EdgeInsets.all(AppSpacing.xs),
        rightChevronPadding: const EdgeInsets.all(AppSpacing.xs),
        leftChevronMargin: const EdgeInsets.all(AppSpacing.xxs),
        rightChevronMargin: const EdgeInsets.all(AppSpacing.xxs),
        leftChevronIcon: Icon(
          AppIcons.chevronLeft,
          size: AppIconSize.large,
          color: muted,
        ),
        rightChevronIcon: Icon(
          AppIcons.chevronRight,
          size: AppIconSize.large,
          color: muted,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.item),
        ),
      );

  // ── 星期栏 ──────────────────────────────────────────────────
  DaysOfWeekStyle get daysOfWeekStyle => DaysOfWeekStyle(
        weekdayStyle: AppTypography.caption.copyWith(color: muted),
        weekendStyle: AppTypography.caption.copyWith(
          color: muted.withValues(alpha: AppOpacity.hint),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: divider, width: AppBorder.thin),
          ),
        ),
      );

  /// 统一打点组件：收入 / 支出分别取语义色，最多显示 [_kMaxMarkers] 个。
  /// 业务只在 `eventLoader` 里给出 [CalendarMark] 列表，不碰颜色。
  Widget markers(List<CalendarMark> marks) {
    if (marks.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final mark in marks.take(_kMaxMarkers))
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs / 4,
            ),
            width: AppComponentSize.calendarMarkerSize,
            height: AppComponentSize.calendarMarkerSize,
            decoration: _circle(
              mark == CalendarMark.income ? markerIncome : markerExpense,
            ),
          ),
      ],
    );
  }
}
