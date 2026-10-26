import 'package:flutter/material.dart';

import '../../models/liability.dart';
import '../../models/money.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';

/// 负债明细页。展示负债信息 + 还款记录 + 还款计划表。
class LiabilityDetailScreen extends StatefulWidget {
  final Liability liability;
  const LiabilityDetailScreen({super.key, required this.liability});

  @override
  State<LiabilityDetailScreen> createState() => _LiabilityDetailScreenState();
}

class _LiabilityDetailScreenState extends State<LiabilityDetailScreen> {
  late Future<_LiabilityDetailData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_LiabilityDetailData> _load() async {
    final s = Services.instance;
    final id = widget.liability.id;
    final schedule = await s.liability.getSchedule(id);
    final records = await s.liability.records(id);
    final totalRepaid = await s.liability.totalRepaid(id);

    // 已还/待还统计
    int paidPrincipalCents = 0;
    int pendingPrincipalCents = 0;
    int totalInterestCents = 0;
    for (final sp in schedule) {
      totalInterestCents += sp.interest.cents;
      if (sp.status == ScheduleStatus.paid) {
        paidPrincipalCents += sp.principal.cents;
      } else {
        pendingPrincipalCents += sp.principal.cents;
      }
    }

    return _LiabilityDetailData(
      schedule: schedule,
      records: records,
      totalRepaid: totalRepaid,
      paidPrincipal: Money.fromCents(paidPrincipalCents),
      pendingPrincipal: Money.fromCents(pendingPrincipalCents),
      totalInterest: Money.fromCents(totalInterestCents),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.liability;
    return Scaffold(
      appBar: AppBar(title: Text(l.name)),
      body: FutureBuilder<_LiabilityDetailData>(
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
              _Header(liability: l),
              const SizedBox(height: 20),
              _InfoGrid(liability: l),
              const SizedBox(height: 20),
              const Text('还款记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _FlowSummary(data: data),
              const SizedBox(height: 12),
              if (data.records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('暂无还款记录', style: TextStyle(color: Colors.grey))),
                )
              else
                ...data.records.map((r) => _RepayTile(record: r)),
              const SizedBox(height: 20),
              const Text('还款计划', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _ScheduleTable(schedule: data.schedule),
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
                  onPressed: () => _showRepayDialog(context),
                  child: const Text('记录还款'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _showEarlyRepay(context),
                  child: const Text('查看对应账户'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRepayDialog(BuildContext context) {
    final ctrl = TextEditingController(
      text: widget.liability.periodPayment.yuan.toStringAsFixed(2),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('记录还款'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '还款金额',
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
              final r = await s.liability.repay(
                liabilityId: widget.liability.id,
                amount: Money.fromDouble(amt),
                fromAccountId: widget.liability.linkedAccountId ?? '',
              );
              if (!mounted) return;
              r.fold(
                (updated) {
                  Navigator.pop(ctx);
                  setState(_reload);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已记录还款 ¥${amt.toStringAsFixed(2)}，剩余本金 ¥${updated.remainingPrincipal.yuan.toStringAsFixed(2)}')),
                  );
                },
                (msg) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                  );
                },
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showEarlyRepay(BuildContext context) async {
    final s = Services.instance;
    final saved = await s.liability.simulateEarlyRepay(
      liabilityId: widget.liability.id,
      extraAmount: widget.liability.remainingPrincipal,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提前还清可节省利息'),
        content: Text('若现在一次性还清，预计可节省利息 ${AmountFormatter.plain(saved)}。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }
}

class _LiabilityDetailData {
  final List<RepaymentSchedule> schedule;
  final List<RepaymentRecord> records;
  final Money totalRepaid;
  final Money paidPrincipal;
  final Money pendingPrincipal;
  final Money totalInterest;
  const _LiabilityDetailData({
    required this.schedule,
    required this.records,
    required this.totalRepaid,
    required this.paidPrincipal,
    required this.pendingPrincipal,
    required this.totalInterest,
  });
}

class _Header extends StatelessWidget {
  final Liability liability;
  const _Header({required this.liability});

  @override
  Widget build(BuildContext context) {
    final l = liability;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[400]!, Colors.red[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.type.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            AmountFormatter.plain(l.remainingPrincipal),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('剩余本金', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(label: '计息', value: l.isInterestBearing ? '是' : '否'),
              const SizedBox(width: 12),
              _InfoChip(label: '年利率', value: l.isInterestBearing ? '${(l.annualInterestRate * 100).toStringAsFixed(2)}%' : '-'),
              const SizedBox(width: 12),
              _InfoChip(label: '还款方式', value: l.repaymentMethod.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Liability liability;
  const _InfoGrid({required this.liability});

  @override
  Widget build(BuildContext context) {
    final l = liability;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3,
      children: [
        _InfoCell(label: '借款日期', value: _fmtDate(l.borrowDate)),
        _InfoCell(label: '到期日期', value: l.dueDate != null ? _fmtDate(l.dueDate!) : '未设'),
        _InfoCell(label: '绑定还款账户', value: l.linkedAccountId != null ? '已绑定' : '未绑定'),
        _InfoCell(
          label: '总期数',
          value: l.totalPeriods != null ? '${l.totalPeriods}期（已还${l.paidPeriods}期）' : '随借随还',
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _FlowSummary extends StatelessWidget {
  final _LiabilityDetailData data;
  const _FlowSummary({required this.data});

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
          Expanded(child: _FlowStat(label: '已还本金', value: AmountFormatter.plain(data.paidPrincipal), color: Colors.green)),
          Expanded(child: _FlowStat(label: '待还本金', value: AmountFormatter.plain(data.pendingPrincipal), color: Colors.red)),
          Expanded(child: _FlowStat(label: '利息合计', value: AmountFormatter.plain(data.totalInterest), color: Colors.orange)),
        ],
      ),
    );
  }
}

class _RepayTile extends StatelessWidget {
  final RepaymentRecord record;
  const _RepayTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.12),
          child: const Text('↘', style: TextStyle(fontSize: 18, color: Colors.green)),
        ),
        title: Text(record.remark ?? '还款', style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${_fmtDate(record.repaidAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          '-${record.amount.format()}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _ScheduleTable extends StatelessWidget {
  final List<RepaymentSchedule> schedule;
  const _ScheduleTable({required this.schedule});

  @override
  Widget build(BuildContext context) {
    if (schedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('随借随还类负债无固定还款计划', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 1, child: Text('期', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('到期', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('本金', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('利息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('状态', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          ...schedule.map(_scheduleTile),
        ],
      ),
    );
  }

  Widget _scheduleTile(RepaymentSchedule r) {
    Color statusColor;
    String statusText;
    switch (r.status) {
      case ScheduleStatus.paid:
        statusColor = Colors.green;
        statusText = '已还';
        break;
      case ScheduleStatus.overdue:
        statusColor = Colors.red;
        statusText = '逾期';
        break;
      default:
        statusColor = Colors.grey;
        statusText = '待还';
    }

    // 本期（下一期未还）高亮为橙色
    final isCurrent = r.status == ScheduleStatus.pending;
    final highlight = isCurrent && r.periodNumber == _nextPending(schedule);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? Colors.orange.withOpacity(0.08) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('${r.periodNumber}', style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(_fmtDate(r.dueDate), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(AmountFormatter.plain(r.principal), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text(AmountFormatter.plain(r.interest), style: TextStyle(fontSize: 12, color: Colors.orange[700]))),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: statusColor)),
            ),
          ),
        ],
      ),
    );
  }

  int _nextPending(List<RepaymentSchedule> list) {
    for (final s in list) {
      if (s.status == ScheduleStatus.pending) return s.periodNumber;
    }
    return -1;
  }

  String _fmtDate(DateTime d) {
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
