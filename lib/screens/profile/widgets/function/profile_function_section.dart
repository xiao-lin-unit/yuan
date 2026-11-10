import 'dart:async';
import '../../../commons/icons/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../settings.dart';
import '../../../../theme.dart';
import '../../../commons/menu/menu_item.dart';
import '../../../commons/menu/menu_list.dart';
import '../../../commons/header/section_header.dart';

// ── 组件私有内容（只服务本分区）────────────────────────────────
const String _kSectionTitle = '功能';

/// ② 功能分区
class ProfileFunctionSection extends StatelessWidget {
  const ProfileFunctionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeController>();
    final dark = t.isDark(context);

    final List<MenuItemData> functions = [
      const MenuItemData(
        icon: AppIcons.knowledge,
        title: '财务小知识',
        subtitle: '边用边学',
        key: 'knowledge',
      ),
      const MenuItemData(
        icon: AppIcons.exportData,
        title: '导出数据',
        subtitle: '迁移数据到外部',
        key: 'export',
      ),
      const MenuItemData(
        icon: AppIcons.importData,
        title: '导入数据',
        subtitle: '从外部迁移数据',
        key: 'import',
      ),
      MenuItemData(
        icon: AppIcons.palette,
        title: '主题',
        subtitle: '当前：${ColorSetting.labelOf(t.seedKey)}（点击切换）',
        key: 'color',
        onTap: () => unawaited(context.read<ThemeController>().cycleSeed()),
      ),
      MenuItemData(
        icon: dark ? AppIcons.lightMode : AppIcons.darkMode,
        title: '外观',
        subtitle: dark ? '切换到日间' : '切换到夜间',
        key: 'appearance',
        onTap: () =>
            unawaited(context.read<ThemeController>().toggleMode(context)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: _kSectionTitle,
          trailing: Icon(AppIcons.function),
        ),
        MenuList(items: functions),
      ],
    );
  }
}
