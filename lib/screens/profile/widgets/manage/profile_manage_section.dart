import 'package:flutter/material.dart';
import '../../../commons/menu_item.dart';
import '../../../commons/menu_list.dart';
import '../../../commons/section_header.dart';

/// ③ 管理分区
class ProfileManageSection extends StatelessWidget {
  final void Function(MenuItemData item)? onItemTap;

  const ProfileManageSection({super.key, this.onItemTap});

  static const List<MenuItemData> _items = [
    MenuItemData(emoji: '📂', title: '分类管理', subtitle: '自定义收支分类', key: 'category'),
    MenuItemData(emoji: '🗑️', title: '回收站', subtitle: '误删可恢复', key: 'trash'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '管理'),
        MenuList(items: _items),
      ],
    );
  }
}
