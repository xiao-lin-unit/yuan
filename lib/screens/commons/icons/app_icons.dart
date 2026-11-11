import 'package:flutter/material.dart';

import 'fa_brands_icons.g.dart';

/// 全软件**唯一**的图标语义表。
///
/// 美术意图：旧版同时存在三套图标语言 —— FontAwesome regular/solid、
/// Material Icons、以及十几个 emoji。同一屏里线宽、圆角、视觉重量都对不上，
/// 切换明暗时 emoji 还不随主题取色。
///
/// 现在所有组件一律只引用 `AppIcons.xxx`，不直接写 `Icons.xxx` 或 emoji。
/// 主体统一用 Material outlined 图标（同一套线宽与几何），
/// FontAwesome 仅保留给真正的品牌 logo（github / apple）。
abstract final class AppIcons {
  AppIcons._();

  // ── 导航 ────────────────────────────────────────────────────
  static const IconData entry = Icons.edit_outlined;
  static const IconData ledger = Icons.receipt_long_outlined;
  static const IconData accounts = Icons.account_balance_wallet_outlined;
  static const IconData analysis = Icons.analytics_outlined;
  static const IconData profile = Icons.person_outline;
  static const IconData home = Icons.home_outlined;
  static const IconData user = Icons.person_outline;
  static const IconData desktop = Icons.desktop_windows_outlined;

  // ── 分区标题 ────────────────────────────────────────────────
  static const IconData about = Icons.info_outline;
  static const IconData function = Icons.tune;
  static const IconData manage = Icons.category_outlined;

  // ── 功能菜单 ────────────────────────────────────────────────
  static const IconData knowledge = Icons.menu_book_outlined;
  static const IconData exportData = Icons.upload_outlined;
  static const IconData importData = Icons.download_outlined;
  static const IconData palette = Icons.palette_outlined;
  static const IconData lightMode = Icons.light_mode_outlined;
  static const IconData darkMode = Icons.dark_mode_outlined;
  static const IconData category = Icons.label_outline;
  static const IconData trash = Icons.delete_outline;

  // ── 状态（loading / error / 重试，供三态骨架使用）─────────────
  static const IconData error = Icons.error_outline;
  static const IconData warning = Icons.warning_amber_outlined;
  static const IconData refresh = Icons.refresh;

  // ── 表单 / 交互 ─────────────────────────────────────────────
  static const IconData edit = Icons.settings_outlined;
  static const IconData clear = Icons.close;
  static const IconData check = Icons.check;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData add = Icons.add;
  static const IconData brokenImage = Icons.broken_image_outlined;
  static const IconData block = Icons.block;
  static const IconData calendarMonth = Icons.calendar_month_outlined;

  // ── Sheet：确认 / 选择 / 表单 ────────────────────────────────
  static const IconData radioChecked = Icons.check_circle;
  static const IconData radioUnchecked = Icons.radio_button_unchecked;
  static const IconData camera = Icons.photo_camera_outlined;
  static const IconData sort = Icons.sort_outlined;
  static const IconData public = Icons.public_outlined;
  static const IconData schedule = Icons.schedule_outlined;
  static const IconData queue = Icons.queue_music_outlined;
  static const IconData more = Icons.more_horiz;

  // ── Sheet：媒体控制 ──────────────────────────────────────────
  static const IconData repeat = Icons.repeat_outlined;
  static const IconData skipPrevious = Icons.skip_previous_outlined;
  static const IconData skipNext = Icons.skip_next_outlined;
  static const IconData play = Icons.play_arrow;
  static const IconData pause = Icons.pause;
  static const IconData volume = Icons.volume_up_outlined;

  // ── Sheet：支出分类 ──────────────────────────────────────────
  static const IconData restaurant = Icons.restaurant_outlined;
  static const IconData car = Icons.directions_car_outlined;
  static const IconData basket = Icons.shopping_basket_outlined;
  static const IconData housing = Icons.home_outlined;
  static const IconData utility = Icons.bolt_outlined;
  static const IconData apparel = Icons.checkroom_outlined;
  static const IconData entertainment = Icons.sports_esports_outlined;
  static const IconData medical = Icons.medical_services_outlined;
  static const IconData study = Icons.menu_book_outlined;
  static const IconData gift = Icons.card_giftcard_outlined;
  static const IconData finance = Icons.account_balance_outlined;
  static const IconData other = Icons.category_outlined;

  // ── 品牌（保留 FontAwesome，品牌 logo 不参与线宽统一）────────
  static const IconData github = FaBrandsIcons.icn_github;
  static const IconData apple = FaBrandsIcons.icn_apple;
}
