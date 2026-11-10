import 'package:flutter/material.dart';
import '../commons/icons/app_icons.dart';

import '../commons/empty/app_empty_state.dart';
import '../commons/scaffold/app_page_scaffold.dart';

// ── 页面私有内容 ───────────────────────────────────────────────
const String _kPageTitle = '账户';
const String _kEmptyTitle = '还没有添加账户';
const String _kEmptyDescription = '把银行卡、现金和钱包放在一起管理。';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: _kPageTitle,
      scrollable: false,
      child: AppEmptyState(
        icon: AppIcons.accounts,
        title: _kEmptyTitle,
        description: _kEmptyDescription,
      ),
    );
  }
}
