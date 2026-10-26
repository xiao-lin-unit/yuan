import 'package:flutter/material.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分析')),
      body: const Center(
        child: Text('分析报表（待实现）', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}