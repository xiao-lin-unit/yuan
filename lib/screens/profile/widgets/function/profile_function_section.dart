import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../settings.dart';
import '../../../../theme.dart';
import '../../../commons/menu/menu_item.dart';
import '../../../commons/menu/menu_list.dart';
import '../../../commons/header/section_header.dart';
import '../../../commons/icons/app_icons.dart';

/// ② 功能分区
class ProfileFunctionSection extends StatelessWidget {
  const ProfileFunctionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeController>();
    // ❌ 旧版用 t.mode == ThemeMode.light 判明暗，跟随系统时永远被当成暗色
    final dark = t.isDark(context);

    final List<MenuItemData> functions = [
      const MenuItemData(
        emoji: '📖',
        title: '财务小知识',
        subtitle: '边用边学',
        key: 'knowledge',
      ),
      const MenuItemData(
        emoji: '📤',
        title: '导出数据',
        subtitle: '迁移数据到外部',
        key: 'export',
      ),
      const MenuItemData(
        emoji: '📥',
        title: '导入数据',
        subtitle: '从外部迁移数据',
        key: 'import',
      ),
      MenuItemData(
        emoji: '🎨',
        title: '主题',
        subtitle: '当前：${ColorSetting.labelOf(t.seedKey)}（点击切换）',
        key: 'color',
        // ❌ 旧版 `defaultColor = ColorSetting.themeColor('pink')`
        // 直接改全局变量，和 SharedPreferences 里持久化的种子互相打架。
        onTap: () => unawaited(context.read<ThemeController>().cycleSeed()),
      ),
      MenuItemData(
        emoji: dark ? '☀️' : '🌃',
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
          title: '功能',
          trailing: Icon(AppIcons.manage),
        ),
        MenuList(items: functions),
      ],
    );
  }
}
