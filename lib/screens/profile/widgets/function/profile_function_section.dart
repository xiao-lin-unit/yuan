import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../settings.dart';
import '../../../../theme.dart';
import '../../../commons/header/section_header.dart';
import '../../../commons/icons/app_icons.dart';
import '../../../commons/menu/menu_item.dart';
import '../../../commons/menu/menu_list.dart';
import '../../../commons/sheet/app_sheet_shell.dart';
import '../../../commons/sheet/contents/select_sheet_content.dart';
import '../../../commons/sheet/sheet_models.dart';

// ── 组件私有内容（只服务本分区）────────────────────────────────
const String _kSectionTitle = '功能';
const String _kThemeSheetTitle = '主题颜色';
const String _kThemeSheetSubtitle = '选择后应用到整个软件';
const String _kThemeApplyLabel = '应用';

/// ② 功能分区
class ProfileFunctionSection extends StatelessWidget {
  const ProfileFunctionSection({super.key});

  /// 打开主题选择弹层。
  ///
  /// 以前这里是 `cycleSeed()`：点一下盲切到下一个颜色，用户不知道
  /// 一共有几种、当前是哪种、想回到某个色要点几下。
  /// 现在改成「单选列表 + 确认应用」，与排序方式等其它选择操作同一套
  /// 交互与视觉（`SelectSheetContent`）。
  ///
  /// 关键：主题切换是「先 await 写 SharedPreferences，再改内存并通知」
  /// 的异步链路，必须走 [SelectSheetContent.onApplyAsync]，
  /// 由组件等待成功后再关闭弹层；写入失败会提示且弹窗保持打开。
  Future<void> _openThemeSheet(BuildContext context) async {
    // 在弹出路由之前取 controller。sheet 是独立路由，用 sheet 自己的
    // context 读 Provider 容易拿到错误的构建上下文。
    final controller = context.read<ThemeController>();

    await AppSheetShell.show<String>(
      context,
      child: SelectSheetContent<String>(
        title: _kThemeSheetTitle,
        subtitle: _kThemeSheetSubtitle,
        actionLabel: _kThemeApplyLabel,
        action: false,
        // 当前颜色默认高亮，用户不改直接「应用」不会产生无意义写盘
        initialValue: controller.seedKey,
        options: <SheetOption<String>>[
          for (final key in ColorSetting.order)
            SheetOption<String>(
              value: key,
              label: ColorSetting.labelOf(key),
              // 只给「这个选项代表什么颜色」这一份数据，
              // 色点的尺寸/描边/选中态由通用零件按全局令牌渲染
              swatch: ColorSetting.themeColor(key),
            ),
        ],
        // onApplyAsync: (String key) => controller.setSeedKey(key),
        onChanged: (String? key) => controller.setSeedKey(key!),
      ),
    );
  }

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
        subtitle: '当前：${ColorSetting.labelOf(t.seedKey)}（点击选择）',
        key: 'color',
        onTap: () => unawaited(_openThemeSheet(context)),
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
