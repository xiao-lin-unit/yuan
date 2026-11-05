import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import '../profile_styles.dart';

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
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          initialName: _userName,
          initialSub: _userSub,
        ),
      ),
    );

    // 返回了数据才更新
    if (result != null) {
      setState(() {
        if (result['name']?.isNotEmpty == true) {
          _userName = result['name']!;
        }
        if (result['sub']?.isNotEmpty == true) {
          _userSub = result['sub']!;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileStyles.pageHPadding, 4, ProfileStyles.pageHPadding, 4,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: ProfileStyles.cardDecoration,
        child: Row(
          children: [
            Text(_avatar, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userName, style: ProfileStyles.userNameStyle),
                  const SizedBox(height: 3),
                  Text(_userSub, style: ProfileStyles.userSubStyle),
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