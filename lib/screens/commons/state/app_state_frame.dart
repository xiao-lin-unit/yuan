import 'package:flutter/material.dart';

import '../../../styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
/// 内容列最大宽度。三态共用同一个值，居中的列宽一致才不会
/// 「空状态一段宽、错误态另一段宽」。只此一处使用，故留在私有常量区。
const double _kContentMaxWidth = 280;

/// 三态（empty / loading / error）**共用**的静态外框。
///
/// ── 为什么抽这一层 ────────────────────────────────────────────
/// 按项目分层规则「被 ≥2 个组件使用的样式上提」：三种状态都要
/// 同样的「整页留白 → 居中 → 限宽 280 → 竖向最小高度」，
/// 不抽就会在三个文件里各写一遍 Padding/Center/ConstrainedBox/Column。
/// 抽出来后改节奏只动这一处，三个状态同步。
///
/// ── 它是纯布局，不是状态管理 ──────────────────────────────────
/// [children] 由调用方（三个状态组件）在构造期给死，本组件不做任何
/// 运行时判定：无 enum、无 Notifier、无回调注册、无跨帧。
/// 「显示哪个状态」由使用方在页面里选组件决定，不在这里做控制。
///
/// 节奏（由上到下）：图标/进度徽章 → 24dp → 标题 → 8dp → 说明 →
/// 24dp → 操作。间距由各状态组件自己用 SizedBox 插入，本文件只管外框。
class AppStateFrame extends StatelessWidget {
  const AppStateFrame({super.key, required this.children});

  /// 纵向排列的内容。调用方负责按节奏插入 SizedBox。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
