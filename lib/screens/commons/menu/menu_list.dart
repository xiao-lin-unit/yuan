import 'package:flutter/material.dart';

import '../../../styles/theme_tokens.dart';
import 'menu_item.dart';

/// 公共列表组件：渲染一组 MenuItem。
///
/// 把列表序号传给 [MenuItem]，供鲜明档徽章铺 12 色相环使用。
/// 序号是数据位置而非样式值，业务层仍不用关心颜色。
class MenuList extends StatelessWidget {
  final List<MenuItemData> items;

  const MenuList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: items
            .asMap()
            .entries
            .map((e) => MenuItem(data: e.value, index: e.key))
            .toList(),
      ),
    );
  }
}
