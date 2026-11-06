import 'package:flutter/material.dart';
import 'edit_profile_sheet.dart';
import '../../../commons/app_styles.dart';
import '../../../commons/bottom_sheet.dart';

class ProfileUserSection extends StatefulWidget {
  final String avatar;
  final String userName;
  final String userSub;

  const ProfileUserSection({
    super.key,
    this.avatar = '👤',
    this.userName = '未设置名字',
    this.userSub = '📱 数据全部保存在本设备',
  });

  @override
  State<ProfileUserSection> createState() => _ProfileUserSectionState();
}

class _ProfileUserSectionState extends State<ProfileUserSection> {
  late String _avatar;
  late String _userName;
  late String _userSub;

  @override
  void initState() {
    super.initState();
    _avatar = widget.avatar;
    _userName = widget.userName;
    _userSub = widget.userSub;
  }

  Future<void> _openEdit() async {
    await showEditProfileSheet(
      context,
      initialName: _userName,
      initialSub: _userSub,
      onSave: (result) {
        setState(() {
          _userName = result['name']!;
          _userSub = result['sub']!;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.pageHPadding, 4, AppStyles.pageHPadding, 4,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppStyles.cardDecoration(context),
        child: Row(
          children: [
            Text(_avatar, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userName, style: AppStyles.userNameStyle),
                  const SizedBox(height: 3),
                  Text(_userSub, style: AppStyles.userSubStyle),
                ],
              ),
            ),
            // 齿轮：只有这里可点击
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _openEdit,
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

Future<void> showEditProfileSheet(
    BuildContext context, {
      required String initialName,
      required String initialSub,
      required ValueChanged<Map<String, String>> onSave,
    }) async {
  final nameCtrl = TextEditingController(text: initialName);
  final subCtrl = TextEditingController(text: initialSub);

  await CommonBottomSheet.show(
    context,
    title: '编辑资料',
    showCloseButton: true,
    showConfirmButton: true,
    enableDragToDismiss: true,
    onConfirm: () {
      final name = nameCtrl.text.trim();
      final sub = subCtrl.text.trim();

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('昵称不能为空')),
        );
        return;
      }

      onSave({
        'name': name,
        'sub': sub,
      });

      Navigator.pop(context);
    },
    child: EditProfileSheet(
      nameCtrl: nameCtrl,
      subCtrl: subCtrl,
    ),
  );
}