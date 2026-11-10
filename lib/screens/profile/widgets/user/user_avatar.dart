import 'package:flutter/material.dart';

import '../../../commons/icons/app_icons.dart';
import '../../../../styles/theme_tokens.dart';
import '../../../commons/image/app_image.dart';
import 'package:yuan/service/image/image_ref.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kAvatarSize = 38;
const double _kPlaceholderIconRatio = 0.6;

class UserAvatar extends StatelessWidget {
  final ImageRef? avatarRef;

  const UserAvatar({super.key, required this.avatarRef});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return AppImage(
      ref: avatarRef,
      size: _kAvatarSize,
      shape: ImageShape.circle,
      placeholder: ClipOval(
        child: Container(
          color: tokens.field,
          alignment: Alignment.center,
          child: Icon(
            AppIcons.user,
            size: _kAvatarSize * _kPlaceholderIconRatio,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
