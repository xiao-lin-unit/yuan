import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../database/account/account_record.dart';
import '../../service/account_controller.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import '../commons/empty/app_empty_state.dart';
import '../commons/function/app_function_layout.dart';
import '../commons/home/app_home_page.dart';
import '../commons/icons/app_icons.dart';
import 'widgets/account_card.dart';
import 'widgets/account_sheets.dart';

// ── 页面私有文案（样式一律走全局层）─────────────────────────────
const String _kHeroLabel = '流动资金';
const String _kHeroCaption = '你当前可支配金额。';
const String _kEmptyTitle = '还没有添加账户';
const String _kEmptyDescription =
    '把银行卡、现金、微信零钱放进来，随时看清现在能花多少钱。';
const String _kGroupEmpty = '这里还没有账户，点右上角 ＋ 加一个。';
const String _kArchivedSection = '已归档账户';
const String _kFootNote =
    '「真正属于你的钱」会把所有账户加起来、再减去欠银行的钱。'
    '以后记进资产和借款后，这个数字会更完整。';

/// 【账户】= 底导直接打开的 5 个 Home 页之一。
///
/// ── 结构嵌套（本任务第 3 条，与分类管理页共用同一套结构层）──────
/// ```
/// AppShell（全局唯一 Scaffold + 断点导航 + 键盘根开关）
///  └ AppHomePage（★ Home 页专用：无标题、无返回、右上角只有 ＋）
///     ├ AppSummaryHero     现在能花的钱 + 大白话解释 + 两个副指标
///     ├ AppFunctionSection 流动资金账户 / 信用卡账户 / 其他资金账户
///     │   └ AccountCard（业务私有）
///     └ 底部大白话说明
/// ```
/// 与二级页（分类管理、账户明细）的差别只在「有没有标题栏」：
/// 导航栏已经说明这是「账户」页，顶上再放一行标题和返回是重复信息，
/// 所以这里连 AppBar 都不渲染，首屏第一块直接是数字。
///
/// ── 任务 4：三个操作下移 ────────────────────────────────────────
/// 原型首页底部的「账户转账 / 余额调整 / 归档账户」工具列表**已删除**。
/// 它们现在出现在每个账户的明细页底部，并且按账户类型给不同组合
/// （信用卡还有「还款 / 调整额度」，受限账户有「修改绑定用途」），
/// 符合设计原则第二条「用户想还信用卡，入口就在信用卡卡片上」。
///
/// 【动态状态，工作逻辑】本页是 **StatelessWidget**，零本地状态：
/// 账户数据全部来自 `context.watch<AccountController>()` 的内存快照；
/// 写操作由 Controller「await 落库 → load 重读 → notify」驱动本页重建。
/// 页面不另存一份列表，也不手动 setState。
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AccountController controller = context.watch<AccountController>();
    final AccountStats stats = controller.stats;
    final bool totallyEmpty = stats.accountCount == 0;

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
        child: AppSummaryHero(
          label: _kHeroLabel,
          value: MoneyFormat.yuan0(stats.spendable),
          caption: _kHeroCaption,
          secondary: <AppInfoItem>[
            AppInfoItem(
              label: '欠银行的钱',
              value: MoneyFormat.yuan0(stats.owedToBank),
            ),
            AppInfoItem(
              label: '一共',
              value: '${stats.accountCount} 个账户',
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (totallyEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: AppEmptyState(
                icon: AppIcons.accountAdd,
                title: _kEmptyTitle,
                description: _kEmptyDescription,
              ),
            )
          else ...<Widget>[
            for (final AccountKind kind in AccountKind.values)
              _section(context, controller, kind),
            if (controller.archived.isNotEmpty)
              _archivedSection(context, controller),
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

  Widget _section(
    BuildContext context,
    AccountController controller,
    AccountKind kind,
  ) {
    final List<AccountRecord> rows = controller.byKind(kind);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppFunctionSection(
        title: kind.label,
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  _kGroupEmpty,
                  style: context.appText.caption,
                ),
              )
            : Padding(
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
      ),
    );
  }

  /// 归档区：3.7 / 10.7「随时能恢复」。点卡片进明细页，那里底部按钮
  /// 会变成「恢复账户」，不需要另建一个回收站页面。
  Widget _archivedSection(
    BuildContext context,
    AccountController controller,
  ) {
    final List<AccountRecord> rows = controller.archived;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppFunctionSection(
        title: '$_kArchivedSection（${rows.length}）',
        child: Padding(
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
      ),
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
