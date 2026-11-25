import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../service/account_controller.dart';
import '../../service/credit_card_account_controller.dart';
import '../../service/savings_account_controller.dart';
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
    '以后把房子、借进借出的钱也记进来，这个数字会更完整。';
const String _kDragTip = '拖动账户左侧手柄可调整顺序；搜索结果不参与排序。';

// ── 3.6 看板的 2c 增量（A1 / A2 / A3）────────────────────────────
// A2（P0）：月末存一次数，之后改价 / 改口径都不改写历史。
// 清单原话是「改一行文案 + 一个跳转」，但跳转目标 8.1.4 归因还没做；
// 按 10.9「一个功能只在一个地方出现」，这里只写静态文案，不造第二个
// 入口、也不画一条还没数据的趋势图。
const String _kTrendNote =
    '变化趋势按每个月末存一次数记录：之后改了价、改了口径，都不会改写历史。';
// A3（3.8 / 13.1 / 13.12）：账本永远是名义金额。
const String _kNominalNote =
    '账本里记的都是当时填下的钱数，软件不会自己把它调大或调小。';
// A1（3.6 两行）属情境设计：月收入、必须花的钱是 8.2 / 13.2 的推算
// 参数，结果只在情境设计里出，不在账户 / 资债页摆「—」占位槽位。
const String _kReminderDisclaimer = '估算，按你填的日利率粗算，以账单为准。';

/// 类型快筛标签。**只按账户类型分**，不含原型的「常用」：
/// 本轮需求只覆盖类型快筛，「常用」的排序规则（手动置顶 or 按使用频率）
/// 还没定，先不做半截功能；规则确定后该加的字段正常加。
enum _AccountFilter { all, liquid, credit, restricted, investment }

/// 可折叠的段。段键只用于记录「哪几段被收起」，不写库、不跨页面。
enum _AccountGroup { liquid, credit, restricted, investment, archived, search }

AccountKind? _kindOf(_AccountFilter f) => switch (f) {
      _AccountFilter.all => null,
      _AccountFilter.liquid => AccountKind.liquid,
      _AccountFilter.credit => AccountKind.credit,
      _AccountFilter.restricted => AccountKind.restricted,
      _AccountFilter.investment => AccountKind.investment,
    };

_AccountGroup _groupOf(AccountKind kind) => switch (kind) {
      AccountKind.liquid => _AccountGroup.liquid,
      AccountKind.credit => _AccountGroup.credit,
      AccountKind.restricted => _AccountGroup.restricted,
      AccountKind.investment => _AccountGroup.investment,
    };

String _filterLabel(_AccountFilter f) => switch (f) {
      _AccountFilter.all => '全部',
      _AccountFilter.liquid => '流动资金',
      _AccountFilter.credit => '信用卡',
      _AccountFilter.restricted => '其他资金',
      _AccountFilter.investment => '投资'
    };

IconData _filterIcon(_AccountFilter f) => switch (f) {
      _AccountFilter.all => AppIcons.accounts,
      _AccountFilter.liquid => AppIcons.accountCash,
      _AccountFilter.credit => AppIcons.accountCreditCard,
      _AccountFilter.restricted => AppIcons.locked,
      _AccountFilter.investment => AppIcons.accountCash,
    };

/// 【账户】= 底导直接打开的 5 个 Home 页之一。
///
/// ── 结构嵌套（与分类管理页共用同一套结构层）────────────────────
/// ```
/// AppShell（全局唯一 Scaffold + 断点导航 + 键盘根开关）
///  └ AppHomePage（★ Home 页专用：无标题、无返回、右上角只有 ＋）
///     ├ hero   → AppSummaryHero（通用件；数字随筛选标签切换）
///     └ child  → 搜索栏 → 类型快筛 chips → 可折叠分组 → 底部说明
///                  └ 每段：_AccountGroupHeader + ReorderableListView
///                          （shrinkWrap，滚动交给页壳一处）
/// ```
/// 首屏第一块直接是数字；搜索栏、chips、分组头**全部在滚动 Column 里**，
/// 没有任何「提升 / pin / 注册到固定槽位」的机制——固定还是滚动，
/// 只看 Column 的 children 顺序，读构造函数就能看全。
///
/// ── 本页的动态逻辑（4 处状态 + 1 处写操作，按项目约定分步写清）────
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
/// ⑤ 拖拽提交（唯一一处写操作，不新增任何 State 字段）：
///    ReorderableListView 给出 oldIndex/newIndex → 把**这一段**的 ids
///    按新顺序排好 → `AccountController.reorder(ids)` → DAO 在一个事务
///    里批量写 sort_order → Controller load() 重读并 notify → 页面重建。
///    Controller 会把「不在这批 ids 里」的记录留在原槽位，所以按类型
///    筛选或只拖一段时，其它类别 / 归档项不会被挤到末尾。
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
/// · 原型还有「排序方式」菜单与「常用账户」chip：
///   - 自定义排序**已接上**：沿用 DAO 的 sort_order + 现成的
///     AccountController.reorder，拖柄照抄分类页 CategoryListTile，
///     没有新增字段、没有新增表、没有第二种排序模式；
///   - 「常用账户」仍不接 UI：规则（手动置顶 or 按使用频率）没定，
///     不做半截功能。数据层已备好按流水聚合的只读查询
///     （AccountController.frequentlyUsedAccounts），等「记支出」模块
///     确定口径后直接取用；「上次使用账户」就是该结果的第一项。
///   - 「排序方式」菜单不做：目前只有 sort_order 一种顺序，加菜单
///     等于加一个没有第二种选项的开关。
///
/// ── 2c 增量（本轮，全部静态，无新增状态）────────────────────────
/// · A2（P0）：底部 [_BoardNotes] 写清「变化趋势按月末存一次数」，
///   不造 8.1.4 归因的第二个入口、不画没数据的趋势图；
/// · A1（P1）：两行只读槽位显示「—」+ 白话原因，数据源模块没做，
///   绝不拿别的数凑；等聚合查询就位只换字符串，页面结构不动；
/// · A3：一句「账本里记的都是当时填下的钱数」说明名义金额口径；
/// · 3.4 还款提醒：顶部 [_RepaymentReminders]，由共享账本同步算好，
///   未来 3 天内到期才出现，纯只读、不写库、不提供关闭按钮；
/// · 附二白话：界面里的「计入资产合计 / 资产合计 / 以后记进资产和借款」
///   等词全部改成人话（零、二章最高准则）。
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
          // 3.4 还款日临近提示：放在账户页最上面（当前唯一的资金总览
          // 入口），纯只读、无关闭按钮、不写库。将来做总览首页时可整块
          // 平移过去，那时这里删掉即可，不会出现两处提醒。
          _RepaymentReminders(
            reminders: controller.upcomingRepayments(DateTime.now()),
          ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: Text(_kDragTip, style: context.appText.caption),
            ),
            ..._groups(
              context,
              controller,
              visible,
              visibleArchived,
              searching,
            ),
            const SizedBox(height: AppSpacing.sm),
            _BoardNotes(
              netWorthText: MoneyFormat.yuan0(controller.netWorthSoFar),
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
          // 配色试点：唯一一张主色 hero。其余三张（含传语义 accent 的
          // 信用卡 / 受限卡）保持中性卡，看完观感再决定铺开范围。
          emphasized: true,
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
            const AppInfoItem(label: '这笔钱', value: '算进总账'),
          ],
        ),
      // 契-7：K4 投资账户在看板单列，只显示剩余可用额；股票市值由资产侧算，
      // 这里不重复计。scoped 已按筛选标签收窄，与 availableCredit 同源。
      _AccountFilter.investment => AppSummaryHero(
          label: '投资账户',
          value: MoneyFormat.yuan0(scoped
              .where((AccountRecord r) => r.kind == AccountKind.investment)
              .fold<double>(
                0,
                (double v, AccountRecord r) => v + r.balance,
              )),
          caption: '券商资金账户里的钱，可转出到储蓄卡。',
          secondary: <AppInfoItem>[
            AppInfoItem(
              label: '账户数',
              value: '${scoped.where((AccountRecord r) => r.kind == AccountKind.investment).length} 个',
            ),
            const AppInfoItem(label: '股票市值', value: '资产侧'),
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
    AccountController controller,
    List<AccountRecord> visible,
    List<AccountRecord> archived,
    bool searching,
  ) {
    final List<Widget> out = <Widget>[];
    if (searching) {
      out.add(
        _group(
          context,
          controller,
          _AccountGroup.search,
          _kSearchGroup,
          visible,
          forceExpanded: true,
          draggable: false,
        ),
      );
    } else if (_filter == _AccountFilter.all) {
      for (final AccountKind kind in AccountKind.values) {
        out.add(
          _group(
            context,
            controller,
            _groupOf(kind),
            kind.label,
            visible
                .where((AccountRecord r) => r.kind == kind)
                .toList(growable: false),
            forceExpanded: false,
            draggable: true,
          ),
        );
      }
    } else {
      final AccountKind kind = _kindOf(_filter)!;
      out.add(
        _group(
          context,
          controller,
          _groupOf(kind),
          kind.label,
          visible,
          forceExpanded: false,
          draggable: true,
        ),
      );
    }
    if (archived.isNotEmpty) {
      out.add(
        _group(
          context,
          controller,
          _AccountGroup.archived,
          _kArchivedSection,
          archived,
          forceExpanded: searching,
          draggable: !searching,
        ),
      );
    }
    return out;
  }

  /// 一段 = 可点标题行 +（未折叠时）卡片列表。
  /// 段内合计取 balance 之和：流动资金/受限是余额合计，信用卡是
  /// **已用额度合计**（两者在模型里是同一列，口径见 AccountRecord.balance）。
  Widget _group(
    BuildContext context,
    AccountController controller,
    _AccountGroup key,
    String label,
    List<AccountRecord> rows, {
    required bool forceExpanded,
    required bool draggable,
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
            // 与分类页 _buildList 同一套写法：页壳 AppHomePage 已经有
            // SingleChildScrollView，这里 shrinkWrap + 禁止自身滚动，
            // 把滚动手势交给外层唯一一处；拖柄用显式 index 绑定，
            // 不用默认长按整卡（会和卡片的点击进详情抢手势）。
            //
            // 【下标与提交，工作逻辑 4 步】
            //   ① itemBuilder 的 i 是**这一段内**的下标，ReorderableListView
            //      只认识自己的 itemCount，所以 dragIndex 传 i；
            //   ② 回调的 newIndex 是「插入位置」，向下拖时要减 1 才是
            //      目标下标（与分类页 onReorderItem 完全一致）；
            //   ③ ids 只收这一段的账户，按新顺序排好后交给
            //      AccountController.reorder；它把其它账户留在原槽位；
            //   ④ reorder 落库 → load() → notifyListeners → 本页重建。
            // 【边界】draggable=false（搜索结果 / 搜索时的归档段）只是
            // 不渲染拖柄，列表仍走同一条渲染路径，没有隐藏的第二种模式；
            // 跨类别的临时搜索结果本来也没有稳定的排序语义。
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: rows.length,
              onReorderItem: (int oldIndex, int newIndex) async {
                final List<int> ids = rows
                    .map((AccountRecord r) => r.id)
                    .whereType<int>()
                    .toList();
                int target = newIndex;
                if (target > oldIndex) target -= 1;
                final int moved = ids.removeAt(oldIndex);
                ids.insert(target, moved);
                await controller.reorder(ids);
              },
              itemBuilder: (BuildContext context, int i) => AccountCard(
                // ReorderableListView 要求每个 child 有稳定 key。
                key: ValueKey<int>(rows[i].id ?? i),
                account: rows[i],
                index: i,
                dragIndex: draggable ? i : null,
                onTap: () => unawaited(
                  context.push('/accounts/detail/${rows[i].id}'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 新增两步：先用 ⑤ CategorySheetContent 选类型，
  /// 再用 ① FormSheetContent 填表。**顺序两个弹层，不是弹窗套弹窗**。
  /// 关闭类型选择（返回 null）就什么都不做。
  ///
  /// 【分派说明】共享账本 `controller` 只负责查询与重名校验；真正落库
  /// 由表单按所选类别交给 SavingsAccountController 或
  /// CreditCardAccountController，页面不碰资金方向逻辑。
  Future<void> _addAccount(
    BuildContext context,
    AccountController controller,
  ) async {
    final AccountKind? kind = await showAccountKindPicker(context);
    if (kind == null || !context.mounted) return;
    await showAccountEditorSheet(
      context,
      catalog: controller,
      savings: context.read<SavingsAccountController>(),
      credit: context.read<CreditCardAccountController>(),
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

/// 3.4 还款提醒条（首页醒目位置，纯只读）。
///
/// 【纯静态，没有状态、没有 Notifier】要不要显示、显示几张卡，全部由
/// 调用方用 `AccountController.upcomingRepayments(DateTime.now())` 在
/// build 里算好后构造期传入；本组件只按列表渲染，自己不读时间、不查库、
/// 不提供「关闭」按钮（提醒不该被随手关掉后就不见了）。
///
/// 【估算口径，必须写清】「下个月大约会多出 X 利息」只在用户填了日
/// 利率时才出现，公式是（已用 − 最低还款）× 日利率 × 30，界面固定
/// 附 [_kReminderDisclaimer]；不按 7.7 的六种还款算法精算，因为负债
/// 模块还没做，提前精算等于拿估算冒充银行账单。
class _RepaymentReminders extends StatelessWidget {
  const _RepaymentReminders({required this.reminders});

  final List<RepaymentReminder> reminders;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final RepaymentReminder r in reminders)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _card(context, r),
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, RepaymentReminder r) {
    final String when = r.daysLeft == 0 ? '今天' : '还有 ${r.daysLeft} 天';
    final double? estimate = r.estimatedMonthlyInterest;
    final String tail = estimate == null
        ? '全额还清没有利息。'
        : '只还最低约 ${MoneyFormat.yuan0(r.minimumPayment)}，'
            '下个月大约会多出 ${MoneyFormat.yuan0(estimate)} 利息。'
            '$_kReminderDisclaimer';
    return Container(
      decoration: AppDecorations.card(context),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            AppIcons.schedule,
            size: AppIconSize.medium,
            color: context.tokens.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '你的「${r.cardName}」$when要还 '
              '${MoneyFormat.yuan0(r.amount)}，'
              '将从「${r.sourceName}」扣款。$tail',
              style: context.appText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// 账户页底部「再看看」：A2 趋势口径 + A3 名义金额口径 + 总账说明。
/// A1 两行「留够应急金 / 不上班能撑住」是情境设计的推算结果，
/// 不在记录页摆静态槽位（8.2 / 13.2）。
class _BoardNotes extends StatelessWidget {
  const _BoardNotes({required this.netWorthText});

  final String netWorthText;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Container(
          decoration: AppDecorations.card(context),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('再看看', style: context.appText.sectionHeader),
              const SizedBox(height: AppSpacing.sm),
              Text(_kTrendNote, style: context.appText.caption),
              const SizedBox(height: AppSpacing.xs),
              Text(_kNominalNote, style: context.appText.caption),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$_kFootNote\n目前按账户算：$netWorthText',
                style: context.appText.caption,
              ),
            ],
          ),
        ),
      );

}
