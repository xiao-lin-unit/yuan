import 'package:flutter/material.dart';
import '../../../commons/image/image_picker_widget.dart';

class EditProfileSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController subCtrl;
  final String? initialAvatar;

  const EditProfileSheet({
    super.key,
    required this.nameCtrl,
    required this.subCtrl,
    required this.initialAvatar,
  });

  @override
  State<EditProfileSheet> createState() => EditProfileSheetState();
}

class EditProfileSheetState extends State<EditProfileSheet> {
  /// 临时头像：弹窗内所有改动只存在这里
  /// 确认才对外提交；关闭弹窗直接销毁，不会影响线上/本地原图
  String? tempAvatar;

  @override
  void initState() {
    super.initState();
    tempAvatar = widget.initialAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 头像选择区域
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: SingleImagePickerWidget(
              initialBase64: tempAvatar,
              enableUpload: true,
              size: 88,
              shape: ImageShape.circle,
              // 限制头像图片参数，防止超大图占用存储
              maxFileSize: 2 * 1024 * 1024,
              pickMaxWidth: 512,
              pickMaxHeight: 512,
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
              maxWidth: 512,
              maxHeight: 512,
              imageQuality: 85,
              onImageChanged: (b64) {
                setState(() {
                  tempAvatar = b64;
                });
              },
            ),
          ),
        ),

        /// 名称
        _LabeledField(
          label: '名称',
          maxLength: 12,
          controller: widget.nameCtrl,
          hintText: '怎么称呼你？',
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: 16),

        /// 介绍
        _LabeledField(
          label: '介绍',
          maxLength: 60,
          controller: widget.subCtrl,
          hintText: '一句话介绍自己，例如：月薪族，正在攒钱买车',
          textInputAction: TextInputAction.done,
          maxLines: 3,
        ),

        const SizedBox(height: 12),

        /// 本地提示
        Text(
          '头像仅保存在本设备，不会上传云端。',
          style: textTheme.bodySmall?.copyWith(
            color: color.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatefulWidget {
  final String label;
  final int maxLength;
  final TextEditingController controller;
  final String? hintText;
  final TextInputAction textInputAction;
  final int maxLines;

  const _LabeledField({
    required this.label,
    required this.maxLength,
    required this.controller,
    this.hintText,
    required this.textInputAction,
    this.maxLines = 1,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  late int _length;

  @override
  void initState() {
    super.initState();
    _length = widget.controller.text.length;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _length = widget.controller.text.length;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// label
        Text(
          widget.label,
          style: textTheme.labelMedium?.copyWith(
            color: color.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 8),

        /// input
        TextField(
          controller: widget.controller,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          textInputAction: widget.textInputAction,
          decoration: InputDecoration(
            hintText: widget.hintText,
            counterText: '', // 我们自己计数
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 4),

        /// counter
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$_length / ${widget.maxLength}',
            style: textTheme.bodySmall?.copyWith(
              color: color.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}