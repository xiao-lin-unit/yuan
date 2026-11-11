import 'package:flutter/material.dart';

import '../../../styles/theme_tokens.dart';

/// 全软件统一的页面骨架，容器。
class AppPageScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool scrollable;
  final bool showAppBar;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  const AppPageScaffold({
    super.key,
    this.title,
    required this.child,
    this.scrollable = true,
    this.showAppBar = true,
    this.actions,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppLayout.pageTop,
          AppSpacing.md,
          AppLayout.pageBottom,
        );

    final Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.maxContentWidth,
        ),
        child: scrollable
            ? SingleChildScrollView(padding: effectivePadding, child: child)
            : Padding(padding: effectivePadding, child: child),
      ),
    );

    return Scaffold(
      appBar: showAppBar && title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
            )
          : null,
      body: SafeArea(child: content),
    );
  }
}
