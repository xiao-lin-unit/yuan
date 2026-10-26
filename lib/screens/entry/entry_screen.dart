import 'package:flutter/material.dart';

class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记账')),
      body: const Center(
        child: Text('收支录入（待实现）', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}