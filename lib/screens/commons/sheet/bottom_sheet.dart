import 'package:flutter/material.dart';

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // 滚动sheet
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (widget.enableDragToDismiss &&
                notification.extent <= notification.minExtent + 0.01) {
              Navigator.pop(context);
            }
            return false;
          },
          child: Container(
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                /// ===== 顶部栏 =====
                if (widget.title != null ||
                    widget.showCloseButton ||
                    widget.showConfirmButton)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        /// 关闭按钮
                        if (widget.showCloseButton)
                          IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.black54,
                            onPressed: () => Navigator.pop(context),
                          )
                        else
                          const SizedBox(width: 48),

                        /// 标题
                        Expanded(
                          child: widget.title == null
                              ? const SizedBox()
                              : Text(
                                  widget.title!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),

                        /// 保存按钮
                        if (widget.showConfirmButton)
                          TextButton(
                            onPressed: _saving ? null : _onConfirmPressed,
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(widget.confirmText,
                                    style: const TextStyle(
                                        color: Colors.black54)),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),

                const Divider(height: 1),

                /// ===== 内容区（可滚动） =====
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
