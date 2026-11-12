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

  /// 静态数据表：只描述「有哪些项」，不持有回调。
  /// 点击行为统一在 build 里绑定，避免把 context / 路由写进 const 数据。
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
    // 【动态绑定，工作逻辑】点击的唯一入口是 MenuItemData.onTap：
    // menu_item.dart 里是 InkWell(onTap: data.onTap)，MenuList 只接收
    // items、不接收分区级回调。上层 ProfileScreen 传来的 onItemTap
    // 必须在这里逐条绑到数据项上，否则 onTap 为 null —— InkWell 连
    // 水波纹都不画，表现就是「点分类管理完全没反应」。
    //
    // 分步：① 遍历静态模板 _items；② 每条复制出带 onTap 的新项；
    //      ③ 点击时把模板项（含 key）回传上层，由上层统一拼路由；
    //      ④ 交给 MenuList 渲染。
    // 边界：上层没传 onItemTap 时 onTap 保持 null，列表纯展示、不报错。
    // 本文件不拼路由、不读 context，分区组件不认识「页面」这个概念。
    final List<MenuItemData> items = <MenuItemData>[
      for (final MenuItemData item in _items)
        MenuItemData(
          emoji: item.emoji,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          key: item.key,
          onTap: onItemTap == null ? null : () => onItemTap!(item),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: _kSectionTitle,
          trailing: Icon(AppIcons.manage),
        ),
        MenuList(items: items),
      ],
    );
  }
}
