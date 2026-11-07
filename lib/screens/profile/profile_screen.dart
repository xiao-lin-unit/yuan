import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/user/profile_user_section.dart';
import 'widgets/function/profile_function_section.dart';
import 'widgets/manage/profile_manage_section.dart';
import 'widgets/about/profile_about_section.dart';

// 「我的」页面：组装用户 / 功能 / 管理 / 关于四个分区
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// 功能与管理共用的点击处理：按 key 跳转，路由未注册时不会崩
  void _onItemTap(BuildContext context, String? key) {
    if (key == null) return;
    final route = '/$key';
    try {
      context.push(route);
    } catch (_) {
      // 路由未注册时忽略，待 GoRouter 补上对应路由后即可跳转
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppStyles.bg,
      // appBar: AppBar(
      //   elevation: 0,
      // ),
      body: SafeArea(
        // 滚动视图
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ① 用户
              const ProfileUserSection(),
              // 间隔
              const SizedBox(height: 12),
              // ② 功能
              ProfileFunctionSection(
                // onItemTap: (item) => _onItemTap(context, item.key),
              ),
              // 间隔
              const SizedBox(height: 4),
              // ③ 管理
              ProfileManageSection(
                onItemTap: (item) => _onItemTap(context, item.key),
              ),
              // 间隔
              const SizedBox(height: 4),
              // ④ 关于
              ProfileAboutSection(
                onAboutTap: () => _onItemTap(context, 'about'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
