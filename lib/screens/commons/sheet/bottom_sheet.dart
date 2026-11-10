import 'package:flutter/material.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const double _kDragHandleWidth = 32;
const double _kDragHandleHeight = 4;
const double _kProgressSize = 16;
const double _kInitialChildSize = 0.5;
const double _kMinChildSize = 0.25;
const double _kMaxChildSize = 0.9;

class CommonBottomSheet extends StatefulWidget {
  /// 标题（可为 null）
  final String? title;

  /// 内容
  final Widget child;

  /// 是否显示关闭按钮
  final bool showCloseButton;

  /// 是否显示确认按钮
  final bool showConfirmButton;

  /// 确认按钮文本
  final String confirmText;

  /// 确认回调（由使用方处理逻辑，抛异常 = 保存失败，弹窗不关闭）
  final Future<void> Function()? onConfirm;

  /// 点击遮罩是否关闭
  final bool barrierDismissible;

  final bool enableDragToDismiss;

  const CommonBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.showCloseButton = true,
    this.showConfirmButton = true,
    this.confirmText = '确认',
    this.onConfirm,
    this.barrierDismissible = true,
    this.enableDragToDismiss = true,
  });

  /// 快捷调用
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    bool showCloseButton = true,
    bool showConfirmButton = true,
    String confirmText = '确认',
    Future<void> Function()? onConfirm,
    bool barrierDismissible = true,
    bool enableDragToDismiss = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: barrierDismissible,
      enableDrag: enableDragToDismiss,
      builder: (_) => CommonBottomSheet(
        title: title,
        showCloseButton: showCloseButton,
        showConfirmButton: showConfirmButton,
        confirmText: confirmText,
        onConfirm: onConfirm,
        barrierDismissible: barrierDismissible,
        enableDragToDismiss: enableDragToDismiss,
        child: child,
      ),
    );
  }

  @override
  State<CommonBottomSheet> createState() => _CommonBottomSheetState();
}

class _CommonBottomSheetState extends State<CommonBottomSheet> {
  bool _saving = false;

  Future<void> _onConfirmPressed() async {
    if (_saving) return;
    if (widget.onConfirm == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onConfirm!();
      // ✅ 只有保存成功才关闭弹窗
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _kInitialChildSize,
      minChildSize: _kMinChildSize,
      maxChildSize: _kMaxChildSize,
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (widget.enableDragToDismiss &&
                notification.extent <= notification.minExtent + 0.01) {
              Navigator.pop(context);
            }
            return false;
          },
          child: SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              // 容器装饰统一由全局层提供（明暗/主题色一换全软件同步）
              decoration: AppDecorations.sheet(context),
              child: Column(
                children: [
                  // M3 拖拽把手：32×4，onSurfaceVariant 低透明
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                    child: Container(
                      width: _kDragHandleWidth,
                      height: _kDragHandleHeight,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.scrim),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  /// ===== 顶部栏 =====
                  if (widget.title != null ||
                      widget.showCloseButton ||
                      widget.showConfirmButton)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                      child: Row(
                        children: [
                          if (widget.showCloseButton)
                            IconButton(
                              icon: const Icon(Icons.close),
                              color: cs.onSurfaceVariant,
                              tooltip: '关闭',
                              onPressed: () => Navigator.pop(context),
                            )
                          else
                            const SizedBox(width: kMinTapTarget),

                          Expanded(
                            child: widget.title == null
                                ? const SizedBox()
                                : Text(
                                    widget.title!,
                                    textAlign: TextAlign.center,
                                    style: tt.titleMedium
                                        ?.copyWith(color: cs.onSurface),
                                  ),
                          ),

                          if (widget.showConfirmButton)
                            TextButton(
                              onPressed: _saving ? null : _onConfirmPressed,
                              child: _saving
                                  ? SizedBox(
                                      width: _kProgressSize,
                                      height: _kProgressSize,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    )
                                  : Text(
                                      widget.confirmText,
                                      style: tt.labelLarge
                                          ?.copyWith(color: cs.primary),
                                    ),
                            )
                          else
                            const SizedBox(width: kMinTapTarget),
                        ],
                      ),
                    ),

                  Divider(
                    color: t.divider,
                    height: 1,
                    thickness: AppBorder.thin,
                  ),

                  /// ===== 内容区（可滚动） =====
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
