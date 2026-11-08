import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';

class AvatarUploader extends StatefulWidget {
  final String? initialBase64;
  final ValueChanged<String?> onChanged;

  const AvatarUploader({
    super.key,
    this.initialBase64,
    required this.onChanged,
  });

  @override
  State<AvatarUploader> createState() => _AvatarUploaderState();
}

class _AvatarUploaderState extends State<AvatarUploader> {
  String? _base64;

  @override
  void initState() {
    super.initState();
    _base64 = widget.initialBase64;
  }

  Future<void> _pick() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_base64 != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('移除头像'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _base64 = null);
                  widget.onChanged(null);
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final b64 = base64Encode(bytes);

    setState(() => _base64 = b64);
    widget.onChanged(b64);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _pick,
      child: Row(
        children: [
          ClipOval(
            child: _base64 == null
                ? Container(
              width: 56,
              height: 56,
              color: color.surfaceContainerHighest,
              child: Icon(
                AppIcons.user,
                size: 32,
                color: color.onSurfaceVariant,
              ),
            )
                : Image.memory(
              base64Decode(_base64!),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _base64 == null ? '上传头像' : '更换头像',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '仅保存在本设备',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}