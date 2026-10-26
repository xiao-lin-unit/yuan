import '../models/money.dart';

/// 金额展示工具。所有金额统一走这里，禁止在 UI 层拼接金额字符串。
class AmountFormatter {
  /// 带符号展示。支出/出账带负号，收入/入账带正号可选。
  static String withSign(Money money, {bool showPositiveSign = false, String symbol = '¥'}) {
    if (money.isZero) return '$symbol0.00';
    final sign = money.isNegative ? '-' : (showPositiveSign ? '+' : '');
    final abs = Money.fromCents(money.cents.abs());
    return '$sign${abs.format(symbol: symbol)}';
  }

  /// 纯数字，不带符号
  static String plain(Money money) => money.formatNumber();

  /// 适合作为卡片主数字展示（大字，不带正负号，负号单独由颜色表达）
  static String cardNumber(Money money, {bool showSign = false}) {
    return showSign ? withSign(money) : money.format();
  }
}
