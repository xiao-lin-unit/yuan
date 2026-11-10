import 'package:flutter/material.dart';

import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../icons/app_icons.dart';
import '../scaffold/app_page_scaffold.dart';

// ── 预览页私有内容（只服务本页）────────────────────────────────
const String _kPageTitle = '组件样式预览';

enum _Range { day, week, month }

/// 用于验证第一批组件主题是否真的生效的可运行页面。
///
/// 这一页**不写任何颜色、圆角、字号、间距数值**：
/// Chip / TabBar / SegmentedButton / PopupMenu / Badge /
/// LinearProgressIndicator / DatePicker 的外观全部来自
/// `ThemeData` 里刚装配的 9 个组件主题。
///
/// 用法：临时把路由里某个 tab 指向本页，或在 main.dart 里
/// `runApp(MaterialApp(home: MaterialComponentsPreview()))`，
/// 然后循环切主题色 / 切明暗，观察下列控件是否同步变化。
class MaterialComponentsPreview extends StatefulWidget {
  const MaterialComponentsPreview({super.key});

  @override
  State<MaterialComponentsPreview> createState() =>
      _MaterialComponentsPreviewState();
}

class _MaterialComponentsPreviewState
    extends State<MaterialComponentsPreview> {
  _Range _range = _Range.week;
  bool _filterOn = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPageScaffold(
      title: _kPageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PreviewCard(
            title: 'TabBar',
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: <Widget>[
                  const TabBar(
                    tabs: <Widget>[
                      Tab(text: '日'),
                      Tab(text: '周'),
                      Tab(text: '月'),
                    ],
                  ),
                  SizedBox(
                    height: 96,
                    child: TabBarView(
                      children: <Widget>[
                        for (final label in <String>['日视图', '周视图', '月视图'])
                          Center(
                            child: Text(
                              label,
                              style: AppTypography.body
                                  .copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          _PreviewCard(
            title: 'Chip（选中态）',
            child: Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('全部'),
                  selected: _filterOn,
                  onSelected: (v) => setState(() => _filterOn = v),
                ),
                FilterChip(
                  label: const Text('仅支出'),
                  selected: !_filterOn,
                  onSelected: (v) => setState(() => _filterOn = !v),
                ),
                const Chip(
                  label: Text('已同步'),
                  avatar: Icon(AppIcons.check, size: AppIconSize.small),
                ),
                // onSelected 省略（null）时 ChoiceChip 自动走
                // ChipThemeData.disabledColor 定义的禁用态
                const ChoiceChip(
                  label: Text('不可用'),
                  selected: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          _PreviewCard(
            title: 'SegmentedButton（选中态）',
            child: SegmentedButton<_Range>(
              segments: const <ButtonSegment<_Range>>[
                ButtonSegment<_Range>(
                  value: _Range.day,
                  label: Text('日'),
                  icon: Icon(AppIcons.calendarMonth, size: AppIconSize.medium),
                ),
                ButtonSegment<_Range>(
                  value: _Range.week,
                  label: Text('周'),
                ),
                ButtonSegment<_Range>(
                  value: _Range.month,
                  label: Text('月'),
                ),
              ],
              selected: <_Range>{_range},
              onSelectionChanged: (Set<_Range> value) =>
                  setState(() => _range = value.first),
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          _PreviewCard(
            title: 'PopupMenu / Badge / ProgressIndicator',
            child: Row(
              children: <Widget>[
                PopupMenuButton<String>(
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('编辑'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('删除'),
                    ),
                  ],
                  child: const Icon(AppIcons.edit),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Badge(
                  label: Text('3'),
                  child: Icon(AppIcons.about),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(
                  child: LinearProgressIndicator(value: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          _PreviewCard(
            title: 'DatePicker',
            child: FilledButton(
              onPressed: () async {
                await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
              },
              child: const Text('打开日期选择器'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Drawer 与 FloatingActionButton 无需样例：在任意 Scaffold 中放'
            ' drawer / floatingActionButton 即自动应用已配置的主题。',
            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.sectionHeader
                .copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
