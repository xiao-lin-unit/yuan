import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../database/ledger/az_db.dart';
import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../screens/commons/function/app_floating_actions.dart';
import '../../screens/commons/function/app_function_layout.dart';
import '../../screens/commons/function/app_detail_page.dart';
import '../../screens/commons/icons/app_icons.dart';
import '../../service/account_controller.dart';
import '../../service/ledger/az_controller.dart';
import '../../styles/app_decorations.dart';
import '../../styles/app_typography.dart';
import '../../styles/theme_tokens.dart';
import '../../utils/money_format.dart';
import 'az_sheets.dart';
import 'widgets/az_cards.dart';

/// 资产详情页（6.5 / 6.6 / 6.7 共用同一个框架）。
///
/// 【为什么用 AppDetailPage + AppFloatingActions】项目已有「资产 / 负债 /
/// 账户三类明细页共用」的公共框架与悬浮按钮组：头（返回 / 标题）、
/// 可滚动主体、右下角悬浮三件事都由布局决定，这里只填内容，不另写一套壳。
/// 原型里股票、基金、房子、车、借出款长得不一样，但骨架一致 —— 差异
/// 只体现在 [AppInfoGrid] 的行和买卖记录区，符合「通用 / 私有分开」。
///
/// 【静态优先】页面 StatelessWidget，所有数据来自 `context.watch`，没有
/// 本地状态；点按钮只做导航或打开 Sheet，写库全交给 AzWriteController。
class AssetDetailScreen extends StatelessWidget {
  const AssetDetailScreen({super.key, required this.assetId});

  final int assetId;

  @override
  Widget build(BuildContext context) {
    final AzController az = context.watch<AzController>();
    final AccountController accounts = context.watch<AccountController>();
    final AssetRecord? asset = az.assetById(assetId);
    if (asset == null) {
      return AppDetailPage(
        title: '找不到这一项',
        child: Center(
          child: Text('它可能已经进了回收站。', style: context.appText.body),
        ),
      );
    }

    final AzData d = az.data;
    final DateTime today = az.today;
    final List<AssetTradeRecord> trades = az.tradesFor(asset);
    final AzTradeSummary summary = AzMath.tradeSummary(trades);
    final double value = AzMath.assetValueOf(asset, d.preferences.valuationMode);
    final AzFlowTag tag = AzMath.flowTagOf(asset, d.activeLiabilities);
    final int staleDays = asset.valuedAt == null
        ? -1
        : today.difference(asset.valuedAt!).inDays;
    final String accountName = _accountName(accounts, asset.linkAccountId);
    final String debtName = az.liabilityById(asset.linkDebtId)?.name ?? '—';

    return AppDetailPage(
      title: asset.name,
      actions: <Widget>[
        IconButton(
          tooltip: '编辑',
          icon: const Icon(AppIcons.edit),
          onPressed: () => unawaited(
            showAzAssetSheet(context, existing: asset),
          ),
        ),
      ],
      floating: AppFloatingActions(
        actions: <AppFloatingAction>[
          AppFloatingAction(
            label: '更新一下现在值多少',
            icon: AppIcons.edit,
            emphasized: true,
            onPressed: () => unawaited(showAzValuationSheet(context, asset)),
          ),
          AppFloatingAction(
            label: '记一笔买入',
            icon: AppIcons.add,
            onPressed: () => unawaited(
              showAzTradeSheet(context, asset, TradeDirection.buy),
            ),
          ),
          AppFloatingAction(
            label: '记一笔卖出',
            icon: AppIcons.secondHand,
            onPressed: () => unawaited(
              showAzTradeSheet(context, asset, TradeDirection.sell),
            ),
          ),
          AppFloatingAction(
            label: '算不算进总账',
            icon: AppIcons.balanceAdjust,
            onPressed: () => unawaited(showAzCountedSheet(context, asset)),
          ),
          AppFloatingAction(
            label: '删除',
            icon: AppIcons.trash,
            onPressed: () => unawaited(
              showAzDeleteSheet(
                context,
                title: '把「${asset.name}」放进回收站？',
                description:
                    '${trades.length} 笔买卖记录会保留，30 天内可恢复。',
                onConfirm: () async {
                  await context.read<AzWriteController>().softDelete(
                        AzDb.assetsTable,
                        asset.id!,
                        '从资产详情页删除',
                      );
                  if (context.mounted) context.pop();
                },
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSummaryHero(
            label: asset.counted ? '现在按什么价算' : '这一项不算进总账',
            value: asset.counted ? MoneyFormat.yuan0(value) : '不算进总账',
            caption: staleDays < 0
                ? '按买入价算'
                : '$staleDays 天前填的',
            accent: tag.bad ? context.tokens.expense : null,
            secondary: <AppInfoItem>[
              AppInfoItem(
                label: '买它一共花了',
                value: MoneyFormat.yuan0(asset.cost),
              ),
              if (asset.latestValue != null)
                AppInfoItem(
                  label: '你填的最新价',
                  value: MoneyFormat.yuan0(asset.latestValue!),
                ),
            ],
          ),
          const SizedBox(height: AppLayout.sectionGap),
          AppInfoGrid(
            items: <AppInfoItem>[
              AppInfoItem(label: '属于哪类', value: asset.assetClass.label),
              AppInfoItem(label: '多久能变成现金', value: asset.liquidity.label),
              AppInfoItem(label: '这笔进账稳不稳', value: asset.stability.label),
              AppInfoItem(label: '它每月给你', value: MoneyFormat.yuan0(asset.monthlyIn)),
              AppInfoItem(label: '它每月要你花', value: MoneyFormat.yuan0(asset.monthlyOut)),
              AppInfoItem(label: '净流向', value: tag.text),
              AppInfoItem(label: '提前拿会扣', value: MoneyFormat.yuan0(asset.exitCost)),
              AppInfoItem(label: '算不算进总账', value: asset.counted ? '算' : '不算'),
              AppInfoItem(label: '钱从哪张卡出去的', value: accountName),
              AppInfoItem(label: '跟哪笔债有关', value: debtName),
              AppInfoItem(label: '值怎么来的', value: asset.valuationSource.label),
              AppInfoItem(label: '什么时候买的', value: _dateText(asset.createdAt)),
              if (asset.quantity != null)
                AppInfoItem(
                  label: '持有数量',
                  value: '${asset.quantity!.toStringAsFixed(2)} 份',
                ),
              if (asset.useMode.isNotEmpty)
                AppInfoItem(label: '自己住还是出租', value: asset.useMode),
              if (asset.depreciationNote.isNotEmpty)
                AppInfoItem(label: '这东西一年比一年不值钱', value: asset.depreciationNote),
            ],
          ),
          const SizedBox(height: AppLayout.sectionGap),
          AppFunctionSection(
            title: '买卖记录',
            child: trades.isEmpty
                ? const AzSmallEmpty('暂无买卖记录')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final AssetTradeRecord x in trades) ...<Widget>[
                        _tradeRow(context, x),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
          ),
          AppStatBar(
            items: <AppStatItem>[
              AppStatItem(
                label: '已经落袋的赚亏',
                value: MoneyFormat.yuan0(summary.realized),
              ),
              AppStatItem(
                label: '还没卖的，本钱',
                value: MoneyFormat.yuan0(summary.holdingCost),
              ),
              AppStatItem(
                label: '还没卖的数量',
                value: summary.holdingQuantity.toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (asset.countedReason.isNotEmpty)
            AzHint(asset.countedReason),
        ],
      ),
    );
  }

  Widget _tradeRow(BuildContext context, AssetTradeRecord x) {
    final t = context.tokens;
    final bool buy = x.direction == TradeDirection.buy;
    return Container(
      decoration: AppDecorations.item(context),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(
            buy ? AppIcons.add : AppIcons.secondHand,
            size: AppIconSize.medium,
            color: buy ? t.info : t.income,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${x.direction.label} ${x.quantity.toStringAsFixed(2)} 份 · '
                  '${_dateText(x.occurredAt)}',
                  style: context.appText.menuTitle,
                ),
                Text(
                  '单价 ${MoneyFormat.yuan(x.unitPrice)} · '
                  '另外${buy ? '交' : '扣'} ${MoneyFormat.yuan0(x.fee)}'
                  '${x.realizedPnl == null ? '' : ' · 这次赚 ${MoneyFormat.yuan0(x.realizedPnl!)}'}',
                  style: context.appText.caption,
                ),
              ],
            ),
          ),
          Text(
            MoneyFormat.yuan0(x.amount),
            style: context.appText.menuTitle.copyWith(
              color: buy ? t.expense : t.income,
            ),
          ),
        ],
      ),
    );
  }

  static String _accountName(AccountController accounts, int? id) {
    if (id == null) return '—（没关联）';
    for (final dynamic a in accounts.all) {
      if (a.id == id) return a.name as String;
    }
    return '原来那张卡已删除';
  }

  static String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
