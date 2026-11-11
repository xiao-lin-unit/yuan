import 'package:flutter/material.dart';

import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../empty/app_empty_state.dart';
import '../icons/app_icons.dart';
import '../scaffold/app_page_scaffold.dart';
import '../state/app_error_state.dart';
import '../state/app_loading_state.dart';

// ── 页面私有内容 ───────────────────────────────────────────────
const String _kPageTitle = '三态骨架预览';

/// 每个示例块的固定高度：三态组件内部是「居中 + 最小高度」，
/// 放在滚动 Column 里必须给一个确定高度，否则 Center 拿不到约束。
const double _kBlockHeight = 240;

/// 三态骨架的可运行验证页（纯静态，无状态、无切换逻辑）。
///
/// 用法：临时挂一条 GoRoute 指向本页，肉眼确认三态的
/// 「徽章 → 标题 → 说明 → 操作」节奏、留白与列宽是否一致；
/// 再切主题色 / 明暗，确认三者同步变化。验证完删掉路由即可。
///
/// 这里不写状态切换（StatefulWidget / enum / Notifier）：
/// 按项目静态优先约定，预览页只是把三个组件并排摆出来，
/// 「什么时候显示哪一个」仍由业务页面自己决定。
class AppStatePreview extends StatelessWidget {
  const AppStatePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: _kPageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _PreviewBlock(
            label: '空状态 / empty',
            child: AppEmptyState(
              icon: AppIcons.analysis,
              title: '暂无数据',
              description: '记下第一笔账之后，这里会显示趋势。',
            ),
          ),
          const _PreviewBlock(
            label: '加载态 / loading',
            child: AppLoadingState(message: '正在读取账本…'),
          ),
          _PreviewBlock(
            label: '错误态 / error',
            // 示例里的重试按钮不做真实重试；业务使用时传入自己的回调。
            child: AppErrorState(
              title: '读取失败',
              description: '本地数据暂时无法读取，请稍后再试。',
              onRetry: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Text(label, style: context.appText.sectionHeader),
        ),
        SizedBox(height: _kBlockHeight, child: child),
        const Divider(),
      ],
    );
  }
}
