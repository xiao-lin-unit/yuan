import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuan/screens/commons/sheet/app_sheet_shell.dart';
import 'package:yuan/screens/commons/sheet/contents/form_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
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
    // 结构（全部静态、构造期可读完）：
    //   header → SheetHeader(取消 / 标题 / 保存)，壳固定在顶端
    //   child  → EditProfileSheet，只声明表单项
    //
    // 【唯一一处动态逻辑】顶栏「保存」要触发 child 内部的提交链路
    // （校验 → await 写库 → 成功才关闭）。它必须留在 FormSheetContent
    // 内部（那里有 FormState / controller / 防连点标记），外部拿不到，
    // 所以用一个显式的 FormSheetController 句柄接起来：
    //   ① 这里 new 一个 controller；
    //   ② 同一个实例传给 header 的保存按钮和 EditProfileSheet；
    //   ③ 点保存 → controller.submit() → 内部 _submit()。
    // 完整工作逻辑写在 form_sheet_content.dart 的 FormSheetController
    // 注释里。没有 Notifier / InheritedWidget 提升 / 跨帧回调。
    final formController = FormSheetController();
    await AppSheetShell.show<SheetFormValues>(
      context,
      header: SheetHeader(
        title: '编辑资料',
        centered: true,
        leading: const SheetCancelAction(),
        trailing: SheetTextAction(
          label: '保存',
          emphasized: true,
          onTap: formController.submit,
        ),
      ),
      child: EditProfileSheet(
        initialName: initialName,
        initialSub: initialSub,
        initialRef: initialRef,
        onSave: onSave,
        controller: formController,
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
