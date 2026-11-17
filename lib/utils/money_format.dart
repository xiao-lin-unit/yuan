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

  /// 全软件唯一的流水金额符号口径，视觉锚点是**剩余可用金额**：
  ///   入账 → 可动用的钱变多 → +¥8,000.00
  ///   出账 → 可动用的钱变少 → −¥186.00
  /// 用真正的减号 U+2212 而非连字符，宽度与加号对齐。
  ///
  /// 【信用卡为什么不再用「已用额度」口径】已用额度在消费时 +、还款时 −，
  /// 与「钱变少 / 变多」的直觉正好相反；用户关心的应是「还剩多少能用」。
  /// 于是信用卡消费 200 元出账显示 −¥200.00、还款 200 元入账显示
  /// +¥200.00，和储蓄类完全同一条规则：不按卡类型乘系数、不需要第二个
  /// 方法、公共列表组件也不必新增任何参数。
  ///
  /// 【两套口径别混】详情页顶部三格是「已用额度构成」的统计，用 [yuan0]
  /// 输出不带符号的金额；本方法只管**逐笔流水行**的符号。两者互不复用。
  static String signed(AccountDirection direction, num value) =>
      '${direction == AccountDirection.inbound ? '+' : '−'}${yuan(value)}';

  /// 差额：+¥70 / −¥70（余额调整确认里用）。
  static String delta(num value) =>
      '${value >= 0 ? '+' : '−'}${yuan(value.abs())}';

  /// 空值兜底：额度没填时显示「—」而不是 0（6.7 同款规则，
  /// 避免用户误以为额度真的是 0）。
  static String orDash(num? value) => value == null ? '—' : yuan0(value);
}
