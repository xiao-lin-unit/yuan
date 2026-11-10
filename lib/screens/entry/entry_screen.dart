import 'package:flutter/material.dart';
import '../commons/icons/app_icons.dart';

import '../commons/empty/app_empty_state.dart';
import '../commons/scaffold/app_page_scaffold.dart';

// ── 页面私有内容（只服务本页，样式一律走全局层）───────────────
const String _kPageTitle = '记账';
const String _kEmptyTitle = '还没有记过一笔';
const String _kEmptyDescription = '记下第一笔收支，账目从这里开始清晰起来。';

class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: _kPageTitle,
      scrollable: false,
      child: AppEmptyState(
        icon: AppIcons.entry,
        title: _kEmptyTitle,
        description: _kEmptyDescription,
      ),
    );
  }
}
