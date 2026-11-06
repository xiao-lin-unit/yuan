import 'package:flutter/material.dart';
import '../../../commons/menu_item.dart';
import '../../../commons/menu_list.dart';
import '../../../commons/section_header.dart';

/// ② 功能分区
class ProfileFunctionSection extends StatelessWidget {
  final void Function(MenuItemData item)? onItemTap;

  const ProfileFunctionSection({super.key, this.onItemTap});

  static const List<MenuItemData> _items = [
    MenuItemData(emoji: '📖', title: '财务小知识', subtitle: '边用边学', key: 'knowledge'),
    MenuItemData(emoji: '🔔', title: '提醒设置', subtitle: '还款日 / 到期提醒', key: 'reminder'),
    MenuItemData(emoji: '🔒', title: '应用锁', subtitle: '打开软件要密码', key: 'lock'),
    MenuItemData(emoji: '📤', title: '导出数据', subtitle: 'CSV / Excel', key: 'export'),
    MenuItemData(emoji: '📥', title: '导入数据', subtitle: '从其他软件迁移', key: 'import'),
    MenuItemData(emoji: '🎨', title: '外观', subtitle: '深色 / 浅色', key: 'appearance'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = onItemTap == null
        ? _items
        : _items
            .map((i) => MenuItemData(
                  emoji: i.emoji,
                  title: i.title,
                  subtitle: i.subtitle,
                  key: i.key,
                  onTap: () => onItemTap!(i),
                ))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '功能'),
        MenuList(items: items),
      ],
    );
  }
}
