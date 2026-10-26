import 'package:flutter/material.dart';

import '../../models/asset.dart';
import '../../models/money.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';

/// 资产明细页。展示资产信息 + 资产出入记录。
/// 普通资产：借出/收回；股票：买入/卖出；基金：买入/卖出。
class AssetDetailScreen extends StatefulWidget {
  final dynamic asset;
  const AssetDetailScreen.normal({super.key, required Asset asset}) : asset = asset;
  const AssetDetailScreen.stock({super.key, required StockAsset asset}) : asset = asset;
  const AssetDetailScreen.fund({super.key, required FundAsset asset}) : asset = asset;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late Future<List<AssetTradeRecord>> _tradesFuture;

  AssetKind get _kind {
    final a = widget.asset;
    if (a is StockAsset) return AssetKind.stock;
    if (a is FundAsset) return AssetKind.fund;
    return AssetKind.normal;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final a = widget.asset;
    _tradesFuture = Services.instance.asset.trades(
      a is StockAsset
          ? a.id
          : a is FundAsset
              ? a.id
              : (a as Asset).id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    final isStock = kind == AssetKind.stock;
    final isFund = kind == AssetKind.fund;
    final color = isStock ? Colors.red : (isFund ? Colors.purple : Colors.green);

    return Scaffold(
      appBar: AppBar(title: Text(_name)),
      body: FutureBuilder<List<AssetTradeRecord>>(
        future: _tradesFuture,
        builder: (context, snapshot) {
          final trades = snapshot.data ?? const [];
          final inAmount = _sum(trades, TradeKind.sell); // 卖出/收回 = 资产减少（钱进来）
          final outAmount = _sum(trades, TradeKind.buy); // 买入/借出 = 资产增加（钱出去）
          final net = Money.fromCents(inAmount.cents - outAmount.cents);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(kind: kind, color: color),
              const SizedBox(height: 20),
              _InfoGrid(kind: kind),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('出入记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              _FlowSummary(
                inAmount: inAmount,
                outAmount: outAmount,
                net: net,
              ),
              const SizedBox(height: 12),
              if (trades.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('暂无出入记录', style: TextStyle(color: Colors.grey))),
                )
              else
                ...trades.map((t) => _TradeTile(trade: t)),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _buildActions(context, kind),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, AssetKind kind) {
    if (kind == AssetKind.stock) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showTradeDialog(context, true),
              child: const Text('记录买入'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showTradeDialog(context, false),
              child: const Text('记录卖出'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => _showPriceDialog(context),
              child: const Text('更新现价'),
            ),
          ),
        ],
      );
    }
    if (kind == AssetKind.fund) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showTradeDialog(context, true),
              child: const Text('记录买入'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showTradeDialog(context, false),
              child: const Text('记录卖出'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => _showPriceDialog(context),
              child: const Text('更新净值'),
            ),
          ),
        ],
      );
    }
    // 普通资产
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showLoanDialog(context, true),
            child: const Text('记录借出'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: () => _showLoanDialog(context, false),
            child: const Text('记录收回'),
          ),
        ),
      ],
    );
  }

  // ---------- 对话框 ----------

  void _showTradeDialog(BuildContext context, bool isBuy) {
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBuy ? '记录买入' : '记录卖出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _kind == AssetKind.stock ? '买入价格' : '买入净值',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _kind == AssetKind.stock ? '买入数量（股）' : '买入份额',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final price = double.tryParse(priceCtrl.text) ?? 0;
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (price <= 0 || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的价格和数量')),
                );
                return;
              }
              final s = Services.instance;
              if (_kind == AssetKind.stock) {
                final r = isBuy
                    ? await s.asset.recordStockBuy(
                        assetId: (widget.asset as StockAsset).id,
                        price: price,
                        quantity: qty,
                      )
                    : await s.asset.recordStockSell(
                        assetId: (widget.asset as StockAsset).id,
                        price: price,
                        quantity: qty,
                      );
                r.fold(
                  (_) {},
                  (msg) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                  ),
                );
              } else {
                final r = isBuy
                    ? await s.asset.recordFundBuy(
                        assetId: (widget.asset as FundAsset).id,
                        nav: price,
                        shares: qty,
                      )
                    : await s.asset.recordFundSell(
                        assetId: (widget.asset as FundAsset).id,
                        nav: price,
                        shares: qty,
                      );
                r.fold(
                  (_) {},
                  (msg) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                  ),
                );
              }
              if (mounted) {
                Navigator.pop(ctx);
                setState(_reload);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showPriceDialog(BuildContext context) {
    final ctrl = TextEditingController(
      text: _kind == AssetKind.stock
          ? (widget.asset as StockAsset).currentPrice.toString()
          : (widget.asset as FundAsset).currentNav.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_kind == AssetKind.stock ? '更新现价' : '更新净值'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _kind == AssetKind.stock ? '当前股价' : '当前净值',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text) ?? 0;
              if (v < 0) return;
              final s = Services.instance;
              if (_kind == AssetKind.stock) {
                await s.asset.refreshStockPrice((widget.asset as StockAsset).id, v);
              } else {
                await s.asset.refreshFundNav((widget.asset as FundAsset).id, v);
              }
              if (mounted) {
                Navigator.pop(ctx);
                setState(_reload);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showLoanDialog(BuildContext context, bool isLend) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLend ? '记录借出' : '记录收回'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '金额',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final amt = double.tryParse(ctrl.text) ?? 0;
              if (amt <= 0) return;
              final s = Services.instance;
              final r = isLend
                  ? await s.asset.recordLoanOut(
                      assetId: (widget.asset as Asset).id,
                      amount: Money.fromDouble(amt),
                    )
                  : await s.asset.recordLoanIn(
                      assetId: (widget.asset as Asset).id,
                      amount: Money.fromDouble(amt),
                    );
              r.fold(
                (_) {},
                (msg) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
                ),
              );
              if (mounted) {
                Navigator.pop(ctx);
                setState(_reload);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  // ---------- 数据访问 ----------

  String get _name {
    final a = widget.asset;
    if (a is StockAsset) return a.name;
    if (a is FundAsset) return a.name;
    return (a as Asset).name;
  }

  Money _sum(List<AssetTradeRecord> trades, TradeKind kind) {
    int cents = 0;
    for (final t in trades) {
      if (t.kind == kind) cents += t.amount.cents;
    }
    return Money.fromCents(cents);
  }

  // ---------- 头部 ----------
  Widget _Header({required AssetKind kind, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.7), color.withOpacity(0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_typeLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            AmountFormatter.plain(Money.fromDouble(_mainValue)),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(_valueLabel, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (kind == AssetKind.stock) ...[
            const SizedBox(height: 12),
            _StockHeaderChips(),
          ] else if (kind == AssetKind.fund) ...[
            const SizedBox(height: 12),
            _FundHeaderChips(),
          ],
        ],
      ),
    );
  }

  Widget _StockHeaderChips() {
    final s = widget.asset as StockAsset;
    return Row(
      children: [
        _InfoChip(label: '买入价', value: s.buyPrice.toStringAsFixed(2)),
        const SizedBox(width: 12),
        _InfoChip(label: '当前价', value: s.currentPrice.toStringAsFixed(2)),
        const SizedBox(width: 12),
        _InfoChip(label: '数量', value: '${s.buyQuantity}股'),
      ],
    );
  }

  Widget _FundHeaderChips() {
    final f = widget.asset as FundAsset;
    return Row(
      children: [
        _InfoChip(label: '确认净值', value: f.confirmNav.toStringAsFixed(4)),
        const SizedBox(width: 12),
        _InfoChip(label: '当前净值', value: f.currentNav.toStringAsFixed(4)),
        const SizedBox(width: 12),
        _InfoChip(label: '份额', value: f.shares.toStringAsFixed(0)),
      ],
    );
  }

  String get _typeLabel {
    switch (_kind) {
      case AssetKind.stock:
        return '股票';
      case AssetKind.fund:
        return '基金';
      default:
        return (widget.asset as Asset).subType.label;
    }
  }

  double get _mainValue {
    switch (_kind) {
      case AssetKind.stock:
        return (widget.asset as StockAsset).marketValue;
      case AssetKind.fund:
        return (widget.asset as FundAsset).marketValue;
      default:
        return (widget.asset as Asset).amount.yuan;
    }
  }

  String get _valueLabel {
    switch (_kind) {
      case AssetKind.stock:
        final s = widget.asset as StockAsset;
        final pl = s.profitLoss;
        return '盈亏 ${pl >= 0 ? '+' : ''}${pl.toStringAsFixed(2)}（${s.profitLossRatio >= 0 ? '+' : ''}${(s.profitLossRatio * 100).toStringAsFixed(1)}%）';
      case AssetKind.fund:
        final f = widget.asset as FundAsset;
        final cost = f.confirmNav * f.shares;
        final mv = f.marketValue;
        final pl = mv - cost;
        return '盈亏 ${pl >= 0 ? '+' : ''}${pl.toStringAsFixed(2)}';
      default:
        return '资产金额';
    }
  }

  // ---------- 信息网格 ----------
  Widget _InfoGrid({required AssetKind kind}) {
    final cells = <Widget>[];
    if (kind == AssetKind.stock) {
      final s = widget.asset as StockAsset;
      cells.addAll([
        _InfoCell(label: '股票名称', value: s.name),
        _InfoCell(label: '股票代码', value: s.code),
        _InfoCell(label: '关联账户', value: s.linkedAccountId ?? '-'),
        _InfoCell(label: '持仓市值', value: '¥${s.marketValue.toStringAsFixed(2)}'),
      ]);
    } else if (kind == AssetKind.fund) {
      final f = widget.asset as FundAsset;
      cells.addAll([
        _InfoCell(label: '基金名称', value: f.name),
        _InfoCell(label: '基金代码', value: f.code),
        _InfoCell(label: '份额', value: f.shares.toStringAsFixed(2)),
        _InfoCell(label: '持仓市值', value: '¥${f.marketValue.toStringAsFixed(2)}'),
      ]);
    } else {
      final a = widget.asset as Asset;
      cells.addAll([
        _InfoCell(label: '资产类型', value: a.subType.label),
        _InfoCell(label: '关联账户', value: a.linkedAccountId ?? '-'),
        _InfoCell(label: '计息方式', value: _calcLabel(a.calcType)),
        _InfoCell(label: '计入总资产', value: a.countInTotal ? '是' : '否'),
      ]);
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3,
      children: cells,
    );
  }

  String _calcLabel(AssetCalcType t) {
    switch (t) {
      case AssetCalcType.byYield:
        final a = widget.asset as Asset;
        return '按年收益率 ${(a.annualYieldRate * 100).toStringAsFixed(2)}%';
      case AssetCalcType.byAmount:
        return '按金额计算';
      default:
        return '不计算收益';
    }
  }

  // ---------- 出入记录 ----------
  Widget _FlowSummary({required Money inAmount, required Money outAmount, required Money net}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 买入/借出 = 资产侧出账（钱出去换资产）
          Expanded(child: _FlowStat(label: '总买入/借出', value: '-${AmountFormatter.plain(outAmount)}', color: Colors.green)),
          Expanded(child: _FlowStat(label: '总卖出/收回', value: '+${AmountFormatter.plain(inAmount)}', color: Colors.red)),
          Expanded(child: _FlowStat(
            label: '净变动',
            value: '${net.cents >= 0 ? '+' : '-'}${AmountFormatter.plain(net)}',
            color: Colors.blue,
          )),
        ],
      ),
    );
  }
}

enum AssetKind { normal, stock, fund }

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  const _InfoCell({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _FlowStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FlowStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _TradeTile extends StatelessWidget {
  final AssetTradeRecord trade;
  const _TradeTile({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.kind == TradeKind.buy;
    // 买入/借出 = 资产侧出账（绿色，钱出去了）
    final color = isBuy ? Colors.green : Colors.red;
    final kindText = isBuy ? '买入' : '卖出';
    final sign = isBuy ? '-' : '+';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Text(isBuy ? '↗' : '↘', style: TextStyle(fontSize: 18, color: color)),
        ),
        title: Row(
          children: [
            Text(trade.remark ?? kindText, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(kindText, style: TextStyle(fontSize: 9, color: Colors.grey[700])),
            ),
          ],
        ),
        subtitle: Text(
          '${_formatDate(trade.tradedAt)} · ${trade.price.toStringAsFixed(2)} × ${trade.quantity.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          '$sign${trade.amount.format()}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
