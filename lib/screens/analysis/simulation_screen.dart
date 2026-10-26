import 'package:flutter/material.dart';
import 'simulation_result_screen.dart';

/// 情景推演：选择想试的情况
class SimulationScreen extends StatelessWidget {
  const SimulationScreen({super.key});

  static const _scenarios = <_Scenario>[
    _Scenario(icon: '💼', title: '如果失业了', subtitle: '看看手上的钱能撑几个月', kind: 'unemployment'),
    _Scenario(icon: '📉', title: '如果收入减少了', subtitle: '比如降薪20%，还能剩多少', kind: 'income_down'),
    _Scenario(icon: '📈', title: '如果收入增加了', subtitle: '比如涨薪，能多存多少', kind: 'income_up'),
    _Scenario(icon: '💳', title: '如果利率涨了', subtitle: '信用卡/贷款利息会多多少', kind: 'rate_up'),
    _Scenario(icon: '🏦', title: '如果提前还清一笔债', subtitle: '能省多少利息', kind: 'prepay'),
    _Scenario(icon: '🎲', title: '组合情景', subtitle: '同时发生好几件事会怎样', kind: 'combo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('情景推演')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('选一个你想试的情况：', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 12),
          ..._scenarios.map((s) => _ScenarioTile(
                scenario: s,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SimulationResultScreen(scenario: s),
                  ));
                },
              )).toList(),
          const SizedBox(height: 24),
          const Text('历史推演', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          const _HistoryTile(title: '失业推演', result: '可撑 5.2 个月', date: '10-20'),
          const _HistoryTile(title: '降薪推演', result: '结余 -¥200/月', date: '10-15'),
        ],
      ),
    );
  }
}

class _Scenario {
  final String icon, title, subtitle, kind;
  const _Scenario({required this.icon, required this.title, required this.subtitle, required this.kind});
}

class _ScenarioTile extends StatelessWidget {
  final _Scenario scenario;
  final VoidCallback onTap;
  const _ScenarioTile({required this.scenario, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(scenario.icon, style: const TextStyle(fontSize: 24)),
        title: Text(scenario.title),
        subtitle: Text(scenario.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String title, result, date;
  const _HistoryTile({required this.title, required this.result, required this.date});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.teal,
          child: Icon(Icons.history, color: Colors.white, size: 18),
        ),
        title: Text(title),
        subtitle: Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        trailing: Text(result, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
