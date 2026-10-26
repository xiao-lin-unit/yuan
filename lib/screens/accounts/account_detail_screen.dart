import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../models/money.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';

/// 账户明细页。展示账户信息 + 出入记录。
/// 出账：购物、缴费；入账：工资、转账；转账：账户间划转（不计入收支）。
class AccountDetailScreen extends StatefulWidget {
  final Account account;
  const AccountDetailScreen({super.key, required this.account});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late Future<_DetailData> _future;
  String _range = '本月';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final s = Services.instance;
    final acc = widget.account;
    final flows = await s.account.flows(acc.id);

    final now = DateTime.now();
    late DateTime start, end;
    switch (_range) {
      case '近3月':
        start = DateTime(now.year, now.month - 2, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case '全部':
        start = DateTime(2000);
        end = DateTime(2100);
        break;
      default: // 本月
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }

    final summary = await s.account.monthlyFlow(acc.id, now);

    // 按日期分组
    final grouped = <String, List<AccountFlow>>{};
    for (final f in flows) {
      if (f.occurredAt.isBefore(start) || f.occurredAt.isAfter(end)) continue;
      final key = '${f.occurredAt.year}-${f.occurredAt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(f);
    }

    return _DetailData(
      flows: flows,
      grouped: grouped,
      inflow: summary.$1,
      outflow: summary.$2,
      net: summary.$3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final acc = widget.account;
    final isCredit = acc.category == AccountCategory.credit;
    final color = isCredit ? Colors.red : (acc.isRestricted ? Colors.purple : Colors.blue);

    return Scaffold(
      appBar: AppBar(title: Text(acc.name)),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('加载失败'));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(account: acc, color: color),
              const SizedBox(height: 20),
              _InfoGrid(account: acc),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('出入记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '本月', label: Text('本月')),
                      ButtonSegment(value: '近3月', label: Text('近3月')),
                      ButtonSegment(value: '全部', label: Text('全部')),
                    ],
                    selected: {_range},
                    onSelectionChanged: (v) {
                      setState(() {
                        _range = v.first;
                        _reload();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FlowSummary(
                inflow: data.inflow,
                outflow: data.outflow,
                net: data.net,
              ),
              const SizedBox(height: 12),
              if (data.grouped.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('该时段暂无出入记录', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...data.grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                        child: Text(_monthLabel(entry.key),
                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                      ...entry.value.map((f) => _FlowTile(flow: f)),
                    ],
                  );
                }),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('跳转至收支录入页功能待实现')),
                    );
                  },
                  child: const Text('新增收支'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (isCredit) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('跳转至还款功能待实现')),
                      );
                    } else {
                      _openTransfer(context);
                    }
                  },
                  child: Text(isCredit ? '还款' : '转账'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTransfer(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountOperationsScreen(
        initialTab: 0,
        presetFromAccountId: widget.account.id,
      ),
    ));
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    return '${parts[0]}年${parts[1]}月';
  }
}

class _DetailData {
  final List<AccountFlow> flows;
  final Map<String, List<AccountFlow>> grouped;
  final Money inflow;
  final Money outflow;
  final Money net;
  const _DetailData({
    required this.flows,
    required this.grouped,
    required this.inflow,
    required this.outflow,
    required this.net,
  });
}

class _Header extends StatelessWidget {
  final Account account;
  final Color color;
  const _Header({required this.account, required this.color});

  @override
  Widget build(BuildContext context) {
    final acc = account;
    final isCredit = acc.category == AccountCategory.credit;
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
          Text(acc.type.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            AmountFormatter.plain(Money.fromDouble(isCredit ? acc.usedLimit : acc.balance)),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(isCredit ? '已用额度' : '当前余额',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (isCredit)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  _InfoChip(label: '总额度', value: '¥${acc.totalLimit.toStringAsFixed(0)}'),
                  const SizedBox(width: 12),
                  _InfoChip(label: '可用', value: '¥${acc.availableLimit.toStringAsFixed(0)}'),
                  const SizedBox(width: 12),
                  _InfoChip(
                      label: '账单日',
                      value: acc.billDay != null ? '每月${acc.billDay}号' : '-'),
                ],
              ),
            ),
          if (acc.isRestricted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  _InfoChip(label: '受限', value: acc.remark ?? '仅限绑定用途'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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

class _InfoGrid extends StatelessWidget {
  final Account account;
  const _InfoGrid({required this.account});

  @override
  Widget build(BuildContext context) {
    final acc = account;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3,
      children: [
        _InfoCell(label: '账户类型', value: acc.type.label),
        _InfoCell(label: '计入总资产', value: acc.countInTotal ? '是' : '否'),
        _InfoCell(
          label: '还款日',
          value: acc.paymentDay != null ? '每月${acc.paymentDay}号' : '-',
        ),
        _InfoCell(
          label: '关联还款账户',
          value: acc.linkedAccountId != null ? '已绑定' : '未绑定',
        ),
      ],
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

class _FlowSummary extends StatelessWidget {
  final Money inflow, outflow, net;
  const _FlowSummary({required this.inflow, required this.outflow, required this.net});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _FlowStat(label: '总入账', value: '+${AmountFormatter.plain(inflow)}', color: Colors.green)),
          Expanded(child: _FlowStat(label: '总出账', value: '-${AmountFormatter.plain(outflow)}', color: Colors.red)),
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

class _FlowTile extends StatelessWidget {
  final AccountFlow flow;
  const _FlowTile({required this.flow});

  @override
  Widget build(BuildContext context) {
    final isIn = flow.flowType == FlowType.inflow || flow.flowType == FlowType.adjustmentUp;
    final isTransfer = flow.relatedRecordType == 'transfer';
    final kind = isTransfer ? '转账' : (isIn ? '入账' : '出账');
    final color = isTransfer ? Colors.orange : (isIn ? Colors.green : Colors.red);
    final sign = isIn ? '+' : '-';
    final amount = Money.fromCents(flow.amountCents);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Text(isIn ? '↗' : '↘', style: TextStyle(fontSize: 18, color: color)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(flow.remark ?? kind, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isTransfer ? Colors.orange.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                kind,
                style: TextStyle(fontSize: 9, color: isTransfer ? Colors.orange[800] : Colors.grey[700]),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${_formatDate(flow.occurredAt)} · $kind',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          '$sign${AmountFormatter.plain(amount)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.month}-${d.day}';
  }
}
