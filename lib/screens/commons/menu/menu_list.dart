import 'package:flutter/material.dart';

import '../../../styles/theme_tokens.dart';
import 'menu_item.dart';

/// 公共列表组件：渲染一组 MenuItem
class MenuList extends StatelessWidget {
  final List<MenuItemData> items;

  const MenuList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: items.map((i) => MenuItem(data: i)).toList(),
      ),
    );
  }
}
