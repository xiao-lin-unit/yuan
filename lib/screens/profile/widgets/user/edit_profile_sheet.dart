import 'package:flutter/material.dart';

import '../../../commons/image/image_picker_widget.dart';

class EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController subCtrl;
  final String? initialAvatar;
  final ValueChanged<String?> onAvatarChanged;

  const EditProfileSheet({
    super.key,
    required this.nameCtrl,
    required this.subCtrl,
    required this.initialAvatar,
    required this.onAvatarChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // BottomSheet 高度无界，Column(mainAxisSize.min) 必须套一层 ScrollView
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          _FormRow(
            label: '头像',
            child: _AvatarField(
              initialBase64: initialAvatar,
              onAvatarChanged: onAvatarChanged,
            ),
          ),
          _FormRow(
            label: '名称',
            child: _TextField(
              controller: nameCtrl,
              hintText: '怎么称呼你？',
              maxLength: 12,
              textInputAction: TextInputAction.next,
            ),
          ),
          _FormRow(
            label: '描述',
            align: CrossAxisAlignment.start,
            child: _TextField(
              controller: subCtrl,
              hintText: '一句话介绍自己，例如：月薪族，正在攒钱买车',
              maxLength: 60,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.done,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 4),
            child: Text(
              '头像仅保存在本设备，不会上传云端。',
              textAlign: TextAlign.right,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行表单：左标签 72px + 右内容，底部分割线
class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;
  final CrossAxisAlignment align;

  static const double _labelWidth = 72;
  static const double _minHeight = 56;

  const _FormRow({
    required this.label,
    required this.child,
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.6),
          ),
        ),
      ),
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Row(
        crossAxisAlignment: align,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 头像：圆形 + 右下角相机角标
class _AvatarField extends StatelessWidget {
  final String? initialBase64;
  final ValueChanged<String?> onAvatarChanged;

  static const double _size = 48;

  const _AvatarField({
    required this.initialBase64,
    required this.onAvatarChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 必须钉死尺寸：Stack 在无界高度下会把 Infinity 透传给子元素
        SizedBox(
          width: _size,
          height: _size,
          child: SingleImagePickerWidget(
            initialBase64: initialBase64,
            enableUpload: true,
            size: _size,
            shape: ImageShape.circle,
            maxLongSide: 512,
            imageQuality: 85,
            maxFileSize: 2 * 1024 * 1024,
            allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
            onImageChanged: onAvatarChanged,
            placeholder: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: _size * 0.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),

        // 相机角标：IgnorePointer 让点击穿透到下面的头像
        // Positioned(
        //   right: -2,
        //   bottom: -2,
        //   child: IgnorePointer(
        //     child: Container(
        //       width: 22,
        //       height: 22,
        //       decoration: BoxDecoration(
        //         color: cs.primary,
        //         shape: BoxShape.circle,
        //         border: Border.all(color: cs.surface, width: 2),
        //       ),
        //       child: Icon(
        //         Icons.photo_camera_outlined,
        //         size: 12,
        //         color: cs.onPrimary,
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

/// 无边框输入框：右侧清除按钮，多行时底部显示字数
class _TextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final int maxLength;
  final int maxLines;
  final int minLines;
  final TextInputAction textInputAction;

  const _TextField({
    required this.controller,
    required this.hintText,
    required this.maxLength,
    required this.textInputAction,
    this.maxLines = 1,
    this.minLines = 1,
  });

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late int _length;

  @override
  void initState() {
    super.initState();
    _length = widget.controller.text.length;
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _length = widget.controller.text.length);

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final multiLine = widget.maxLines > 1;

    return Row(
      crossAxisAlignment:
      multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: widget.controller,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines,
                minLines: widget.minLines,
                textInputAction: widget.textInputAction,
                style: tt.bodyMedium,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withOpacity(0.6),
                  ),
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              if (multiLine) ...[
                const SizedBox(height: 4),
                Text(
                  '$_length/${widget.maxLength}',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 清除按钮：有内容才出现
        if (_length > 0)
          GestureDetector(
            onTap: () => widget.controller.clear(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Icon(
                Icons.cancel,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }
}