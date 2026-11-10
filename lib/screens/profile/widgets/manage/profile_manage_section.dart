import 'package:flutter/material.dart';

import '../../../commons/menu/menu_item.dart';
import '../../../commons/menu/menu_list.dart';
import '../../../commons/header/section_header.dart';
import '../../../commons/icons/app_icons.dart';

// ── 组件私有内容（只服务本分区）────────────────────────────────
const String _kSectionTitle = '管理';

/// ③ 管理分区
class ProfileManageSection extends StatelessWidget {
  final void Function(MenuItemData item)? onItemTap;

  const ProfileManageSection({super.key, this.onItemTap});

  static const List<MenuItemData> _items = [
    MenuItemData(
      icon: AppIcons.category,
      title: '分类管理',
      subtitle: '自定义收支分类',
      key: 'category',
    ),
    MenuItemData(
      icon: AppIcons.trash,
      title: '回收站',
      subtitle: '误删可恢复',
      key: 'trash',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: _kSectionTitle,
          trailing: Icon(AppIcons.manage),
        ),
        MenuList(items: _items),
      ],
    );
  }
}
