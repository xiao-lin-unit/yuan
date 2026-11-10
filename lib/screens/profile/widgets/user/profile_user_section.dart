import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuan/screens/profile/widgets/user/user_avatar.dart';
import 'package:yuan/service/image/image_ref.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/app_typography.dart';
import 'package:yuan/styles/theme_tokens.dart';

import '../../../../database/user/user_info.dart';
import '../../../../service/user_controller.dart';
import '../../../commons/icons/app_icons.dart';
import '../../../commons/sheet/bottom_sheet.dart';
import 'edit_profile_sheet.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kCardPadding = AppSpacing.md + 2;
const double _kAvatarTextGap = AppSpacing.sm + 2;
const double _kNameSubGap = 3;
const int _kSubMaxLines = 2;

class ProfileUserSection extends StatelessWidget {
  const ProfileUserSection({super.key});

  Future<void> _openEdit(BuildContext context, UserInfo user) async {
    await showEditProfileSheet(
      context,
      initialName: user.username,
      initialSub: user.userSub,
      initialRef: user.avatarRef,
      onSave: (name, sub, avatar) async {
        await context.read<UserController>().updateProfile(
          username: name,
          userSub: sub,
          avatar: avatar,
        );
      },
    );
  }

  Future<void> showEditProfileSheet(
      BuildContext context, {
        required String initialName,
        required String initialSub,
        required ImageRef? initialRef,
        required Future<void> Function(String name, String sub, Object? avatar) onSave,
      }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final subCtrl = TextEditingController(text: initialSub);

    Object? tempAvatar = imageUndefined;

    await CommonBottomSheet.show(
      context,
      title: '编辑资料',
      showConfirmButton: true,
      onConfirm: () async {
        if (!context.mounted) return;
        final name = nameCtrl.text.trim();
        final sub = subCtrl.text.trim();

        if (name.isEmpty) {
          throw StateError('昵称不能为空');
        }
        await onSave(name, sub, tempAvatar);
      },
      child: EditProfileSheet(
        nameCtrl: nameCtrl,
        subCtrl: subCtrl,
        initialRef: initialRef,
        onAvatarChanged: (v) => tempAvatar = v,
      ),
    );

    nameCtrl.dispose();
    subCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserController>().user;
    final cs = Theme.of(context).colorScheme;
    final appText = context.appText;

    if (user == null) {
      return const SizedBox(height: AppLayout.listItemMinHeight + AppSpacing.lg);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Container(
        padding: const EdgeInsets.all(_kCardPadding),
        decoration: AppDecorations.card(context),
        child: Row(
          children: [
            UserAvatar(avatarRef: user.avatarRef),
            const SizedBox(width: _kAvatarTextGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username, style: appText.userName),
                  const SizedBox(height: _kNameSubGap),
                  Text(
                    user.userSub,
                    maxLines: _kSubMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: appText.userSub,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => unawaited(_openEdit(context, user)),
              tooltip: '编辑资料',
              icon: const Icon(AppIcons.edit),
              color: cs.onSurfaceVariant,
              constraints: const BoxConstraints.tightFor(
                width: kMinTapTarget,
                height: kMinTapTarget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
