import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuan/screens/profile/widgets/user/user_avatar.dart';
import 'package:yuan/service/image/image_ref.dart';

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
    // 不再需要把文件路径读成 base64 —— 图片层自己会按引用展示。
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
        // 注意：不要传 GlobalObjectKey(UniqueKey())，
        // 每次 build 换新 key 会销毁 State，选的图会丢
        nameCtrl: nameCtrl,
        subCtrl: subCtrl,
        initialRef: initialRef,
        onAvatarChanged: (v) => tempAvatar = v,
      ),
    );

    // 弹窗关闭后释放控制器
    nameCtrl.dispose();
    subCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserController>().user;

    if (user == null) {
      return const SizedBox(height: 80);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.pageHPadding, 4, AppStyles.pageHPadding, 4,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppStyles.cardDecoration(context),
        child: Row(
          children: [
            // 头像：仅展示，禁止直接编辑
            UserAvatar(avatarRef: user.avatarRef),

            const SizedBox(width: 14),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username, style: AppStyles.userNameStyle),
                  const SizedBox(height: 3),
                  Text(user.userSub, style: AppStyles.userSubStyle),
                ],
              ),
            ),

            // 设置按钮
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openEdit(context, user),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('⚙️', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
