import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../service/account_controller.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import '../commons/empty/app_empty_state.dart';
import '../commons/function/app_detail_page.dart';
import '../commons/function/app_floating_actions.dart';
import '../commons/function/app_function_layout.dart';
import '../commons/icons/app_icons.dart';
import '../commons/state/app_loading_state.dart';
import 'widgets/account_sheets.dart';

// ── 页面私有内容 ─────────────────────────────────────────────────
const String _kNotFoundTitle = '账户不存在';
const String _kNotFoundBody = '该账户可能已被归档或删除。';
const String _kLoading = '正在加载流水记录…';
const String _kLedgerTitle = '出入流水';
const String _kNoEntry =
    '暂无流水记录。记账、转账或余额调整后将在此显示。';

/// 账户明细页：二级功能页，用公共 [AppDetailPage]（**有标题、有返回**），
/// 与首页 [AccountsScreen] 的 [AppHomePage]（无标题无返回）明确分开。
/// 资产 / 负债详情页以后复用同一个 [AppDetailPage]，不再各写一套外壳。
///
/// ── 结构嵌套 ────────────────────────────────────────────────────
/// ```
/// AppShell（唯一 Scaffold）
///  └ AppDetailPage  ← 公共外部框架：头 / 主体 / 右下角悬浮三处位置
///     └ AppPageScaffold（骨架：固定头 → 滚动主体 → 悬浮层）
///        ├ header: AppDetailHeader  返回 / 标题 / 编辑·删除（固定）
///        ├ child:  Column           ← 主体，本页自己填
///        │   ├ AppSummaryHero       余额 或 已用额度
///        │   ├ AppInfoGrid          账户类型 / 计入总资产 / 关联还款 / 备注
///        │   └ AppFunctionSection → AppStatBar + AppLedgerList
///        └ floating: AppFloatingActions  ← ★ 操作下移到对应账户明细页
/// ```
///
/// 【动态状态，工作逻辑写清楚】
///   1. initState 调 `controller.loadDetail(id)`：同步段在第一次 build
///      之前就把 loading 标记置好，异步读完后由 Controller 通知重建；
///   2. Controller 里的 `_detailLoading / _detailEntries / _detailSummary`
///      是唯一真源，本页用 `context.watch` 按它切三态
///      （加载→AppLoadingState，空→AppEmptyState，有数据→列表）；
///   3. 任何写操作由 Controller 落库后重读并 notify，本页自动重建，
///      页面本身**不持有**列表副本、不手动 setState。
///   4. 流水按**交易时间**（不是录入时间）分组，见附录 C：用户可能月底
///      补记月初的账；分组只在这里做一次，通用件 AppLedgerList 只渲染。
class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final DateFormat _dayFormat = DateFormat('M月d日 · E', 'zh_CN');

  @override
  void initState() {
    super.initState();
    // 【为什么可以直接在这里调，不需要 addPostFrameCallback / microtask】
    // loadDetail 的同步段（置 _detailLoading / _detailAccountId）跑在第一次
    // build 之前，build 用 context.watch 读到的就是「加载中」；Controller
    // 不在同步段 notifyListeners，所以不会触发「build 阶段 markNeedsBuild」。
    // 加载完成那次通知在 await 之后，已离开 build 阶段。完整工作逻辑见
    // AccountController.loadDetail 的注释。
    unawaited(context.read<AccountController>().loadDetail(widget.accountId));
  }

  @override
  Widget build(BuildContext context) {
    final AccountController controller = context.watch<AccountController>();
    final AccountRecord? account = controller.byId(widget.accountId);

    if (account == null) {
      // 这里用「参数控制」形态：只传 title，公共框架自动补默认返回按钮。
      // 下面的正常分支用「内容控制」形态：直接传 AppDetailHeader 组件。
      return AppDetailPage(
        title: _kNotFoundTitle,
        child: const AppEmptyState(
          icon: AppIcons.warning,
          title: _kNotFoundTitle,
          description: _kNotFoundBody,
        ),
      );
    }

    return AppDetailPage(
      // 头作为组件直接传入；返回按钮用 AppDetailHeader 的默认值。
      header: AppDetailHeader(
        title: account.name,
        actions: <Widget>[
          IconButton(
            icon: const Icon(AppIcons.edit),
            tooltip: '编辑账户',
            onPressed: () => unawaited(
              showAccountEditorSheet(
                context,
                controller: controller,
                kind: account.kind,
                account: account,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(AppIcons.trash),
            tooltip: '删除账户',
            onPressed: () => unawaited(
              showAccountDeleteSheet(
                context,
                controller: controller,
                account: account,
              ),
            ),
          ),
        ],
      ),
      // 底部多留一个 FAB 的高度：右下角悬浮层不参与滚动区，
      // 不留白会把最后一条流水压在按钮下面。
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom + AppComponentSize.fabSize,
      ),
      // ★ 操作仍按账户类型下移到「对应账户下」，改由公共悬浮组渲染。
      floating: AppFloatingActions(
        actions: _floatingActions(context, controller, account),
      ),
      child: controller.detailLoading ||
              controller.detailAccountId != widget.accountId
          ? const AppLoadingState(message: _kLoading)
          : _content(context, controller, account),
    );
  }

  Widget _content(
    BuildContext context,
    AccountController controller,
    AccountRecord account,
  ) {
    final AccountEntrySummary? summary = controller.detailSummary;
    final List<AccountEntryRecord> entries = controller.detailEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _hero(context, controller, account),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: AppInfoGrid(items: _infoItems(controller, account)),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppFunctionSection(
          title: _kLedgerTitle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppStatBar(
                  items: <AppStatItem>[
                    AppStatItem(
                      label: '总入账',
                      value: MoneyFormat.yuan0(summary?.inbound ?? 0),
                    ),
                    AppStatItem(
                      label: '总出账',
                      value: MoneyFormat.yuan0(summary?.outbound ?? 0),
                    ),
                    AppStatItem(
                      label: '净变动',
                      value: MoneyFormat.yuan0(summary?.net ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        child: Text(
                          _kNoEntry,
                          style: context.appText.caption,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : AppLedgerList(groups: _groups(entries)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 摘要卡：信用卡显示「已用额度 / 总额度 + 额度条」，其余显示余额。
  Widget _hero(
    BuildContext context,
    AccountController controller,
    AccountRecord account,
  ) {
    if (account.kind == AccountKind.credit) {
      final double limit = account.creditLimit ?? 0;
      return AppSummaryHero(
        label: '已用额度 / 总额度',
        value: '${MoneyFormat.yuan0(account.balance)} / '
            '${MoneyFormat.orDash(account.creditLimit)}',
        caption: '可用 ${MoneyFormat.orDash(account.availableCredit)} · '
            '账单日每月 ${account.statementDay ?? "—"} 日 · '
            '还款日每月 ${account.dueDay ?? "—"} 日',
        progress: limit > 0 ? (account.balance / limit).clamp(0.0, 1.0) : 0,
        accent: context.tokens.warning,
        secondary: <AppInfoItem>[
          AppInfoItem(
            label: '可用额度',
            value: MoneyFormat.orDash(account.availableCredit),
          ),
          AppInfoItem(
            label: '最低还款（约）',
            value: MoneyFormat.yuan0(account.balance * account.minPaymentRate),
          ),
        ],
      );
    }
    return AppSummaryHero(
      label: '当前余额',
      value: MoneyFormat.yuan(account.balance),
      caption: account.kind == AccountKind.restricted
          ? '该账户资金有特定用途，记账时将按绑定用途过滤可选账户。'
          : '这是账户当前可用余额，每一笔变动均在下方留痕。',
      secondary: <AppInfoItem>[
        AppInfoItem(
          label: '初始余额',
          value: MoneyFormat.yuan0(account.initialBalance),
        ),
        AppInfoItem(
          label: '绑定用途',
          value: account.kind == AccountKind.restricted
              ? '${controller.bindingsOf(account.id!).length} 类'
              : '不限',
        ),
      ],
    );
  }

  List<AppInfoItem> _infoItems(
    AccountController controller,
    AccountRecord account,
  ) {
    final AccountRecord? repayTo = account.repayAccountId == null
        ? null
        : controller.byId(account.repayAccountId!);
    return <AppInfoItem>[
      AppInfoItem(
        label: '账户类型',
        value: '${account.kind.label} · ${account.type.label}',
      ),
      AppInfoItem(
        label: '计入资产合计',
        value: account.includeInNetWorth ? '是' : '否',
      ),
      AppInfoItem(
        label: account.kind == AccountKind.credit ? '还款账户' : '备注',
        value: account.kind == AccountKind.credit
            ? (repayTo?.name ?? '未设置')
            : (account.note.isEmpty ? '未填写' : account.note),
      ),
      AppInfoItem(
        label: '计入可用余额',
        value: account.isLiquid ? '是' : '否',
      ),
    ];
  }

  /// 按交易日期分组（附录 C）。entries 已由 DAO 按 occurred_at DESC 排好，
  /// LinkedHashMap 保持插入顺序，所以分组天然是从新到旧。
  List<AppLedgerGroupData> _groups(List<AccountEntryRecord> entries) {
    final Map<String, List<AppLedgerRowData>> grouped =
        <String, List<AppLedgerRowData>>{};
    for (final AccountEntryRecord e in entries) {
      final String label = _dayFormat.format(e.occurredAt);
      grouped.putIfAbsent(label, () => <AppLedgerRowData>[]).add(
            AppLedgerRowData(
              title: e.note.isEmpty ? e.entryType.label : e.note,
              subtitle: e.reason.isEmpty
                  ? '${e.entryType.label} · 变动后余额 ${MoneyFormat.yuan0(e.balanceAfter)}'
                  : '${e.entryType.label} · ${e.reason}',
              amountText: MoneyFormat.signed(e.direction, e.amount),
              icon: _entryIcon(e.entryType),
              positive: e.direction == AccountDirection.inbound,
            ),
          );
    }
    return <AppLedgerGroupData>[
      for (final MapEntry<String, List<AppLedgerRowData>> e in grouped.entries)
        AppLedgerGroupData(dateLabel: e.key, rows: e.value),
    ];
  }
}

IconData _entryIcon(AccountEntryType type) => switch (type) {
      AccountEntryType.opening => AppIcons.accountAdd,
      AccountEntryType.expense => AppIcons.category,
      AccountEntryType.income => AppIcons.salary,
      AccountEntryType.transferOut || AccountEntryType.transferIn =>
        AppIcons.transfer,
      AccountEntryType.adjustment => AppIcons.balanceAdjust,
      AccountEntryType.creditSpend => AppIcons.accountCreditCard,
      AccountEntryType.creditRepay => AppIcons.repay,
    };

/// ★ 操作配置：仍按账户类型下移到「对应账户下」，只是从底部固定区
/// 改到右下角悬浮组。
///
/// 纯数据：业务只声明「名称 / 图标 / 点击」，按钮样式、单按钮 / 多按钮
/// 形态、展开收起、名称提示全部交给公共 [AppFloatingActions]。
/// 列表顺序 = 展开后从上到下的顺序，最后一项最靠近主按钮。
/// 异步动作由调用方自己 `unawaited`（工程开了 unawaited_futures）。
List<AppFloatingAction> _floatingActions(
  BuildContext context,
  AccountController controller,
  AccountRecord account,
) =>
    <AppFloatingAction>[
      if (account.kind == AccountKind.liquid)
        AppFloatingAction(
          label: '账户转账',
          icon: AppIcons.transfer,
          onPressed: () => unawaited(
            showAccountTransferSheet(
              context,
              controller: controller,
              fromId: account.id,
            ),
          ),
        ),
      if (account.kind == AccountKind.credit) ...<AppFloatingAction>[
        AppFloatingAction(
          label: '还款',
          icon: AppIcons.repay,
          emphasized: true,
          onPressed: () => unawaited(
            showAccountRepaySheet(
              context,
              controller: controller,
              creditCard: account,
            ),
          ),
        ),
        AppFloatingAction(
          label: '额度调整',
          icon: AppIcons.creditLimit,
          onPressed: () => unawaited(
            showAccountCreditLimitSheet(
              context,
              controller: controller,
              account: account,
            ),
          ),
        ),
      ],
      if (account.kind == AccountKind.restricted)
        AppFloatingAction(
          label: '绑定用途',
          icon: AppIcons.binding,
          onPressed: () => unawaited(
            showAccountBindingsSheet(
              context,
              controller: controller,
              account: account,
            ),
          ),
        ),
      AppFloatingAction(
        label: '余额调整',
        icon: AppIcons.balanceAdjust,
        onPressed: () => unawaited(
          showAccountAdjustSheet(
            context,
            controller: controller,
            account: account,
          ),
        ),
      ),
      // 已归档的账户显示「恢复账户」，保证 3.7 / 10.7 可逆。
      AppFloatingAction(
        label: account.archived ? '恢复账户' : '归档账户',
        icon: account.archived ? AppIcons.unarchive : AppIcons.archive,
        onPressed: () => unawaited(
          showAccountArchiveSheet(
            context,
            controller: controller,
            account: account,
            archive: !account.archived,
          ),
        ),
      ),
    ];
