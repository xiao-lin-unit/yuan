import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';
import 'styles/color_math.dart';
import 'styles/theme_tokens.dart';

/// 主题装配。
///
/// 优化点：
/// 1. 按 (seed, brightness, contrast) 缓存 ThemeData。旧版每次
///    ThemeController.notifyListeners 都重算 ColorScheme.fromSeed + 十几个
///    组件主题，切个颜色整棵树都在做无意义的重复计算。
/// 2. 主题色变化不只是换 seed：先做高对比度修正 → 生成语义色并 harmonize
///    到 seed → 用对比度函数选出可读的前景 → 挂成 ThemeExtension。
/// 3. 不再给 Switch/Radio/Slider 等传空的 ThemeData，把 M3 默认样式还回去。
/// 4. 去掉 materialTapTargetSize.shrinkWrap（它会关掉 48dp 最小点击区）。
class AppTheme {
  AppTheme._();

  static final Map<String, ThemeData> _cache = <String, ThemeData>{};
  static const int _cacheLimit = 48;

  static ThemeData light(Color seed, {double contrast = 0}) =>
      _get(seed, Brightness.light, contrast);

  static ThemeData dark(Color seed, {double contrast = 0}) =>
      _get(seed, Brightness.dark, contrast);

  static ThemeData _get(Color seed, Brightness brightness, double contrast) {
    final key =
        '${seed.toARGB32()}_${brightness.index}_${contrast.toStringAsFixed(2)}';
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.length >= _cacheLimit) _cache.clear();
    final built = _build(seed, brightness, contrast);
    _cache[key] = built;
    return built;
  }

  static ThemeData _build(Color seed, Brightness brightness, double contrast) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final cs = ColorMath.boostContrast(base, contrast);
    final tokens = AppThemeTokens.fromScheme(cs, seed);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      extensions: <ThemeExtension<dynamic>>[tokens],

      scaffoldBackgroundColor: cs.surface,
      canvasColor: cs.surface,
      fontFamily: defaultFont,
      fontFamilyFallback: defaultFontFallback,

      textTheme: ThemeSetting.textTheme.apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
        decorationColor: cs.onSurface,
      ),
      primaryTextTheme: ThemeSetting.textTheme.apply(
        bodyColor: cs.onPrimary,
        displayColor: cs.onPrimary,
      ),

      appBarTheme: ThemeSetting.appBarTheme(cs),
      navigationBarTheme: ThemeSetting.navigationBarTheme(cs),
      elevatedButtonTheme: ThemeSetting.elevatedButtonTheme(cs, tokens),
      textButtonTheme: ThemeSetting.textButtonTheme(cs),
      outlinedButtonTheme: ThemeSetting.outlinedButtonTheme(cs, tokens),
      inputDecorationTheme: ThemeSetting.inputDecorationTheme(cs, tokens),
      cardTheme: ThemeSetting.cardTheme(cs, tokens),
      listTileTheme: ThemeSetting.listTileTheme(cs, tokens),
      iconTheme: ThemeSetting.iconTheme(cs),
      dividerTheme: ThemeSetting.dividerTheme(tokens),
      bottomSheetTheme: ThemeSetting.bottomSheetTheme(cs, tokens),
      dialogTheme: ThemeSetting.dialogTheme(cs),
      snackBarTheme: ThemeSetting.snackBarTheme(cs),
      tooltipTheme: ThemeSetting.tooltipTheme(cs),

      // ── 第二批：圆角 / 间距 / 选中态统一接管 ──────────────────
      // 这些控件默认虽跟随 colorScheme，但圆角档位与内边距和项目里的
      // 卡片 / 列表 / 按钮对不上；现在全部从同一套令牌派生。
      chipTheme: ThemeSetting.chipTheme(cs, tokens),
      tabBarTheme: ThemeSetting.tabBarTheme(cs, tokens),
      floatingActionButtonTheme: ThemeSetting.floatingActionButtonTheme(cs),
      drawerTheme: ThemeSetting.drawerTheme(cs, tokens),
      datePickerTheme: ThemeSetting.datePickerTheme(cs, tokens),
      popupMenuTheme: ThemeSetting.popupMenuTheme(cs, tokens),
      segmentedButtonTheme: ThemeSetting.segmentedButtonTheme(cs, tokens),
      badgeTheme: ThemeSetting.badgeTheme(cs),
      progressIndicatorTheme: ThemeSetting.progressIndicatorTheme(cs),

      // Switch / Checkbox / Radio / Slider 故意不设置：
      // 传空 ThemeData 会把 M3 的内建样式覆盖掉。

      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: ThemeSetting.pageTransitionsTheme,
    );
  }

  static void clearCache() => _cache.clear();
}

class ThemeController extends ChangeNotifier {
  static const _kMode = 'theme_mode';
  static const _kSeed = 'theme_seed';
  static const _kSeedKey = 'theme_seed_key';
  static const _kContrast = 'theme_contrast';

  ThemeMode _mode = defaultMode;
  Color _seed = defaultColor;
  String _seedKey = 'blue';
  double _contrast = 0;

  ThemeMode get mode => _mode;
  Color get seed => _seed;
  String get seedKey => _seedKey;
  double get contrast => _contrast;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();

    final modeIndex = p.getInt(_kMode);
    _mode = (modeIndex != null &&
            modeIndex >= 0 &&
            modeIndex < ThemeMode.values.length)
        ? ThemeMode.values[modeIndex]
        : defaultMode;

    final seedValue = p.getInt(_kSeed);
    if (seedValue != null) _seed = Color(seedValue);
    _seedKey = p.getString(_kSeedKey) ?? ColorSetting.keyOf(_seed) ?? 'blue';
    _contrast = (p.getDouble(_kContrast) ?? 0).clamp(0.0, 2.0).toDouble();

    notifyListeners();
  }

  /// 判明暗要考虑 system 模式。旧版 `t.mode == ThemeMode.light`
  /// 把「跟随系统」永远当成暗色，外观按钮的图标和文案都是反的。
  bool isDark(BuildContext context) {
    switch (_mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  /// 与「保存资料」一致：先 await 写盘成功，再改内存并通知，
  /// 不做乐观更新，避免主题设置重启后回退。
  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMode, m.index);
    _mode = m;
    notifyListeners();
  }

  Future<void> setSeed(Color c, {String? key}) async {
    if (_seed.toARGB32() == c.toARGB32() && key == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSeed, c.toARGB32());
    final nextKey = key ?? ColorSetting.keyOf(c) ?? 'custom';
    await p.setString(_kSeedKey, nextKey);
    _seed = c;
    _seedKey = nextKey;
    notifyListeners();
  }

  /// 按预设 key 切换主题色，供「主题颜色」选择弹层使用。
  ///
  /// key → Color 的映射收在主题层，业务层只传用户选中的标识；
  /// 选中当前色时直接返回，避免无意义的 SharedPreferences 写入与
  /// 整棵树重建。setSeed 本身仍是「先写盘成功再改内存」的 await 链路。
  Future<void> setSeedKey(String key) async {
    final next = ColorSetting.themeColor(key);
    if (_seedKey == key && _seed.toARGB32() == next.toARGB32()) return;
    await setSeed(next, key: key);
  }

  /// 在预设色板里循环。
  ///
  /// 【我的】→ 主题 已改为打开 SelectSheetContent 单选确认，
  /// 这里保留作为兼容 API / 快捷调用，不再是菜单入口。
  Future<void> cycleSeed() async {
    final next = ColorSetting.nextKey(_seedKey);
    await setSeed(ColorSetting.themeColor(next), key: next);
  }

  Future<void> toggleMode(BuildContext context) =>
      setMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);

  /// 0 标准 / 1 中对比 / 2 高对比
  Future<void> setContrast(double level) async {
    final next = level.clamp(0.0, 2.0).toDouble();
    if (_contrast == next) return;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kContrast, next);
    _contrast = next;
    notifyListeners();
  }
}
