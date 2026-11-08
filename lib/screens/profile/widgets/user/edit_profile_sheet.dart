import 'package:flutter/material.dart';

class EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController subCtrl;

  const EditProfileSheet({
    super.key,
    required this.nameCtrl,
    required this.subCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// 名称
        _LabeledField(
          label: '名称',
          maxLength: 12,
          controller: nameCtrl,
          hintText: '怎么称呼你？',
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: 16),

        /// 介绍
        _LabeledField(
          label: '介绍',
          maxLength: 60,
          controller: subCtrl,
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