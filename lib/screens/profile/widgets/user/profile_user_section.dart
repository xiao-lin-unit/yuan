import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuan/screens/profile/widgets/user/user_avatar.dart';
import 'package:yuan/service/image/image_ref.dart';
import 'package:yuan/styles/theme_tokens.dart';

import '../../../../database/user/user_info.dart';
import '../../../../service/user_controller.dart';
import '../../../commons/sheet/bottom_sheet.dart';
import '../../../commons/styles/app_styles.dart';
import 'edit_profile_sheet.dart';

class ProfileUserSection extends StatelessWidget {
  const ProfileUserSection({super.key});

  // 打开编辑框操作
  Future<void> _openEdit(BuildContext context, UserInfo user) async {
    await showEditProfileSheet(
      context,
      initialName: user.username,
      initialSub: user.userSub,
      initialRef: user.avatarRef,
      onSave: (name, sub, avatar) async {
        // ✅ await 到底；异常上抛给 BottomSheet，保存失败时弹窗不关闭
        await context.read<UserController>().updateProfile(
          username: name,
          userSub: sub,
          avatar: avatar,
        );
      },
    );
  }

  // 展示 sheet 框
  Future<void> showEditProfileSheet(
      BuildContext context, {
        required String initialName,
        required String initialSub,
        required ImageRef? initialRef,
        required Future<void> Function(String name, String sub, Object? avatar) onSave,
      }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final subCtrl = TextEditingController(text: initialSub);

    // 统一哨兵：没动过 / 清空(null) / 新图(ImageCandidate)
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
          // 交给 BottomSheet 统一提示，保持弹窗打开且不重复弹 SnackBar
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

    if (user == null) {
      return const SizedBox(height: 80);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.pageHPadding,
        AppSpacing.xxs,
        AppStyles.pageHPadding,
        AppSpacing.xxs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: AppStyles.cardDecoration(context),
        child: Row(
          children: [
            UserAvatar(avatarRef: user.avatarRef),

            const SizedBox(width: AppSpacing.sm + 2),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: AppStyles.userNameStyle.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.userSub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.userSubStyle.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 矢量图标替代 emoji：跨设备字形一致、随主题取色、48dp 热区
            IconButton(
              onPressed: () => unawaited(_openEdit(context, user)),
              tooltip: '编辑资料',
              icon: const Icon(Icons.settings_outlined),
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
