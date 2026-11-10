import 'package:flutter/material.dart';
import '../commons/icons/app_icons.dart';

import '../commons/empty/app_empty_state.dart';
import '../commons/scaffold/app_page_scaffold.dart';

// ── 页面私有内容 ───────────────────────────────────────────────
const String _kPageTitle = '分析';
const String _kEmptyTitle = '暂时没有可分析的数据';
const String _kEmptyDescription = '积累一段时间的收支后，这里会呈现趋势与占比。';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: _kPageTitle,
      scrollable: false,
      child: AppEmptyState(
        icon: AppIcons.analysis,
        title: _kEmptyTitle,
        description: _kEmptyDescription,
      ),
    );
  }
}
