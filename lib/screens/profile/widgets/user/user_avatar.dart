import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/image/app_image.dart';
import 'package:yuan/service/image/image_ref.dart';

class UserAvatar extends StatelessWidget {
  /// 统一图片引用，由 AppImage 负责解析与展示
  final ImageRef? avatarRef;

  const UserAvatar({super.key, required this.avatarRef});

  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    return AppImage(
      ref: avatarRef,
      size: _size,
      shape: ImageShape.circle,
      placeholder: ClipOval(
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(AppIcons.user, size: _size * 0.6),
        ),
      ),
    );
  }
}
