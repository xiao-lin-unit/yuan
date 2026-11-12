import 'package:intl/intl.dart';

import '../database/account/account_record.dart';

/// 全软件唯一的金额格式化入口（10.4「所有金额走统一的格式化…
/// 界面上禁止出现裸数字拼接」）。
///
/// 金额在**数据层永远是正数**（10.6 / 附录 D），显示层的「+/−」只由
/// [AccountDirection] 决定，业务页面不自己拼 `'¥' + value.toString()`。
abstract final class MoneyFormat {
  static final NumberFormat _two = NumberFormat('#,##0.00', 'zh_CN');
  static final NumberFormat _zero = NumberFormat('#,##0', 'zh_CN');
  static final NumberFormat _wan = NumberFormat('#,##0.0', 'zh_CN');

  /// 精确到分：¥8,320.00
  static String yuan(num value) => '¥${_two.format(value)}';

  /// 整数：¥8,320（看板、卡片右侧；原型用的就是这一档）
  static String yuan0(num value) => '¥${_zero.format(value)}';

  /// 大额「万元」切换（10.4）：≥ 10000 时显示 12.5 万。
  static String compact(num value) => value.abs() >= 10000
      ? '${_wan.format(value / 10000)} 万'
      : yuan0(value);

  /// 流水行：+¥8,000.00 / −¥186.00。
  /// 用真正的减号 U+2212 而非连字符，宽度与加号对齐。
  static String signed(AccountDirection direction, num value) =>
      '${direction == AccountDirection.inbound ? '+' : '−'}${yuan(value)}';

  /// 差额：+¥70 / −¥70（余额调整确认里用）。
  static String delta(num value) =>
      '${value >= 0 ? '+' : '−'}${yuan(value.abs())}';

  /// 空值兜底：额度没填时显示「—」而不是 0（6.7 同款规则，
  /// 避免用户误以为额度真的是 0）。
  static String orDash(num? value) => value == null ? '—' : yuan0(value);
}
