import 'package:flutter/material.dart';
import '../../utils/amount_formatter.dart';
import 'simulation_screen.dart';

/// 情景推演结果页。展示核心结论 + 逐月消耗 + 改善建议。
class SimulationResultScreen extends StatefulWidget {
  final _Scenario scenario;
  const SimulationResultScreen({super.key, required this.scenario});

  @override
  State<SimulationResultScreen> createState() => _SimulationResultScreenState();
}

class _SimulationResultScreenState extends State<SimulationResultScreen> {
  // 失业推演参数
  double _monthlyExpense = 3500;
  double _cashOnHand = 8320;
  int _unemploymentMonths = 6;

  @override
  Widget build(BuildContext context) {
    // 计算：可维持月数
    final months = (_cashOnHand / _monthlyExpense);
    final fullMonths = months.floor();
    final gap = _monthlyExpense * 3 - _cashOnHand; // 3个月应急金缺口

    return Scaffold(
      appBar: AppBar(title: Text(widget.scenario.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 参数输入
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('你告诉我的：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                _ParamRow(
                  label: '每月必要花销',
                  value: '¥${_monthlyExpense.toStringAsFixed(0)}',
                  onMinus: () => setState(() {
                    if (_monthlyExpense > 500) _monthlyExpense -= 500;
                  }),
                  onPlus: () => setState(() => _monthlyExpense += 500),
                ),
                const SizedBox(height: 8),
                _ParamRow(
                  label: '手上能动的钱',
                  value: '¥${_cashOnHand.toStringAsFixed(0)}',
                  onMinus: () => setState(() {
                    if (_cashOnHand > 1000) _cashOnHand -= 1000;
                  }),
                  onPlus: () => setState(() => _cashOnHand += 1000),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 核心结论
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[400]!, Colors.teal[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('结果', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  '你的钱能撑约 $fullMonths 个月',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 逐月消耗
          const Text('逐月消耗', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...List.generate(fullMonths + 1, (i) {
            final remaining = _cashOnHand - _monthlyExpense * i;
            final isLast = i == fullMonths;
            return _MonthTile(
              month: '第${i + 1}个月末',
              remaining: remaining,
              isWarning: isLast,
            );
          }),
          _MonthTile(
            month: '第${fullMonths + 1}个月中',
            remaining: -(_monthlyExpense - (_cashOnHand - _monthlyExpense * fullMonths)),
            isWarning: true,
            label: '钱花光了',
          ),
          const SizedBox(height: 20),
          // 建议
          const Text('建议', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· 紧急备用金建议至少留 ¥${(_monthlyExpense * 3).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12)),
                Text('· 目前缺口 ¥${gap.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12)),
                const Text('· 可削减的弹性支出约 ¥800/月',
                    style: TextStyle(fontSize: 12)),
                Text('· 削减后可将支撑时间延长至 ${(months + 800 / _monthlyExpense).toStringAsFixed(1)} 个月',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _monthlyExpense = 3500;
                    _cashOnHand = 8320;
                  }),
                  child: const Text('调整参数再试'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已保存这次推演')),
                    );
                  },
                  child: const Text('保存这次推演'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  final String label, value;
  final VoidCallback onMinus, onPlus;
  const _ParamRow({required this.label, required this.value, required this.onMinus, required this.onPlus});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(onPressed: onMinus, icon: const Icon(Icons.remove, size: 16), padding: const EdgeInsets.all(4)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(onPressed: onPlus, icon: const Icon(Icons.add, size: 16), padding: const EdgeInsets.all(4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthTile extends StatelessWidget {
  final String month;
  final double remaining;
  final bool isWarning;
  final String? label;
  const _MonthTile({required this.month, required this.remaining, this.isWarning = false, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.withOpacity(0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: isWarning ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Expanded(child: Text(month, style: TextStyle(fontSize: 13, color: isWarning ? Colors.red : null))),
          if (label != null)
            Text(label!, style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
          Text(
            '剩 ¥${remaining.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              color: isWarning ? Colors.red : Colors.grey[700],
              fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
