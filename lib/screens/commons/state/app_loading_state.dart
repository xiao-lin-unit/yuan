import 'package:flutter/material.dart';

import '../../../styles/app_typography.dart';
import '../../../styles/sheet_tokens.dart';
import '../../../styles/theme_tokens.dart';
import 'app_state_frame.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
/// 进度圈容器高度与空状态的图标徽章对齐，三态切换时视觉锚点不跳动。
const double _kIndicatorBoxSize = AppSheetSize.iconBadgeSize;
const double _kIndicatorSize = AppIconSize.empty;

/// 全软件统一的**加载态**。
///
/// 与 [AppEmptyState] / [AppErrorState] 共用 [AppStateFrame]，
/// 所以三种状态的留白、居中、列宽、竖向节奏完全一致。
/// 进度圈颜色走 ThemeData 的 progressIndicatorTheme（全局已注册），
/// 文字走 `context.appText.caption`，不写死任何 Color / fontSize。
///
/// 静态优先：本组件无状态、无 Future、无监听。它只负责「画一个加载态」；
/// 什么时候显示、什么时候切换，由使用方在页面里决定，不在这里控制。
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.message,
    this.cancelLabel = '取消',
    this.onCancel,
  });

  /// 可选说明文案，例如「正在读取账本…」。null 时只显示进度圈。
  final String? message;

  /// 可选取消按钮文案。只有 [onCancel] 非空时才会渲染按钮。
  final String cancelLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final text = context.appText;
    return AppStateFrame(
      children: <Widget>[
        // 固定 72dp 盒子：与 72dp 图标徽章等高，状态切换不产生位移。
        const SizedBox(
          width: _kIndicatorBoxSize,
          height: _kIndicatorBoxSize,
          child: Center(
            child: SizedBox(
              width: _kIndicatorSize,
              height: _kIndicatorSize,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
        if (message != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: text.caption,
          ),
        ],
        if (onCancel != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ],
      ],
    );
  }
}
