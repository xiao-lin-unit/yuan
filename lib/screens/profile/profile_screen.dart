import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../commons/scaffold/app_page_scaffold.dart';
import '../../styles/theme_tokens.dart';
import 'widgets/user/profile_user_section.dart';
import 'widgets/function/profile_function_section.dart';
import 'widgets/manage/profile_manage_section.dart';
import 'widgets/about/profile_about_section.dart';

// ── 页面私有内容 ───────────────────────────────────────────────
const double _kSectionGap = AppLayout.sectionGap;

/// 「我的」页面：组装用户 / 功能 / 管理 / 关于四个分区。
/// 页面留白、滚动、宽屏限宽统一交给 AppPageScaffold，
/// 分区间距统一用 AppLayout.sectionGap（不再出现 12/4/4/24）。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _onItemTap(BuildContext context, String? key) {
    if (key == null) return;
    // 二级功能页统一挂在「我的」分支下（/profile/xxx）：
    // AppShell 用前缀匹配保持底导高亮「我的」，且页面仍在 ShellRoute
    // 内，键盘避让的根开关不丢。未注册的 key 仍走原来的 catch 兜底。
    final route = '/profile/$key';
    try {
      context.push(route);
    } catch (_) {
      // 路由未注册时忽略，待 GoRouter 补上对应路由后即可跳转
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      showAppBar: false,
      padding: const EdgeInsets.fromLTRB(
        0,
        AppLayout.pageTop,
        0,
        AppLayout.pageBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileUserSection(),
          const SizedBox(height: _kSectionGap),
          const ProfileFunctionSection(),
          const SizedBox(height: _kSectionGap),
          ProfileManageSection(
            onItemTap: (item) => _onItemTap(context, item.key),
          ),
          const SizedBox(height: _kSectionGap),
          ProfileAboutSection(
            onAboutTap: () => _onItemTap(context, 'about'),
          ),
        ],
      ),
    );
  }
}
