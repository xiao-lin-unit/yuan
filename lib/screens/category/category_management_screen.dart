import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../commons/empty/app_empty_state.dart';
import '../commons/function/app_function_layout.dart';
import '../commons/icons/app_icons.dart';
import '../commons/scaffold/app_page_scaffold.dart';
import '../../database/category/category_record.dart';
import '../../service/category_controller.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import 'widgets/category_editor_sheet.dart';
import 'widgets/category_list_tile.dart';

// ── 页面私有内容（只服务本页，样式一律走全局层）───────────────
const String _kPageTitle = '分类管理';
const String _kListTitle = '分类列表';
const String _kTip =
    '拖住左侧手柄可调整顺序。预设分类不能删除，但可以隐藏，隐藏后记账时不会出现。';
const String _kFootExpense =
    '「必须花的 / 可省的」由你自己定，不打标记就不参与判断。算「失业能撑几个月」时，只用标了「必须花的」分类。';
const String _kFootIncome =
    '「每月都有 / 偶尔才有」由你自己定，不打标记就不参与判断。标了「每月都有」的会计入每月固定收入。';
const String _kDeleteTitle = '删除分类';
const String _kDeleteBody = '已记过的账不受影响，这条分类会进回收站，30 天内可恢复。';

/// 【我的】→ 管理 → 分类管理（原型 page-category-management）。
///
/// ── 功能页结构嵌套（本任务第 3 条）──────────────────────────────
/// ```
/// AppShell（全局唯一 Scaffold + 断点导航 + 键盘根开关）
///  └ AppPageScaffold（页级：顶栏/返回/新增 / 滚动内容 / 限宽）
///     └ Column
///        ├ AppSegmentTabs        支出分类 / 收入分类
///        ├ AppHintBanner         可关闭提示
///        ├ AppStatBar            在用 / 已隐藏 / 自定义
///        ├ AppFunctionSection    标题 + 「显示已隐藏」+ 列表
///        │   └ ReorderableListView → CategoryListTile
///        └ 底部说明
/// ```
/// 页面本身不写任何 BoxDecoration / TextStyle / 魔法间距，只把通用
/// 结构件和业务数据拼起来。以后做「账户」「分析」页照这四层套即可。
///
/// 【动态状态，工作逻辑写清楚】本页是 StatefulWidget，只有 3 个状态：
///   1. `_kind`：点分段按钮切换支出/收入，只影响「取哪一组数据」；
///   2. `_showHidden`：点「显示已隐藏」切换，只影响列表过滤；
///   3. `_tipVisible`：点提示条 ✕ 隐藏，纯 UI。
/// 三者都不持久化、不跨页面；真正的分类数据**全部**来自
/// `context.watch<CategoryController>()` 的内存快照，页面不另存一份。
/// 任何写操作都是 `await controller.xxx()` → Controller 落库后 reload
/// → notifyListeners → 本页自动重建，没有 setState 手动改数据。
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends State<CategoryManagementScreen> {
  CategoryKind _kind = CategoryKind.expense;
  bool _showHidden = false;
  bool _tipVisible = true;

  @override
  Widget build(BuildContext context) {
    final CategoryController controller =
        context.watch<CategoryController>();
    final List<CategoryRecord> rows =
        controller.managed(_kind, includeHidden: _showHidden);
    final CategoryStats stats = controller.statsOf(_kind);

    return AppPageScaffold(
      title: _kPageTitle,
      // 显式返回：二级页在 ShellRoute 的嵌套 Navigator 里，可 pop。
      // 不用 AppBar 自动推断的 leading，代码一眼能看清去哪。
      leading: IconButton(
        icon: const Icon(AppIcons.chevronLeft),
        tooltip: '返回',
        onPressed: () => context.pop(),
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(AppIcons.add),
          tooltip: '新增分类',
          onPressed: () => unawaited(
            showCategoryEditorSheet(
              context,
              kind: _kind,
              controller: controller,
            ),
          ),
        ),
      ],
      // 与 ProfileScreen 一致：分区结构件各自管左右 16dp 留白，
      // 页壳只管上下留白；避免「页壳 16 + 分区 16 = 32」的缩进。
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSegmentTabs<CategoryKind>(
            options: <AppSegmentOption<CategoryKind>>[
              AppSegmentOption<CategoryKind>(
                value: CategoryKind.expense,
                label: CategoryKind.expense.pageTab,
              ),
              AppSegmentOption<CategoryKind>(
                value: CategoryKind.income,
                label: CategoryKind.income.pageTab,
              ),
            ],
            selected: _kind,
            onChanged: (CategoryKind value) =>
                setState(() => _kind = value),
          ),
          if (_tipVisible)
            AppHintBanner(
              message: _kTip,
              onDismiss: () => setState(() => _tipVisible = false),
            ),
          AppStatBar(
            items: <AppStatItem>[
              AppStatItem(label: '在用', value: '${stats.active}'),
              AppStatItem(label: '已隐藏', value: '${stats.hidden}'),
              AppStatItem(label: '自定义', value: '${stats.custom}'),
            ],
          ),
          AppFunctionSection(
            title: _kListTitle,
            actionLabel: _showHidden ? '隐藏已隐藏' : '显示已隐藏',
            onAction: () => setState(() => _showHidden = !_showHidden),
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: AppEmptyState(
                      icon: AppIcons.category,
                      title: '这里还没有分类',
                      description: '点右上角的 ＋ 新建一个。',
                    ),
                  )
                : _buildList(context, controller, rows),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              _kind == CategoryKind.expense ? _kFootExpense : _kFootIncome,
              style: context.appText.caption,
            ),
          ),
        ],
      ),
    );
  }

  /// 列表：外层 AppPageScaffold 已经有 SingleChildScrollView，所以这里
  /// 用 shrinkWrap + NeverScrollableScrollPhysics，把滚动交给外层一处，
  /// 避免两个可滚动 widget 抢手势。拖拽手柄用
  /// [ReorderableDragStartListener] 显式绑定 index。
  Widget _buildList(
    BuildContext context,
    CategoryController controller,
    List<CategoryRecord> rows,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: rows.length,
          onReorderItem: (int oldIndex, int newIndex) async {
            final List<int> ids = rows
                .map((CategoryRecord r) => r.id)
                .whereType<int>()
                .toList();
            int target = newIndex;
            if (target > oldIndex) target -= 1;
            final int moved = ids.removeAt(oldIndex);
            ids.insert(target, moved);
            await controller.reorder(_kind, ids);
          },
          itemBuilder: (BuildContext context, int i) {
            final CategoryRecord record = rows[i];
            return CategoryListTile(
              // ReorderableListView 要求每个 child 有稳定 key。
              key: ValueKey<int>(record.id ?? i),
              record: record,
              displayIndex: i,
              dragIndex: i,
              onEdit: () => unawaited(
                showCategoryEditorSheet(
                  context,
                  kind: _kind,
                  controller: controller,
                  category: record,
                ),
              ),
              onToggleHidden: () => unawaited(
                _run(context, () => controller.toggleHidden(record.id!)),
              ),
              onOrderTap: () => unawaited(_askOrder(context, controller, record, i)),
              onDelete: () => unawaited(_confirmDelete(context, controller, record)),
            );
          },
        ),
      );

  /// 统一的写操作错误提示：失败时 SnackBar，界面保持原值（Controller
  /// 写失败不会改内存快照）。预设分类不能删时给的就是这句话。
  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  /// 「填序号改排序」（原型 promptOrder）：Material 对话框，主题已统一配置。
  Future<void> _askOrder(
    BuildContext context,
    CategoryController controller,
    CategoryRecord record,
    int currentIndex,
  ) async {
    final TextEditingController input = TextEditingController(
      text: '${currentIndex + 1}',
    );
    final int? target = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('调整排序'),
        content: TextField(
          controller: input,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            helperText: '数字越小越靠前',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final int? v = int.tryParse(input.text.trim());
              Navigator.of(ctx).pop(v);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    input.dispose();
    if (target == null || !context.mounted) return;
    await _run(
      context,
      () => controller.moveTo(record.id!, target - 1),
    );
  }

  /// 删除 = 进回收站（10.7）。预设分类给明确提示而不是灰色按钮，
  /// 出口直接指给用户「改成隐藏」。
  Future<void> _confirmDelete(
    BuildContext context,
    CategoryController controller,
    CategoryRecord record,
  ) async {
    if (record.preset) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预设分类不能删除，但可以隐藏——点「在用」就行。')),
      );
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text(_kDeleteTitle),
        content: Text('删除「${record.name}」？\n$_kDeleteBody'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      () => controller.delete(record.id!),
    );
  }
}
