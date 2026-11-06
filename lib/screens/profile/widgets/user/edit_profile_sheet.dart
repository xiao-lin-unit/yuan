import 'package:flutter/material.dart';

class EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController subCtrl;

  const EditProfileSheet({
    super.key,
    required this.nameCtrl,
    required this.subCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '昵称',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: subCtrl,
          decoration: const InputDecoration(
            labelText: '签名 / 说明',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}