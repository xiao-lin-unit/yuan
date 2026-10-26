/// 日期相关工具
class DateUtils {
  static String ymd(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  static String ym(DateTime d) => '${d.year}-${_pad(d.month)}';

  static String md(DateTime d) => '${_pad(d.month)}-${_pad(d.day)}';

  static String weekdayCn(DateTime d) {
    const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[d.weekday - 1];
  }

  /// 今天、昨天、或具体日期
  static String smartDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == -1) return '明天';
    return '${d.month}月${d.day}日';
  }

  /// 本月第一天
  static DateTime monthStart([DateTime? d]) {
    final x = d ?? DateTime.now();
    return DateTime(x.year, x.month, 1);
  }

  /// 本月最后一天
  static DateTime monthEnd([DateTime? d]) {
    final x = d ?? DateTime.now();
    return DateTime(x.year, x.month + 1, 0);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
