import 'package:flutter/material.dart';
import 'package:yuan/service/image/image_category.dart';
import 'package:yuan/service/image/image_ref.dart';
import 'package:yuan/styles/theme_tokens.dart';

import '../../../commons/image/image_picker_widget.dart';

class EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController subCtrl;

  /// 已持久化的图片引用，由统一图片组件自己解析展示
  final ImageRef? initialRef;

  /// ImageCandidate = 新图；null = 删除/清空
  final ValueChanged<Object?> onAvatarChanged;

  const EditProfileSheet({
    super.key,
    required this.nameCtrl,
    required this.subCtrl,
    required this.initialRef,
    required this.onAvatarChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // BottomSheet 高度无界，Column(mainAxisSize.min) 必须套一层 ScrollView
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        children: [
          _FormRow(
            label: '头像',
            child: _AvatarField(
              initialRef: initialRef,
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
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              right: AppSpacing.xxs,
            ),
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
  static const double _minHeight = 64;

  const _FormRow({
    required this.label,
    required this.child,
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final t = context.tokens;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.divider)),
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// 头像字段：只是「统一单图组件 + 一个业务分类」，没有任何头像专用逻辑。
class _AvatarField extends StatelessWidget {
  final ImageRef? initialRef;
  final ValueChanged<Object?> onAvatarChanged;

  static const double _size = 48;

  const _AvatarField({required this.initialRef, required this.onAvatarChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 必须钉死尺寸：Stack 在无界高度下会把 Infinity 透传给子元素
        SizedBox(
          width: _size,
          height: _size,
          child: SingleImagePickerWidget(
            initialRef: initialRef,
            enableUpload: true,
            category: ImageCategory.avatar,
            size: _size,
            shape: ImageShape.circle,
            onImageChanged: onAvatarChanged,
            placeholder: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.field, shape: BoxShape.circle),
              child: Icon(
                Icons.person,
                size: _size * 0.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 输入框：不再自己写 `InputBorder.none` + `contentPadding: zero`。
///
/// 旧版局部覆盖把主题的 filled 背景留着、边框去掉，结果是一块没有边界、
/// 文字贴边的深色矩形；聚焦时也没有任何视觉反馈。
/// 现在只传业务字段（hint / counter），容器、填充色、指示线、
/// 内外边距、错误态全部由 ThemeSetting.inputDecorationTheme 统一提供。
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
      crossAxisAlignment: multiLine
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
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
                style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  counterText: '',
                  alignLabelWithHint: multiLine,
                  // 刻意不覆盖 border / filled / fillColor / contentPadding
                ),
              ),
              if (multiLine) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '$_length/${widget.maxLength}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),

        // 清除按钮：48dp 热区 + 语义图标 + tooltip
        if (_length > 0)
          IconButton(
            onPressed: () => widget.controller.clear(),
            tooltip: '清空',
            icon: const Icon(Icons.close, size: 18),
            color: cs.onSurfaceVariant,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: kMinTapTarget,
              height: kMinTapTarget,
            ),
          ),
      ],
    );
  }
}
