import 'package:flutter/material.dart';
import '../commons/icons/app_icons.dart';

import '../commons/empty/app_empty_state.dart';
import '../commons/scaffold/app_page_scaffold.dart';

// ── 页面私有内容 ───────────────────────────────────────────────
const String _kPageTitle = '资债';
const String _kEmptyTitle = '还没有流水记录';
const String _kEmptyDescription = '每一笔收支都会按时间汇总在这里。';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: _kPageTitle,
      scrollable: false,
      child: AppEmptyState(
        icon: AppIcons.ledger,
        title: _kEmptyTitle,
        description: _kEmptyDescription,
      ),
    );
  }
}
