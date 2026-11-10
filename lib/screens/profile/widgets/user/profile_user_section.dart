import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuan/screens/commons/sheet/app_sheet_shell.dart';
import 'package:yuan/screens/commons/sheet/sheet_form_items.dart';
import 'package:yuan/screens/profile/widgets/user/user_avatar.dart';
import 'package:yuan/service/image/image_ref.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/app_typography.dart';
import 'package:yuan/styles/theme_tokens.dart';

import '../../../../database/user/user_info.dart';
import '../../../../service/user_controller.dart';
import '../../../commons/icons/app_icons.dart';
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
      onSave: (values) async {
        await context.read<UserController>().updateProfile(
              username: values.text('name').trim(),
              userSub: values.text('sub').trim(),
              avatar: values.raw('avatar'),
            );
      },
    );
  }

  Future<void> showEditProfileSheet(
    BuildContext context, {
    required String initialName,
    required String initialSub,
    required ImageRef? initialRef,
    required Future<void> Function(SheetFormValues values) onSave,
  }) async {
    // 旧实现：CommonBottomSheet + 外部 TextEditingController +
    // tempAvatar 临时变量 + 手写 onConfirm 校验。
    // 现在：外壳负责玻璃/把手/滚动/键盘避让，内容组件负责表单全部职责，
    // 这里只剩「把初始值传进去、把结果接出来」。
    await AppSheetShell.show<SheetFormValues>(
      context,
      child: EditProfileSheet(
        initialName: initialName,
        initialSub: initialSub,
        initialRef: initialRef,
        onSave: onSave,
      ),
    );
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
