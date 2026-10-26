import 'package:flutter/material.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资产负债')),
      body: const Center(
        child: Text('资产负债（待实现）', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}