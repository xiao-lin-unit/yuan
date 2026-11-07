import 'package:yuan/screens/commons/icons/fa_regular_icons.g.dart';

import 'fa_solid_icons.g.dart';
import 'fa_brands_icons.g.dart';

// 全局统一
abstract final class AppIcons {
  AppIcons._();

  // ===== 导航 =====
  static const home = FaRegularIcons.icn_home;
  static const user = FaRegularIcons.icn_user;
  static const desktop = FaSolidIcons.icn_desktop;
  static const about = FaSolidIcons.icn_circle_info;
  static const function = FaSolidIcons.icn_puzzle_piece;
  static const manage = FaSolidIcons.icn_user_gear;

  // ===== 品牌 =====
  static const github = FaBrandsIcons.icn_github;
  static const apple = FaBrandsIcons.icn_apple;
}