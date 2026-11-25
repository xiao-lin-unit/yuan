/// 全库唯一的金额工具类（《账户表结构草案》全局约定 2 / 要-6b）。
///
/// 【为什么落库是字符串、计算是整数】
/// SQLite 的 REAL 是 IEEE754 双精度，0.1 + 0.2 != 0.3；DECIMAL(18,2)
/// 在 SQLite 里只是亲和性、不强制小数位。因此金额列一律 `TEXT` 存
/// 十进制字符串，parse 成「分」的 [int] 再加减，format 回字符串落库。
/// **内部禁用 double**，不引第三方 decimal 依赖。
///
/// 【桥接】模型层仍用 double（元）给 UI / Controller，只在 fromMap /
/// toMap 的边界做转换；[AccountEntryDao.append] 的累加链路全程走
/// [parse] / [format] 的整数分，所以「保存不丢精度」与「现有页面零改动」
/// 同时成立。利率、比例、数量不是金额，仍用 REAL 小数。
abstract final class Money {
  /// 落库格式：最多 2 位小数、允许负号、禁千分位 / 科学计数法 / 前导 +。
  static final RegExp _format = RegExp(r'^-?\d+(\.\d{1,2})?$');

  static const int scale = 100;

  static bool isValid(String? s) =>
      s != null && _format.hasMatch(s);

  /// 十进制字符串 → 分。非法格式抛 ArgumentError（不静默吞成 0）。
  static int parse(String? s) {
    if (s == null || s.isEmpty) return 0;
    if (!_format.hasMatch(s)) {
      throw ArgumentError('金额格式不合法: $s');
    }
    final bool neg = s.startsWith('-');
    final String body = neg ? s.substring(1) : s;
    final List<String> parts = body.split('.');
    final int yuan = int.parse(parts[0]);
    final int cents = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));
    final int v = yuan * scale + cents;
    return neg ? -v : v;
  }

  /// 分 → 十进制字符串（最多 2 位小数，负号保留）。
  static String format(int cents) {
    final bool neg = cents < 0;
    final int v = neg ? -cents : cents;
    final int yuan = v ~/ scale;
    final int frac = v % scale;
    final String body = frac == 0
        ? '$yuan'
        : (frac % 10 == 0
            ? '$yuan.${frac ~/ 10}'
            : '$yuan.${frac.toString().padLeft(2, '0')}');
    return neg ? '-$body' : body;
  }

  /// 字符串 → double 元，仅供模型字段展示用，不参与累加。
  static double yuan(String? s) => parse(s) / scale;

  /// double 元 → 字符串，供 toMap 落库（四舍五入到分）。
  static String fromYuan(num v) => format((v * scale).round());

  /// double 元 → 分，供 append 计算增量。
  static int centsOf(num v) => (v * scale).round();

  /// 分 → double 元，供 append 返回值 / 展示。
  static double toYuan(int cents) => cents / scale;

  /// 逐位整数相加的helper（保留显式入口，便于以后接定点乘除）。
  static int add(int a, int b) => a + b;
}
