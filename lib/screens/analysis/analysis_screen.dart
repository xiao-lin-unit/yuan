import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/money.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';
import 'simulation_screen.dart';

/// 分析模块：结余、收支、分类占比、财务健康、情景推演。
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late Future<_AnalysisData> _future;
  DateTime _month = DateTime(2026, 10);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_AnalysisData> _load() async {
    final s = Services.instance;
    final (expense, income) = await s.transaction.monthlySummary(_month);
    final balance = Money.fromCents(income.cents - expense.cents);
    final overview = await s.summary.overview();
    final health = await s.health.report(_month);
    final breakdown = await s.summary.expenseBreakdown(_month);
    return _AnalysisData(
      expense: expense,
      income: income,
      balance: balance,
      overview: overview,
      health: health,
      breakdown: breakdown,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析'),
        actions: [
          TextButton(
            onPressed: () => _pickMonth(context),
            child: Text('${_month.year}-${_month.month.toString().padLeft(2, '0')} ▾'),
          ),
        ],
      ),
      body: FutureBuilder<_AnalysisData>(
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
              _BalanceCard(balance: data.balance),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SummaryMiniCard(label: '收入', value: AmountFormatter.plain(data.income), count: '', color: Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryMiniCard(label: '支出', value: AmountFormatter.plain(data.expense), count: '', color: Colors.red)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('花在哪了', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _CategoryBars(items: data.breakdown),
              const SizedBox(height: 24),
              const Text('你的财务健康', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _HealthCard(report: data.health),
              const SizedBox(height: 24),
              const Text('更多工具', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _ToolTile(
                icon: Icons.auto_awesome_motion,
                title: '情景推演',
                subtitle: '试试如果……会怎样',
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SimulationScreen(),
                  ));
                },
              ),
              const _ToolTile(
                icon: Icons.show_chart,
                title: '全年趋势',
                subtitle: '收支变化折线图（待实现）',
                onTap: null,
              ),
            ],
          );
        },
      ),
    );
  }

  void _pickMonth(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final now = DateTime.now();
        final months = List<DateTime>.generate(
          12,
          (i) => DateTime(now.year, now.month - i, 1),
        );
        return ListView(
          shrinkWrap: true,
          children: [
            for (final m in months)
              ListTile(
                title: Text('${m.year}年${m.month}月'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _month = m;
                    _reload();
                  });
                },
              ),
          ],
        );
      },
    );
  }
}

class _AnalysisData {
  final Money expense;
  final Money income;
  final Money balance;
  final BookOverview overview;
  final HealthReport health;
  final List<(String name, String icon, Money amount, double ratio)> breakdown;
  const _AnalysisData({
    required this.expense,
    required this.income,
    required this.balance,
    required this.overview,
    required this.health,
    required this.breakdown,
  });
}

class _BalanceCard extends StatelessWidget {
  final Money balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final positive = !balance.isNegative;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? [Colors.green[400]!, Colors.green[700]!]
              : [Colors.red[400]!, Colors.red[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本月结余', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            AmountFormatter.plain(balance),
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            positive ? '↑ 本月有结余，钱变多了' : '↓ 本月入不敷出，支出大于收入',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  final String label, value, count;
  final MaterialColor color;
  const _SummaryMiniCard({required this.label, required this.value, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (count.isNotEmpty)
            Text(count, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  final List<(String name, String icon, Money amount, double ratio)> items;
  const _CategoryBars({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || items.first.$3.isZero) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('本月暂无支出记录', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    // 取前 5 项
    final top = items.take(5).toList();
    return Column(
      children: top.map((it) {
        final color = _colorFor(it.$1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text('${it.$2} ${it.$1}', style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: it.$4,
                    backgroundColor: Colors.grey[200],
                    color: color,
                    minHeight: 16,
                  ),
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '${AmountFormatter.plain(it.$3)}  ${(it.$4 * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _colorFor(String name) {
    final map = {
      '餐饮': Colors.orange,
      '交通': Colors.blue,
      '买菜': Colors.green,
      '住房': Colors.brown,
      '水电': Colors.amber,
      '医疗': Colors.red,
      '服饰': Colors.purple,
      '娱乐': Colors.pink,
      '学习': Colors.indigo,
      '人情': Colors.teal,
      '金融': Colors.blueGrey,
    };
    return map[name] ?? Colors.grey;
  }
}

class _HealthCard extends StatelessWidget {
  final HealthReport report;
  const _HealthCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(report.grade);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gradeColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: gradeColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${report.score}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.grade.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('财务健康分 ${report.score}/100', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...report.risks.map((r) => _HealthRow(icon: '⚠️', color: Colors.orange, text: r)),
          ...report.suggestions.map((s) => _HealthRow(icon: '💡', color: Colors.blue, text: s)),
          if (report.risks.isEmpty && report.suggestions.isEmpty)
            const _HealthRow(icon: '✓', color: Colors.green, text: '当前财务状况健康，继续保持即可'),
        ],
      ),
    );
  }

  Color _gradeColor(HealthGrade g) {
    switch (g) {
      case HealthGrade.excellent:
        return Colors.green;
      case HealthGrade.good:
        return Colors.lightGreen;
      case HealthGrade.fair:
        return Colors.amber;
      case HealthGrade.warning:
        return Colors.orange;
      case HealthGrade.danger:
        return Colors.red;
    }
  }
}

class _HealthRow extends StatelessWidget {
  final String icon;
  final Color color;
  final String text;
  const _HealthRow({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  const _ToolTile({required this.icon, required this.title, required this.subtitle, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.12),
          child: Icon(icon, color: Colors.teal),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
