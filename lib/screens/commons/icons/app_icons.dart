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

  // ── Sheet：支出分类（保留，供既有 Sheet 预览使用）──────────────
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

  // ── 收支分类（分类管理页 / 记账选择器）─────────────────────────
  //
  // 原型用 emoji，本项目按「全软件唯一矢量图标语言」换成 Material
  // outlined 图标：线宽统一、随主题色与明暗取色、无暗色变体负担。
  // 数据库只存下面这些**语义 key**，不存字体码点；换图标体系时
  // 只改这张表，不需要迁移数据。语义相近的分类允许复用同一图标，
  // 这是矢量图标语言相对「一分类一 emoji」的正常取舍。
  static const IconData dragHandle = Icons.drag_handle;

  static const IconData meal = Icons.restaurant_outlined;
  static const IconData drink = Icons.local_cafe_outlined;
  static const IconData fruit = Icons.apple_outlined;
  static const IconData takeout = Icons.takeout_dining_outlined;
  static const IconData grocery = Icons.shopping_basket_outlined;
  static const IconData property = Icons.apartment_outlined;
  static const IconData rent = Icons.home_outlined;
  static const IconData phone = Icons.smartphone_outlined;
  static const IconData daily = Icons.cleaning_services_outlined;
  static const IconData transport = Icons.directions_bus_outlined;
  static const IconData fuel = Icons.local_gas_station_outlined;
  static const IconData taxi = Icons.local_taxi_outlined;
  static const IconData beauty = Icons.face_retouching_natural_outlined;
  static const IconData books = Icons.import_contacts_outlined;
  static const IconData child = Icons.toys_outlined;
  static const IconData elders = Icons.family_restroom_outlined;
  static const IconData pet = Icons.pets_outlined;
  static const IconData travel = Icons.flight_takeoff_outlined;
  static const IconData tobacco = Icons.smoking_rooms_outlined;
  static const IconData fitness = Icons.fitness_center_outlined;
  static const IconData homeImprovement = Icons.handyman_outlined;
  static const IconData digital = Icons.devices_outlined;
  static const IconData insurance = Icons.shield_outlined;
  static const IconData tax = Icons.receipt_outlined;
  static const IconData salary = Icons.payments_outlined;
  static const IconData bonus = Icons.emoji_events_outlined;
  static const IconData sideJob = Icons.laptop_outlined;
  static const IconData investment = Icons.trending_up_outlined;
  static const IconData refund = Icons.undo_outlined;
  static const IconData reimbursement = Icons.receipt_long_outlined;
  static const IconData giftMoney = Icons.redeem_outlined;
  static const IconData secondHand = Icons.swap_horiz_outlined;
  static const IconData lottery = Icons.confirmation_number_outlined;

  /// 语义 key → IconData。 CategoryDb 的 41 条预设分类全部命中这里；
  /// 自定义分类的图标也从这张表里选，业务层不写 Icons.xxx。
  static const Map<String, IconData> categoryIcons = <String, IconData>{
    'meal': meal,
    'drink': drink,
    'fruit': fruit,
    'takeout': takeout,
    'grocery': grocery,
    'utility': utility,
    'property': property,
    'rent': rent,
    'phone': phone,
    'medical': medical,
    'daily': daily,
    'transport': transport,
    'fuel': fuel,
    'taxi': taxi,
    'apparel': apparel,
    'beauty': beauty,
    'study': study,
    'books': books,
    'child': child,
    'elders': elders,
    'pet': pet,
    'gift': gift,
    'entertainment': entertainment,
    'travel': travel,
    'tobacco': tobacco,
    'fitness': fitness,
    'homeImprovement': homeImprovement,
    'digital': digital,
    'insurance': insurance,
    'tax': tax,
    'other': other,
    'salary': salary,
    'bonus': bonus,
    'sideJob': sideJob,
    'investment': investment,
    'refund': refund,
    'reimbursement': reimbursement,
    'giftMoney': giftMoney,
    'secondHand': secondHand,
    'lottery': lottery,
  };

  /// 编辑器图标网格的可选 key（稳定顺序 = map 的声明顺序）。
  static List<String> get categoryIconKeys =>
      categoryIcons.keys.toList(growable: false);

  /// 坏数据兜底：未识别的 key 一律回退到「其他」，不让渲染崩。
  static IconData categoryIcon(String key) => categoryIcons[key] ?? other;

  // ── 品牌（保留 FontAwesome，品牌 logo 不参与线宽统一）────────
  // ── 账户（账户首页 / 明细页 / 账户操作）───────────────────────────
  // 同样只存语义，不存 emoji / 颜色；原型里的 💬💵🏦💳🏥🏠 全部换成
  // 同一套 Material outlined 线宽，切主题与明暗自动取色。
  static const IconData accountBank = Icons.account_balance_outlined;
  static const IconData accountCash = Icons.money_outlined;
  static const IconData accountWechat = Icons.chat_bubble_outline;
  static const IconData accountAlipay = Icons.wallet_outlined;
  static const IconData accountCreditCard = Icons.credit_card_outlined;
  static const IconData accountSocial = Icons.health_and_safety_outlined;
  static const IconData accountHousing = Icons.home_work_outlined;
  static const IconData accountGiftCard = Icons.redeem_outlined;
  static const IconData accountFrozen = Icons.ac_unit_outlined;
  static const IconData accountOther = Icons.savings_outlined;

  static const IconData transfer = Icons.compare_arrows_outlined;
  static const IconData balanceAdjust = Icons.balance_outlined;
  static const IconData archive = Icons.archive_outlined;
  static const IconData unarchive = Icons.unarchive_outlined;
  static const IconData repay = Icons.payments_outlined;
  static const IconData creditLimit = Icons.credit_score_outlined;
  static const IconData locked = Icons.lock_outline;
  static const IconData binding = Icons.link_outlined;
  static const IconData accountNote = Icons.sticky_note_2_outlined;
  static const IconData accountAdd = Icons.add_card_outlined;

  static const IconData github = FaBrandsIcons.icn_github;
  static const IconData apple = FaBrandsIcons.icn_apple;
}
