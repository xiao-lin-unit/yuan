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
  // final void Function(MenuItemData item)? onItemTap;

  const ProfileFunctionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeController>();
    // final c = Theme.of(context).colorScheme;
    bool isLight = t.mode == ThemeMode.light;

    final List<MenuItemData> functions = [
      MenuItemData(
        emoji: '📖',
        title: '财务小知识',
        subtitle: '边用边学',
        key: 'knowledge',
      ),
      // MenuItemData(
      //   emoji: '🔔',
      //   title: '提醒设置',
      //   subtitle: '还款日 / 到期提醒',
      //   key: 'reminder',
      // ),
      // MenuItemData(emoji: '🔒', title: '应用锁', subtitle: '打开软件要密码', key: 'lock'),
      MenuItemData(
        emoji: '📤',
        title: '导出数据',
        subtitle: '迁移数据到外部',
        key: 'export',
      ),
      MenuItemData(
        emoji: '📥',
        title: '导入数据',
        subtitle: '从外部迁移数据',
        key: 'import',
      ),
      MenuItemData(
        emoji: '🎨',
        title: '主题',
        subtitle: '选择喜欢的颜色',
        key: 'color',
        onTap: () => {
          context.read<ThemeController>().setSeed(
            defaultColor = ColorSetting.themeColor('pink')
          ),
        },
      ),
      MenuItemData(
        emoji: isLight ? '🌃' : '☀️',
        title: '外观',
        subtitle: isLight ? '夜间模式' : '日间模式',
        key: 'appearance',
        onTap: () => {
          context.read<ThemeController>().setMode(
            defaultMode = isLight ? ThemeMode.dark : ThemeMode.light,
          ),
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '功能', trailing: Icon(
          AppIcons.manage,
        )),
        MenuList(items: functions),
      ],
    );
  }
}
