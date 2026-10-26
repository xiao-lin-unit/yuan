/// 金额值对象。
/// 内部以"分"为单位的整数存储，杜绝 double 累加误差。
/// 等价于文档中的 DECIMAL(12,2)。
class Money {
  final int _cents;

  const Money._(this._cents);

  /// 从元（如 12.34）构造
  factory Money.fromDouble(double yuan) {
    return Money._((yuan * 100).round());
  }

  /// 从分构造
  factory Money.fromCents(int cents) => Money._(cents);

  /// 零
  static const zero = Money._(0);

  int get cents => _cents;
  double get yuan => _cents / 100.0;

  Money operator +(Money other) => Money._(_cents + other._cents);
  Money operator -(Money other) => Money._(_cents - other._cents);
  Money operator -() => Money._(-_cents);
  Money operator *(int n) => Money._(_cents * n);

  bool operator <(Money other) => _cents < other._cents;
  bool operator <=(Money other) => _cents <= other._cents;
  bool operator >(Money other) => _cents > other._cents;
  bool operator >=(Money other) => _cents >= other._cents;

  bool get isNegative => _cents < 0;
  bool get isZero => _cents == 0;

  /// 格式化为带千分位、两位小数的字符串，如 1,234.56
  String format({String symbol = '¥'}) {
    final sign = _cents < 0 ? '-' : '';
    final abs = _cents.abs();
    final integer = (abs ~/ 100).toString();
    final decimal = (abs % 100).toString().padLeft(2, '0');
    final withSeparator = _addSeparator(integer);
    return '$sign$symbol$withSeparator.$decimal';
  }

  /// 仅数字部分，不带符号
  String formatNumber() {
    final abs = _cents.abs();
    final integer = (abs ~/ 100).toString();
    final decimal = (abs % 100).toString().padLeft(2, '0');
    return '${_addSeparator(integer)}.$decimal';
  }

  String _addSeparator(String s) {
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write(',');
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other._cents == _cents;

  @override
  int get hashCode => _cents.hashCode;

  @override
  String toString() => format();
}
