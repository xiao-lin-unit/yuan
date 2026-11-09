import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';

import '../../../commons/image/image_picker_widget.dart';

class UserAvatar extends StatelessWidget {
  final String? avatar;

  const UserAvatar({super.key, required this.avatar});

  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatar != null && avatar!.isNotEmpty;

    return SizedBox(
      width: _size,
      height: _size,
      child: hasAvatar
          ? SingleImagePickerWidget(
        initialBase64: avatar,
        enableUpload: false,          // 主页只展示，编辑走弹窗
        size: _size,                  // 与外层一致，不再需要 FittedBox 缩放
        shape: ImageShape.circle,
        onImageChanged: (_) {},
      )
          : ClipOval(
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(AppIcons.user, size: _size * 0.6),
        ),
      ),
    );
  }
}