import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../service/account_controller.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import '../commons/empty/app_empty_state.dart';
import '../commons/function/app_function_layout.dart';
import '../commons/icons/app_icons.dart';
import '../commons/scaffold/app_page_scaffold.dart';
import '../commons/state/app_loading_state.dart';
import 'widgets/account_card.dart';
import 'widgets/account_sheets.dart';

// ── 页面私有内容 ─────────────────────────────────────────────────
const String _kNotFoundTitle = '找不到这个账户';
const String _kNotFoundBody = '它可能已经被归档或删除了。';
const String _kLoading = '正在翻这本流水账…';
const String _kLedgerTitle = '出入流水';
const String _kNoEntry = '还没有流水。记一笔、转账或调整余额后，这里就会一条条列出来。';

/// 账户明细页：二级功能页，用 [AppPageScaffold]（**有标题、有返回**），
/// 与首页 [AccountsScreen] 的 [AppHomePage]（无标题无返回）明确分开。
///
/// ── 结构嵌套 ────────────────────────────────────────────────────
/// ```
/// AppShell（唯一 Scaffold）
///  └ AppPageScaffold（标题/返回/编辑/删除 / 滚动内容 / 固定底部操作区）
///     ├ AppSummaryHero   余额 或 已用额度（通用结构件）
///     ├ AppInfoGrid      账户类型 / 计入总资产 / 关联还款 / 备注
///     ├ AppFunctionSection → AppStatBar（入账/出账/净变动）+ AppLedgerList
///     └ bottom: _AccountActions  ← ★ 任务 4：三个操作下移到这里
/// ```
///
/// 【动态状态，工作逻辑写清楚】
///   1. initState 调 `controller.loadDetail(id)` 读流水 + 汇总；
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
    // 加载明细快照；Controller 会 notify，build 里按 detailLoading 切三态。
    unawaited(context.read<AccountController>().loadDetail(widget.accountId));
  }

  @override
  Widget build(BuildContext context) {
    final AccountController controller = context.watch<AccountController>();
    final AccountRecord? account = controller.byId(widget.accountId);

    if (account == null) {
      return AppPageScaffold(
        title: _kNotFoundTitle,
        leading: _back(context),
        child: const AppEmptyState(
          icon: AppIcons.warning,
          title: _kNotFoundTitle,
          description: _kNotFoundBody,
        ),
      );
    }

    return AppPageScaffold(
      title: account.name,
      leading: _back(context),
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
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom,
      ),
      // ★ 固定底部：三个（或更多）操作按账户类型下移到「对应账户下」。
      bottom: _AccountActions(account: account, controller: controller),
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
            '账单日每月${account.statementDay ?? "—"}号 · '
            '还款日每月${account.dueDay ?? "—"}号',
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
          ? '这笔钱有特定用途，不能随便花；记账时下拉会自动按绑定用途过滤。'
          : '这是你卡里现在能用的钱。每一笔进出都在下面留了痕迹。',
      secondary: <AppInfoItem>[
        AppInfoItem(
          label: '开户时',
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
        label: '算进「真正属于你的钱」',
        value: account.includeInNetWorth ? '是' : '否',
      ),
      AppInfoItem(
        label: account.kind == AccountKind.credit ? '用哪张卡还款' : '备注',
        value: account.kind == AccountKind.credit
            ? (repayTo?.name ?? '还没选')
            : (account.note.isEmpty ? '没填' : account.note),
      ),
      AppInfoItem(
        label: '能自由花',
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
                  ? '${e.entryType.label} · 之后 ${MoneyFormat.yuan0(e.balanceAfter)}'
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

Widget _back(BuildContext context) => IconButton(
      icon: const Icon(AppIcons.chevronLeft),
      tooltip: '返回',
      onPressed: () => context.pop(),
    );

/// ★ 任务 4：操作下移到「对应类型的账户下」。
///
/// 首页那三个通用工具（转账 / 余额调整 / 归档）不再单独列一栏，
/// 而是在每张卡的明细页底部给出；并按类型补上原型里各自专属的入口：
///   · 流动资金 → 转账 / 余额调整 / 归档
///   · 信用卡   → 还款 / 调整额度 / 余额调整 / 归档（原型 floating-actions）
///   · 受限     → 修改绑定用途 / 余额调整 / 归档（原型公积金明细）
/// 纯静态：按钮组合由构造期传入的 account.kind 决定，组件不持状态。
class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.account, required this.controller});

  final AccountRecord account;
  final AccountController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            if (account.kind == AccountKind.liquid)
              _action(
                context,
                icon: AppIcons.transfer,
                label: '转账',
                onTap: () => showAccountTransferSheet(
                  context,
                  controller: controller,
                  fromId: account.id,
                ),
              ),
            if (account.kind == AccountKind.credit) ...<Widget>[
              _action(
                context,
                icon: AppIcons.repay,
                label: '立即还款',
                emphasized: true,
                onTap: () => showAccountRepaySheet(
                  context,
                  controller: controller,
                  creditCard: account,
                ),
              ),
              _action(
                context,
                icon: AppIcons.creditLimit,
                label: '调整额度',
                onTap: () => showAccountCreditLimitSheet(
                  context,
                  controller: controller,
                  account: account,
                ),
              ),
            ],
            if (account.kind == AccountKind.restricted)
              _action(
                context,
                icon: AppIcons.binding,
                label: '修改绑定用途',
                onTap: () => showAccountBindingsSheet(
                  context,
                  controller: controller,
                  account: account,
                ),
              ),
            _action(
              context,
              icon: AppIcons.balanceAdjust,
              label: '余额调整',
              onTap: () => showAccountAdjustSheet(
                context,
                controller: controller,
                account: account,
              ),
            ),
            // 已归档的账户显示「恢复账户」，保证 3.7 / 10.7 可逆。
            _action(
              context,
              icon: account.archived ? AppIcons.unarchive : AppIcons.archive,
              label: account.archived ? '恢复账户' : '归档账户',
              onTap: () => showAccountArchiveSheet(
                context,
                controller: controller,
                account: account,
                archive: !account.archived,
              ),
            ),
          ],
        ),
      );

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
    bool emphasized = false,
  }) =>
      SizedBox(
        height: AppComponentSize.chipHeight + AppSpacing.sm,
        child: emphasized
            ? FilledButton.icon(
                onPressed: () => unawaited(onTap()),
                icon: Icon(icon, size: AppIconSize.small),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: () => unawaited(onTap()),
                icon: Icon(icon, size: AppIconSize.small),
                label: Text(label),
              ),
      );
}
