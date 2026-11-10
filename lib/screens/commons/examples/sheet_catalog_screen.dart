import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/scaffold/app_page_scaffold.dart';
import 'package:yuan/screens/commons/sheet/app_sheet_shell.dart';
import 'package:yuan/screens/commons/sheet/contents/category_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/contents/confirm_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/contents/form_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/contents/operation_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/contents/overview_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/contents/select_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_inputs.dart';
import 'package:yuan/screens/commons/sheet/sheet_form_items.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/app_typography.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 预览页私有内容：与 6 张原型图一一对应的示例数据 ────────────
const String _kPageTitle = 'Sheet 组件目录';
const List<SheetTrendPoint> _kTrend = <SheetTrendPoint>[
  SheetTrendPoint(label: '周一', value: 0.55),
  SheetTrendPoint(label: '周二', value: 0.32),
  SheetTrendPoint(label: '周三', value: 0.58),
  SheetTrendPoint(label: '周四', value: 1.0, highlighted: true),
  SheetTrendPoint(label: '周五', value: 0.36),
  SheetTrendPoint(label: '周六', value: 0.72),
  SheetTrendPoint(label: '周日', value: 0.40),
];
const List<SheetCategory<String>> _kCategories = <SheetCategory<String>>[
  SheetCategory<String>(value: 'food', label: '餐饮', icon: AppIcons.restaurant),
  SheetCategory<String>(value: 'car', label: '交通', icon: AppIcons.car),
  SheetCategory<String>(value: 'market', label: '买菜', icon: AppIcons.basket),
  SheetCategory<String>(value: 'housing', label: '住房', icon: AppIcons.housing),
  SheetCategory<String>(value: 'utility', label: '水电', icon: AppIcons.utility),
  SheetCategory<String>(value: 'apparel', label: '服饰', icon: AppIcons.apparel),
  SheetCategory<String>(value: 'fun', label: '娱乐', icon: AppIcons.entertainment),
  SheetCategory<String>(value: 'medical', label: '医疗', icon: AppIcons.medical),
  SheetCategory<String>(value: 'study', label: '学习', icon: AppIcons.study),
  SheetCategory<String>(value: 'gift', label: '人情', icon: AppIcons.gift),
  SheetCategory<String>(value: 'finance', label: '金融', icon: AppIcons.finance),
  SheetCategory<String>(value: 'other', label: '其他', icon: AppIcons.other),
];

/// 6 张原型对应的可运行目录页。
///
/// 临时挂一条路由、或在 main.dart 里
/// `runApp(MaterialApp(home: SheetCatalogScreen()))` 即可逐张查看；
/// 然后在「主题」里循环 8 个预设 / 切明暗，观察 6 张 Sheet 是否同步变化。
/// 这一页只放**示例数据**，不含任何颜色 / 字号 / 圆角定义。
class SheetCatalogScreen extends StatelessWidget {
  const SheetCatalogScreen({super.key});

  void _show(BuildContext context, Widget child) {
    AppSheetShell.show<void>(context, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPageScaffold(
      title: _kPageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '六张原型各对应一种操作；切换主题色或明暗时，渐变、光晕、'
            '选中态与分类色会一起重算。',
            style: AppTypography.sheetSubtitle.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          _CatalogEntry(
            index: '01',
            title: '展示 / 概览',
            subtitle: '指标卡 · 趋势柱 · 渐变主操作',
            icon: AppIcons.analysis,
            onTap: () => _show(
              context,
              const OverviewSheetContent(
                title: '本周概览',
                detailLabel: '详情',
                metrics: <SheetMetric>[
                  SheetMetric(label: '步数', value: '42,860'),
                  SheetMetric(label: '活跃时长', value: '6.2', unit: '小时'),
                  SheetMetric(label: '平均心率', value: '72'),
                ],
                changeLabel: '较上周 +12%',
                trend: _kTrend,
                updatedAt: '数据更新于今日 09:30',
                actionLabel: '查看完整报告',
              ),
            ),
          ),
          _CatalogEntry(
            index: '02',
            title: '危险确认',
            subtitle: '语义图标徽章 · 双按钮 · 不可撤销提示',
            icon: AppIcons.trash,
            onTap: () => _show(
              context,
              ConfirmSheetContent(
                title: '删除这条记录？',
                description: '删除后将无法恢复，相关同步数据也会一并移除。',
                secondaryLabel: '再想想',
                primaryLabel: '确认删除',
                footnote: '此操作不可撤销',
                icon: AppIcons.trash,
              ),
            ),
          ),
          _CatalogEntry(
            index: '03',
            title: '表单编辑',
            subtitle: '声明式 items：头像 · 单行 / 多行 · 标签 · 开关 · 说明',
            icon: AppIcons.edit,
            onTap: () => _show(
              context,
              FormSheetContent(
                title: '编辑资料',
                submitLabel: '保存修改',
                onSubmit: (values) async {
                  // 使用方只按 key 取值，不再持有 controller / 临时变量
                  debugPrint('表单值：${values.toMap()}');
                },
                items: <SheetFormItem>[
                  SheetFormAvatarItem(
                    key: 'avatar',
                    // 未改动哨兵；真实业务里传 imageUndefined
                    initialValue: const Object(),
                    builder: (context, onChanged, size) =>
                        SheetFormAvatarPlaceholder(size: size),
                  ),
                  const SheetFormSingleLineTextItem(
                    key: 'name',
                    label: '昵称',
                    initialValue: '林小满',
                    hint: '怎么称呼你？',
                    maxLength: 12,
                    showClearButton: true,
                    validator: _validateName,
                  ),
                  const SheetFormMultiLineTextItem(
                    key: 'bio',
                    label: '个人简介',
                    initialValue: '热爱生活，记录日常。\n分享镜头里的光。',
                    hint: '写点什么介绍自己',
                    maxLength: 60,
                    maxLines: 3,
                    minLines: 2,
                    showClearButton: true,
                    showCounter: true,
                  ),
                  const SheetFormTagsItem(
                    key: 'tags',
                    label: '标签',
                    options: <SheetTag<Object>>[
                      SheetTag<Object>(value: 'photo', label: '摄影'),
                      SheetTag<Object>(value: 'hike', label: '徒步'),
                      SheetTag<Object>(value: 'coffee', label: '咖啡'),
                    ],
                    initialSelected: <Object>{'photo'},
                  ),
                  const SheetFormToggleItem(
                    key: 'public',
                    label: '设为公开',
                    initialValue: true,
                    dividerAbove: true,
                  ),
                  const SheetFormNoteItem(
                    key: 'note',
                    text: '资料仅保存在本设备，不会上传云端。',
                  ),
                ],
              ),
            ),
          ),
          _CatalogEntry(
            index: '04',
            title: '操作 / 媒体控制',
            subtitle: '封面 · 进度条 · 五个控制 · 底栏动作',
            icon: AppIcons.queue,
            onTap: () => _show(
              context,
              const OperationSheetContent(
                title: '晚风经过',
                subtitle: '陈屿 · 城市漫游',
                progress: 0.36,
                elapsed: '01:24',
                total: '03:48',
                isPlaying: true,
                footerLeft: SheetFooterAction(label: '播放列表'),
                footerRight: SheetFooterAction(label: '定时关闭'),
              ),
            ),
          ),
          _CatalogEntry(
            index: '05',
            title: '单选列表',
            subtitle: '标题 + 说明 · 选项容器 · 应用',
            icon: AppIcons.sort,
            onTap: () => _show(
              context,
              SelectSheetContent<String>(
                title: '排序方式',
                subtitle: '选择内容的排列顺序',
                actionLabel: '应用',
                initialValue: 'latest',
                options: <SheetOption<String>>[
                  SheetOption<String>(
                    value: 'recommend',
                    label: '推荐优先',
                    icon: AppIcons.function,
                  ),
                  SheetOption<String>(
                    value: 'latest',
                    label: '最新发布',
                    icon: AppIcons.schedule,
                  ),
                  SheetOption<String>(
                    value: 'price',
                    label: '价格从低到高',
                    icon: AppIcons.finance,
                  ),
                  SheetOption<String>(
                    value: 'nearby',
                    label: '离我最近',
                    icon: AppIcons.home,
                  ),
                ],
              ),
            ),
          ),
          _CatalogEntry(
            index: '06',
            title: '分类网格',
            subtitle: '最近使用 · 4 列彩色格 · 点击即选',
            icon: AppIcons.category,
            onTap: () => _show(
              context,
              CategorySheetContent<String>(
                title: '选择支出分类',
                subtitle: '选择后自动归入该分类',
                recent: <SheetCategory<String>>[
                  _kCategories[0],
                  _kCategories[1],
                  _kCategories[2],
                ],
                categories: _kCategories,
                initialSelected: 'food',
                hint: '点击分类即可完成选择',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 声明式校验：使用方只给规则，错误文案的样式由公共组件统一渲染。
String? _validateName(String value) =>
    value.trim().isEmpty ? '昵称不能为空' : null;

class _CatalogEntry extends StatelessWidget {
  const _CatalogEntry({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String index;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: AppDecorations.item(context),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: context.appText.menuTitle),
          subtitle: Text(subtitle, style: context.appText.menuSubtitle),
          trailing: Text(
            index,
            style: SheetText.of(context).caption,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
