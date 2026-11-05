import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialSub;

  const EditProfileScreen({
    super.key,
    this.initialName = '',
    this.initialSub = '',
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _subController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _subController = TextEditingController(text: widget.initialSub);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subController.dispose();
    super.dispose();
  }

  void _save() {
    // 把修改后的数据返回给上一页
    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'sub': _subController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                hintText: '输入你的名字',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subController,
              decoration: const InputDecoration(
                labelText: '个性签名',
                hintText: '比如：数据全部保存在本设备',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}