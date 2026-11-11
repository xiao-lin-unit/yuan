import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 全软件**唯一**的本地化配置。
///
/// ── 为什么需要 ─────────────────────────────────────────────────
/// 之前 `MaterialApp.router` 没有 `localizationsDelegates` /
/// `supportedLocales`，于是：
///   · 已配好 DatePickerTheme 的日期选择器、table_calendar 的月份/星期、
///     Material 内置文案（复制/粘贴/确定/取消）全部退回英文 en_US；
///   · `Localizations` 树里没有 Material/Cupertino 委托，某些组件在
///     release 下会直接抛 "No MaterialLocalizations found"。
///
/// ── 本轮做什么、不做什么（边界写清楚）─────────────────────────
/// 做：把框架级委托挂上，让**内置控件**与 intl 日期格式跟随语言；
///     指定支持语言列表，让 MaterialApp 的 Directionality 有明确依据。
/// 不做：不引入 .arb / gen_l10n / AppLocalizations 生成体系。
///     当前五个页面和 Sheet 的业务文案仍是硬编码中文字符串，
///     要真正多语言是另一项独立工程，不在本轮范围。
///
/// ── Directionality 不用手动包 ──────────────────────────────────
/// 之前分析里我说过「RTL 下 Directionality 缺位」，那句不准确：
/// MaterialApp / WidgetsApp 内部本来就根据当前 locale 建立 Directionality，
/// 不需要在 AppRoot 里再包一层。本轮 [supportedLocales] 只含 zh_CN 与
/// en（都是 LTR），若以后加阿拉伯语/希伯来语，需要专门检查 Row 的
/// start/end、Drawer 方向、五个 tab 顺序是否镜像 —— 那是另一个任务。
///
/// ── 静态优先 ───────────────────────────────────────────────────
/// 这个文件全是 const 常量：无状态、无回调、无异步、无运行时探测。
/// 语言顺序就是回退顺序：列表第一个是默认语言（系统语言不在列表里时用它）。
abstract final class AppLocale {
  AppLocale._();

  /// 支持的语言。zh_CN 放第一位 = 默认语言。
  /// Locale('en') 只写语言码，可匹配 en_US / en_GB 等所有英语变体。
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh', 'CN'),
    Locale('en'),
  ];

  /// 默认语言，同时用于 intl 的日期符号数据初始化。
  static const Locale defaultLocale = Locale('zh', 'CN');

  /// intl 的 locale 名（下划线格式，与 [defaultLocale] 对应）。
  /// `table_calendar` 内部用 `DateFormat.yMMMM(locale)`，中文月份/星期
  /// 必须先 `initializeDateFormatting('zh_CN', null)`，否则仍显示英文。
  static const String dateFormattingLocale = 'zh_CN';

  /// Material / Widgets / Cupertino 三套框架委托。
  /// 顺序固定，三个都是 const 单例，不随主题或路由变化。
  static const List<LocalizationsDelegate<dynamic>> delegates =
      <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
