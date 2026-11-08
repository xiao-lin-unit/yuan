import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuan/screens/profile/widgets/user/user_avatar.dart';

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
      onSave: (name, sub) {
        context.read<UserController>().updateProfile(
          username: name,
          userSub: sub,
        );
      },
    );
  }

  // 展示sheet框
  Future<void> showEditProfileSheet(
      BuildContext context, {
        required String initialName,
        required String initialSub,
        required void Function(String name, String sub) onSave,
      }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final subCtrl = TextEditingController(text: initialSub);

    await CommonBottomSheet.show(
      context,
      title: '编辑资料',
      showConfirmButton: true,
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        final sub = subCtrl.text.trim();

        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('昵称不能为空')),
          );
          return;
        }

        onSave(name, sub);
      },
      child: EditProfileSheet(
        nameCtrl: nameCtrl,
        subCtrl: subCtrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserController>().user;

    if (user == null) {
      return const SizedBox(height: 80); // 或 loading placeholder
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
            // 头像
            UserAvatar(base64: user.avatar),
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