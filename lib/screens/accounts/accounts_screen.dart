import 'package:flutter/material.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      body: const Center(
        child: Text('账户管理（待实现）', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}