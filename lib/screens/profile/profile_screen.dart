import 'dart:async';

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

/// 当前已注册的二级页 key，与 router_shell.dart 里 ShellRoute 内部的
/// GoRoute 一一对应（路径为 `/profile/<key>`）。
///
/// 【为什么要有这张静态表】以前 _onItemTap 用 try/catch 包住 push，
/// 路由没注册时异常被吞掉，用户看到的就是「点了没反应」。现在改成
/// 构造期就能查表：不在表里 → 给明确提示；在表里 → 一定跳得过去。
///
/// 新增二级页时改两处（都是静态表，不做运行时反射）：
///   ① router_shell.dart 的 ShellRoute.routes 加一条 GoRoute；
///   ② 这里加一行 key。
const Set<String> _kRegisteredSubPages = <String>{'category'};

/// 「我的」页面：组装用户 / 功能 / 管理 / 关于四个分区。
/// 页面留白、滚动、宽屏限宽统一交给 AppPageScaffold，
/// 分区间距统一用 AppLayout.sectionGap（不再出现 12/4/4/24）。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// 【动态跳转，工作逻辑】
  ///   1. key 为空 → 不处理（数据项还没配 key）；
  ///   2. key 不在 [_kRegisteredSubPages] → SnackBar 明确提示「开发中」，
  ///      绝不静默失败；
  ///   3. 已注册 → `context.push('/profile/<key>')`。用 push 而不是 go，
  ///      是为了保留返回栈，分类管理页的 leading 用 context.pop() 回来；
  ///   4. push 返回 Future，工程开了 unawaited_futures，显式 unawaited。
  ///
  /// 页面仍在 ShellRoute 内，底导 / rail 靠 AppShell 的前缀匹配继续
  /// 高亮「我的」，键盘避让根开关不丢。
  void _onItemTap(BuildContext context, String? key) {
    if (key == null) return;
    if (!_kRegisteredSubPages.contains(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这个功能还在开发中')),
      );
      return;
    }
    unawaited(context.push('/profile/$key'));
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
