import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../service/account_controller.dart';
import '../../styles/app_decorations.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import '../commons/empty/app_empty_state.dart';
import '../commons/function/app_function_layout.dart';
import '../commons/home/app_home_page.dart';
import '../commons/icons/app_icons.dart';
import 'widgets/account_card.dart';
import 'widgets/account_sheets.dart';

// ── 页面私有尺寸（只服务本文件，全部引用全局令牌）───────────────
const double _kSearchHeight = 40;
const double _kClearSize = 32;
const double _kChipGap = AppSpacing.xs;
const double _kCountBadgeRadius = AppRadius.small;
const double _kGroupHeaderHeight = kMinTapTarget;

// ── 页面私有文案（官方书面语；样式一律走全局层）─────────────────
const String _kSearchHint = '搜索账户名称、类型或备注';
const String _kSearchGroup = '搜索结果';
const String _kArchivedSection = '已归档账户';
const String _kEmptyTitle = '还没有添加账户';
const String _kEmptyDescription =
    '把银行卡、现金、微信零钱放进来，随时看清现在能花多少钱。';
const String _kSearchEmptyTitle = '没找到匹配的账户';
const String _kSearchEmptyDescription = '换个关键词，或者点「全部」查看所有账户。';
const String _kFilterEmptyTitle = '这一类还没有账户';
const String _kFilterEmptyDescription = '点右上角 ＋ 新增，或切回「全部」查看其它账户。';
const String _kFootNote =
    '「真正属于你的钱」会把所有账户加起来、再减去欠银行的钱。'
    '以后记进资产和借款后，这个数字会更完整。';

/// 类型快筛标签。**只按账户类型分**，不含原型的「常用」：
/// accounts 表没有「置顶 / 常用」字段，按「没有业务变化就不二次改表结构」
/// 的原则不擅自加列；将来真要做，先明确常用规则（手动置顶 or 按使用频率），
/// 再决定加 is_pinned 字段还是关联表。
enum _AccountFilter { all, liquid, credit, restricted }

/// 可折叠的段。段键只用于记录「哪几段被收起」，不写库、不跨页面。
enum _AccountGroup { liquid, credit, restricted, archived, search }

AccountKind? _kindOf(_AccountFilter f) => switch (f) {
      _AccountFilter.all => null,
      _AccountFilter.liquid => AccountKind.liquid,
      _AccountFilter.credit => AccountKind.credit,
      _AccountFilter.restricted => AccountKind.restricted,
    };

_AccountGroup _groupOf(AccountKind kind) => switch (kind) {
      AccountKind.liquid => _AccountGroup.liquid,
      AccountKind.credit => _AccountGroup.credit,
      AccountKind.restricted => _AccountGroup.restricted,
    };

String _filterLabel(_AccountFilter f) => switch (f) {
      _AccountFilter.all => '全部',
      _AccountFilter.liquid => '流动资金',
      _AccountFilter.credit => '信用卡',
      _AccountFilter.restricted => '其他资金',
    };

IconData _filterIcon(_AccountFilter f) => switch (f) {
      _AccountFilter.all => AppIcons.accounts,
      _AccountFilter.liquid => AppIcons.accountCash,
      _AccountFilter.credit => AppIcons.accountCreditCard,
      _AccountFilter.restricted => AppIcons.locked,
    };

/// 【账户】= 底导直接打开的 5 个 Home 页之一。
///
/// ── 结构嵌套（与分类管理页共用同一套结构层）────────────────────
/// ```
/// AppShell（全局唯一 Scaffold + 断点导航 + 键盘根开关）
///  └ AppHomePage（★ Home 页专用：无标题、无返回、右上角只有 ＋）
///     ├ hero   → AppSummaryHero（通用件；数字随筛选标签切换）
///     └ child  → 搜索栏 → 类型快筛 chips → 可折叠分组 → 底部说明
///                  └ 每段：_AccountGroupHeader + AccountCard 列表
/// ```
/// 首屏第一块直接是数字；搜索栏、chips、分组头**全部在滚动 Column 里**，
/// 没有任何「提升 / pin / 注册到固定槽位」的机制——固定还是滚动，
/// 只看 Column 的 children 顺序，读构造函数就能看全。
///
/// ── 本页的动态逻辑（4 处，按项目约定分步写清）───────────────────
/// 为什么需要动态：折叠、搜索、类型筛选都随用户操作变化，构造期定不死。
/// 全部是本 State 里最朴素的字段 + setState，没有 Notifier、
/// InheritedWidget 提升、跨帧回调，也没有第二种渲染模式。
///
/// ① 数据源：`context.watch<AccountController>()` 的内存快照，页面不复制
///    账户列表、不查数据库；Controller 写库后 load() → notify 驱动重建。
/// ② 筛选：点 chip → `_selectFilter` → setState → `scoped` 按 kind 过滤；
///    顶部 AppSummaryHero 与分组头合计都用 `controller.statsFor(scoped)`，
///    所以「上面的数字」和「下面的列表」永远同源，不会出现上下对不上。
/// ③ 搜索：输入 → setState 存关键词 → 在 scoped 里按「名称 / 形态 /
///    备注 / 副标题」做包含匹配；归档账户单独按同一关键词过滤，
///    让已归档的账户也能被搜到。搜索时**强制展开全部分组**、并合并成
///    「搜索结果」一段，避免收起的段把结果藏起来。
/// ④ 折叠：点分组头 → `_toggleGroup` 把段键加入 / 移出 `_collapsed`；
///    build 里 `collapsed = 段键在集合里` 决定是否渲染卡片列表。
///    折叠状态只在内存，退出页面即重置，不写库（原型也是这个行为）。
///
/// ── 边界行为 ────────────────────────────────────────────────────
/// · 统计**不受搜索词影响**：只按类型筛选后的全量算，否则一输入关键词
///   总额就缩水，容易让用户误以为钱少了；列表才受关键词影响。
/// · 某一段 0 个账户 → 不渲染该段；全部无结果 → 显示 AppEmptyState。
/// · 切换筛选不清空折叠集合（段键是类型，跨筛选仍然有意义）。
/// · 归档段始终排在最后、不受类型筛选影响，只受搜索词影响。
///
/// ── 原型取舍（如实写明，避免「看着不像原型」时无从查起）──────────
/// · 原型是三张横滑统计卡 + 小圆点；本项目已有通用 `AppSummaryHero`，
///   按「通用组件复用」改成「一张卡 + 点 chip 切换统计口径」，比横滑
///   更直接（点哪类就显示哪类），也不引入 PageView 下标这类运行时状态。
/// · 原型还有「排序方式」菜单与「常用账户」chip：本轮按你点名的三项
///   （折叠 / 搜索 / 类型标签）实现，排序沿用 DAO 的 sort_order 自定义
///   顺序，「常用」缺数据字段暂不做。要补排序只需在 State 里加一个
///   枚举 + 一个按钮，不需要改结构层。
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  // ── 动态状态：只有这 4 个字段，全部在 build 里一次性消费 ──────────
  _AccountFilter _filter = _AccountFilter.all;
  String _keyword = '';
  final Set<_AccountGroup> _collapsed = <_AccountGroup>{};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectFilter(_AccountFilter f) => setState(() {
    _filter = f;
  });

  void _clearSearch() {
    _search.clear();
    setState(() => _keyword = '');
  }

  /// Set.remove 返回「原来有没有」；没有就加入，实现一次点击切换。
  void _toggleGroup(_AccountGroup key) => setState(() {
        if (!_collapsed.remove(key)) _collapsed.add(key);
      });

  static bool _matches(AccountRecord r, String kw) {
    if (kw.isEmpty) return true;
    return '${r.name} ${r.type.label} ${r.note} ${r.subtitle}'
        .toLowerCase()
        .contains(kw);
  }

  @override
  Widget build(BuildContext context) {
    final AccountController controller = context.watch<AccountController>();
    final List<AccountRecord> active = controller.all
        .where((AccountRecord r) => !r.isDeleted && !r.archived)
        .toList(growable: false);
    final List<AccountRecord> archived = controller.archived;
    final String kw = _keyword.trim().toLowerCase();
    final bool searching = kw.isNotEmpty;

    // ① 类型筛选：统计与列表共用这一份 scoped，保证上下对得上。
    final AccountKind? scopedKind = _kindOf(_filter);
    final List<AccountRecord> scoped = scopedKind == null
        ? active
        : active
            .where((AccountRecord r) => r.kind == scopedKind)
            .toList(growable: false);

    // ② 搜索：只影响列表，不影响统计。
    final List<AccountRecord> visible = searching
        ? scoped
            .where((AccountRecord r) => _matches(r, kw))
            .toList(growable: false)
        : scoped;
    final List<AccountRecord> visibleArchived = searching
        ? archived
            .where((AccountRecord r) => _matches(r, kw))
            .toList(growable: false)
        : archived;

    final AccountStats stats = controller.statsFor(scoped);
    final bool nothingAtAll = active.isEmpty && archived.isEmpty;
    final bool nothingShown = visible.isEmpty && visibleArchived.isEmpty;

    return AppHomePage(
      // 右上角只放动作，没有标题、没有返回按钮。
      actions: <Widget>[
        IconButton(
          icon: const Icon(AppIcons.accountAdd),
          tooltip: '添加账户',
          onPressed: () => unawaited(_addAccount(context, controller)),
        ),
      ],
      // 分区结构件各自管左右 16dp 留白，页壳只管上下留白，
      // 避免「页壳 16 + 分区 16 = 32」的双重缩进（与分类管理页一致）。
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom,
      ),
      hero: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: _heroFor(context, stats, scoped),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          _searchField(context),
          const SizedBox(height: AppSpacing.xs),
          _filterChips(active),
          const SizedBox(height: AppSpacing.sm),
          if (nothingAtAll)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: AppEmptyState(
                icon: AppIcons.accountAdd,
                title: _kEmptyTitle,
                description: _kEmptyDescription,
              ),
            )
          else if (nothingShown)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: AppEmptyState(
                icon: searching ? AppIcons.search : AppIcons.accounts,
                title: searching ? _kSearchEmptyTitle : _kFilterEmptyTitle,
                description: searching
                    ? _kSearchEmptyDescription
                    : _kFilterEmptyDescription,
              ),
            )
          else ...<Widget>[
            ..._groups(context, visible, visibleArchived, searching),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                '$_kFootNote\n'
                '目前按账户算：${MoneyFormat.yuan0(controller.netWorthSoFar)}',
                style: context.appText.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 顶部摘要：**同一张通用卡**，只是按筛选标签换 label / 数字 / 口径说明。
  /// 色值只从 context.tokens 取语义色，换主题色或切明暗自动重算。
  Widget _heroFor(
    BuildContext context,
    AccountStats stats,
    List<AccountRecord> scoped,
  ) {
    final AppThemeTokens tokens = context.tokens;
    final double availableCredit = scoped
        .where((AccountRecord r) => r.kind == AccountKind.credit)
        .fold<double>(
          0,
          (double v, AccountRecord r) => v + (r.availableCredit ?? 0),
        );

    return switch (_filter) {
      _AccountFilter.all => AppSummaryHero(
          label: '能花的钱',
          value: MoneyFormat.yuan0(stats.spendable),
          caption: '你当前可支配金额，共 ${stats.accountCount} 个账户。',
          secondary: <AppInfoItem>[
            AppInfoItem(
              label: '欠银行的钱',
              value: MoneyFormat.yuan0(stats.owedToBank),
            ),
            AppInfoItem(
              label: '动不了的钱',
              value: MoneyFormat.yuan0(stats.restrictedTotal),
            ),
          ],
        ),
      _AccountFilter.liquid => AppSummaryHero(
          label: '流动资金账户',
          value: MoneyFormat.yuan0(stats.spendable),
          caption: '可自由支配的资金，共 ${stats.accountCount} 个账户。',
          secondary: <AppInfoItem>[
            AppInfoItem(label: '账户数', value: '${stats.accountCount} 个'),
            const AppInfoItem(label: '计入', value: '可用余额'),
          ],
        ),
      _AccountFilter.credit => AppSummaryHero(
          label: '信用卡账户',
          value: MoneyFormat.yuan0(stats.owedToBank),
          caption: '先消费后还款，这部分属于欠款。',
          accent: tokens.expense,
          secondary: <AppInfoItem>[
            AppInfoItem(
              label: '可用额度',
              value: MoneyFormat.yuan0(availableCredit),
            ),
            AppInfoItem(label: '卡片数', value: '${stats.creditCount} 张'),
          ],
        ),
      _AccountFilter.restricted => AppSummaryHero(
          label: '其他资金账户',
          value: MoneyFormat.yuan0(stats.restrictedTotal),
          caption: '有特定用途，不计入可用余额。',
          accent: tokens.warning,
          secondary: <AppInfoItem>[
            AppInfoItem(label: '账户数', value: '${stats.accountCount} 个'),
            const AppInfoItem(label: '计入', value: '资产合计'),
          ],
        ),
    };
  }

  /// 搜索框。外层用全局 field 装饰；TextField 自己**不画边框、不填充**，
  /// 并且显式把 constraints 覆盖成空 —— 全局 inputDecorationTheme 带
  /// minHeight 56dp（表单输入框用），搜索框只有 40dp，不覆盖会被撑高、
  /// 文字贴顶（与前几轮单行表单是同一个坑）。
  Widget _searchField(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        height: _kSearchHeight,
        decoration: AppDecorations.field(context),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(
              AppIcons.search,
              size: AppIconSize.small,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (String v) => setState(() {
                  _keyword = v;
                }),
                textInputAction: TextInputAction.search,
                style: context.appText.body,
                decoration: InputDecoration(
                  isCollapsed: true,
                  constraints: const BoxConstraints(),
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: _kSearchHint,
                  hintStyle: context.appText.hint,
                ),
              ),
            ),
            if (_keyword.isNotEmpty)
              GestureDetector(
                onTap: _clearSearch,
                child: SizedBox(
                  width: _kClearSize,
                  height: _kClearSize,
                  child: Icon(
                    AppIcons.clear,
                    size: AppIconSize.small,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 类型快筛：横向一排，多出屏幕可横滑。
  /// 圆角、选中底、文字色全部来自 settings.dart 的全局 ChipThemeData，
  /// 本页不写任何颜色；数量与标签合成一个文本，避免自定义 label 样式。
  Widget _filterChips(List<AccountRecord> active) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < _AccountFilter.values.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: _kChipGap),
              _filterChip(_AccountFilter.values[i], _countFor(active, i)),
            ],
          ],
        ),
      );

  Widget _filterChip(_AccountFilter f, int count) => ChoiceChip(
        avatar: Icon(_filterIcon(f), size: AppIconSize.small),
        label: Text('${_filterLabel(f)} $count'),
        selected: _filter == f,
        showCheckmark: false,
        onSelected: (bool _) => _selectFilter(f),
      );

  static int _countFor(List<AccountRecord> active, int index) {
    final AccountKind? kind = _kindOf(_AccountFilter.values[index]);
    if (kind == null) return active.length;
    return active.where((AccountRecord r) => r.kind == kind).length;
  }

  /// 分组装配。搜索时合并成一段；否则「全部」按三类分三段，
  /// 选中某类只出一段；归档段永远排最后。
  List<Widget> _groups(
    BuildContext context,
    List<AccountRecord> visible,
    List<AccountRecord> archived,
    bool searching,
  ) {
    final List<Widget> out = <Widget>[];
    if (searching) {
      out.add(
        _group(context, _AccountGroup.search, _kSearchGroup, visible,
            forceExpanded: true),
      );
    } else if (_filter == _AccountFilter.all) {
      for (final AccountKind kind in AccountKind.values) {
        out.add(
          _group(
            context,
            _groupOf(kind),
            kind.label,
            visible
                .where((AccountRecord r) => r.kind == kind)
                .toList(growable: false),
            forceExpanded: false,
          ),
        );
      }
    } else {
      final AccountKind kind = _kindOf(_filter)!;
      out.add(
        _group(context, _groupOf(kind), kind.label, visible,
            forceExpanded: false),
      );
    }
    if (archived.isNotEmpty) {
      out.add(
        _group(context, _AccountGroup.archived, _kArchivedSection, archived,
            forceExpanded: searching),
      );
    }
    return out;
  }

  /// 一段 = 可点标题行 +（未折叠时）卡片列表。
  /// 段内合计取 balance 之和：流动资金/受限是余额合计，信用卡是
  /// **已用额度合计**（两者在模型里是同一列，口径见 AccountRecord.balance）。
  Widget _group(
    BuildContext context,
    _AccountGroup key,
    String label,
    List<AccountRecord> rows, {
    required bool forceExpanded,
  }) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final bool collapsed = !forceExpanded && _collapsed.contains(key);
    final double sum = rows.fold<double>(
      0,
      (double v, AccountRecord r) => v + r.balance,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _AccountGroupHeader(
          label: label,
          count: rows.length,
          sumText: MoneyFormat.yuan0(sum),
          collapsed: collapsed,
          onToggle: () => _toggleGroup(key),
        ),
        if (!collapsed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < rows.length; i++)
                  AccountCard(
                    key: ValueKey<int>(rows[i].id ?? i),
                    account: rows[i],
                    index: i,
                    onTap: () => unawaited(
                      context.push('/accounts/detail/${rows[i].id}'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// 新增两步：先用 ⑤ CategorySheetContent 选类型，
  /// 再用 ① FormSheetContent 填表。**顺序两个弹层，不是弹窗套弹窗**。
  /// 关闭类型选择（返回 null）就什么都不做。
  Future<void> _addAccount(
    BuildContext context,
    AccountController controller,
  ) async {
    final AccountKind? kind = await showAccountKindPicker(context);
    if (kind == null || !context.mounted) return;
    await showAccountEditorSheet(
      context,
      controller: controller,
      kind: kind,
    );
  }
}

/// 分组标题行：展开/折叠箭头、段名、数量徽章、段内合计。
///
/// **纯静态**：箭头图标按 [collapsed] 布尔值二选一，没有隐式动画、
/// 没有 Notifier；点一下由页面 setState 重建，读这一行就知道会发生什么。
/// 左右 16dp 与 SectionHeader 一致，颜色只取 ColorScheme / 全局文字角色。
class _AccountGroupHeader extends StatelessWidget {
  const _AccountGroupHeader({
    required this.label,
    required this.count,
    required this.sumText,
    required this.collapsed,
    required this.onToggle,
  });

  final String label;
  final int count;
  final String sumText;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xxs,
        ),
        child: SizedBox(
          height: _kGroupHeaderHeight,
          child: Row(
            children: <Widget>[
              Icon(
                collapsed ? AppIcons.chevronRight : AppIcons.expandMore,
                size: AppIconSize.medium,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(label, style: context.appText.sectionHeader),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(_kCountBadgeRadius),
                ),
                child: Text('$count', style: context.appText.caption),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(sumText, style: context.appText.menuTitle),
            ],
          ),
        ),
      ),
    );
  }
}
