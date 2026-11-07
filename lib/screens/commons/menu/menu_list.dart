import 'package:flutter/material.dart';
import 'menu_item.dart';
import '../styles/app_styles.dart';

/// 公共列表组件：渲染一组 MenuItem（对应 .menu-list）
class MenuList extends StatelessWidget {
  final List<MenuItemData> items;

  const MenuList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.pageHPadding),
      child: Column(
        children: items.map((i) => MenuItem(data: i)).toList(),
      ),
    );
  }
}
