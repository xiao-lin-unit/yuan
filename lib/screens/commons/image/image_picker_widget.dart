import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_picker_validator.dart';

/// 图片展示形态
enum ImageShape { rect, circle }

/// ================== 单图组件 ==================
class SingleImagePickerWidget extends StatefulWidget {
  final String? initialBase64;

  /// false = 纯预览，不显示上传/删除控件
  final bool enableUpload;

  final double size;
  final ImageShape shape;
  final double radius;

  /// 最长边限制：压缩与校验共用同一标准
  /// 传了它，就不要再传 maxWidth/maxHeight，否则会自己卡自己
  final double? maxLongSide;
  final int imageQuality;

  /// 业务校验（只校验格式 + 体积）
  final int? maxFileSize;
  final List<String>? allowedExtensions;

  /// 额外尺寸校验（一般不用，maxLongSide 已经保证过了）
  final int? minWidth;
  final int? minHeight;

  /// 无图且不可上传时的占位；不传则保持同尺寸空框
  final Widget? placeholder;

  final ValueChanged<String?> onImageChanged;

  const SingleImagePickerWidget({
    super.key,
    this.initialBase64,
    this.enableUpload = true,
    this.size = 80,
    this.shape = ImageShape.rect,
    this.radius = 8,
    this.maxLongSide,
    this.imageQuality = 90,
    this.maxFileSize,
    this.allowedExtensions,
    this.minWidth,
    this.minHeight,
    this.placeholder,
    required this.onImageChanged,
  });

  @override
  State<SingleImagePickerWidget> createState() => _SingleImagePickerWidgetState();
}

class _SingleImagePickerWidgetState extends State<SingleImagePickerWidget> {
  String? _base64;
  String? _lastAppliedInitial;
  bool _busy = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _base64 = widget.initialBase64;
    _lastAppliedInitial = widget.initialBase64;
  }

  @override
  void didUpdateWidget(covariant SingleImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有「外部值真的变了」且「与内部当前值不同」才采纳。
    // 否则父组件一次普通 rebuild 就会把用户刚选的图冲回旧值 → 表现为「选了没反应」
    if (widget.initialBase64 != _lastAppliedInitial &&
        widget.initialBase64 != _base64) {
      _base64 = widget.initialBase64;
      _lastAppliedInitial = widget.initialBase64;
    }
  }

  BorderRadius get _borderRadius => widget.shape == ImageShape.circle
      ? BorderRadius.circular(widget.size / 2)
      : BorderRadius.circular(widget.radius);

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    if (!widget.enableUpload || _busy) return;
    setState(() => _busy = true);

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: widget.maxLongSide,
        maxHeight: widget.maxLongSide,
        imageQuality: widget.imageQuality,
      );
      if (picked == null) return; // 用户取消，静默返回

      final result = await ImagePickerValidator.validateWithFile(
        file: File(picked.path),
        maxFileSize: widget.maxFileSize,
        allowedExtensions: widget.allowedExtensions,
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
        maxWidth: widget.maxLongSide?.toInt(),
        maxHeight: widget.maxLongSide?.toInt(),
      );

      if (!mounted) return;
      setState(() {
        _base64 = result.base64;
        _lastAppliedInitial = result.base64; // 同步，避免被 didUpdateWidget 判成外部变化
      });
      widget.onImageChanged(result.base64);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeImage() {
    setState(() {
      _base64 = null;
      _lastAppliedInitial = null;
    });
    widget.onImageChanged(null);
  }

  /// 上传控件：只在「无图 + 允许上传」时出现
  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _busy ? null : _pickImage,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: _borderRadius,
          border: Border.all(color: Colors.grey, width: 1),
          color: Colors.grey[50],
        ),
        child: _busy
            ? SizedBox(
          width: widget.size * 0.32,
          height: widget.size * 0.32,
          child: const CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _base64 != null && _base64!.isNotEmpty;

    // ① 有图 → 只展示图片 + 删除按钮，上传控件完全不渲染
    if (hasImage) {
      // 关键：Stack 必须有确定尺寸。
      // 原来用 StackFit.expand 会把父级 h=Infinity 透传给 ClipRRect → 断言崩溃
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none, // 允许删除按钮挂在边外
          children: [
            ClipRRect(
              borderRadius: _borderRadius,
              child: Image.memory(
                base64Decode(_base64!),
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                gaplessPlayback: true, // 换图不闪白
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image,
                  size: widget.size * 0.4,
                  color: Colors.red,
                ),
              ),
            ),
            if (widget.enableUpload)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: _removeImage,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // ② 无图 + 允许上传 → 上传控件
    if (widget.enableUpload) return _buildUploadBox();

    // ③ 无图 + 纯预览 → 占位，尺寸与有图时一致，布局不跳动
    return widget.placeholder ??
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipRRect(
            borderRadius: _borderRadius,
            child: Container(color: Colors.grey[100]),
          ),
        );
  }
}

/// ================== 多图组件 ==================
class MultiImagePickerWidget extends StatefulWidget {
  final List<String> initialBase64List;

  /// false = 纯预览
  final bool enableUpload;

  /// 最大图片数量
  final int maxCount;

  final double size;
  final ImageShape shape;
  final double radius;

  final double? maxLongSide;
  final int imageQuality;

  final int? maxFileSize;
  final List<String>? allowedExtensions;
  final int? minWidth;
  final int? minHeight;

  /// 满员时的占位（不传用内置禁用框）
  final Widget? fullPlaceholder;

  final ValueChanged<List<String>> onImagesChanged;

  const MultiImagePickerWidget({
    super.key,
    this.initialBase64List = const [],
    this.enableUpload = true,
    this.maxCount = 9,
    this.size = 80,
    this.shape = ImageShape.rect,
    this.radius = 8,
    this.maxLongSide,
    this.imageQuality = 90,
    this.maxFileSize,
    this.allowedExtensions,
    this.minWidth,
    this.minHeight,
    this.fullPlaceholder,
    required this.onImagesChanged,
  });

  @override
  State<MultiImagePickerWidget> createState() => _MultiImagePickerWidgetState();
}

class _MultiImagePickerWidgetState extends State<MultiImagePickerWidget> {
  late List<String> _list;
  bool _busy = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _list = List.unmodifiable(widget.initialBase64List);
  }

  @override
  void didUpdateWidget(covariant MultiImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBase64List != widget.initialBase64List) {
      _list = List.unmodifiable(widget.initialBase64List);
    }
  }

  bool get _isFull => _list.length >= widget.maxCount;

  BorderRadius get _borderRadius => widget.shape == ImageShape.circle
      ? BorderRadius.circular(widget.size / 2)
      : BorderRadius.circular(widget.radius);

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImages() async {
    if (!widget.enableUpload || _busy || _isFull) return;
    setState(() => _busy = true);

    try {
      final remain = widget.maxCount - _list.length;

      final pickedList = await _picker.pickMultiImage(
        maxWidth: widget.maxLongSide,
        maxHeight: widget.maxLongSide,
        imageQuality: widget.imageQuality,
      );
      if (pickedList.isEmpty) return;

      final selectedCount = pickedList.length;
      final added = <String>[];
      final errors = <String>[];

      for (final picked in pickedList.take(remain)) {
        try {
          final result = await ImagePickerValidator.validateWithFile(
            file: File(picked.path),
            maxFileSize: widget.maxFileSize,
            allowedExtensions: widget.allowedExtensions,
            minWidth: widget.minWidth,
            minHeight: widget.minHeight,
            maxWidth: widget.maxLongSide?.toInt(),
            maxHeight: widget.maxLongSide?.toInt(),
          );
          added.add(result.base64);
        } catch (e) {
          errors.add(e.toString()); // 单张失败不影响其余张
        }
      }

      if (!mounted) return;

      if (added.isNotEmpty) {
        setState(() => _list = List.unmodifiable([..._list, ...added]));
        widget.onImagesChanged(_list);
      }

      // 超量的必须告知用户，不能静默丢弃
      if (selectedCount > remain) {
        _showError(
          '最多上传 ${widget.maxCount} 张，本次仅添加 $remain 张，'
              '其余 ${selectedCount - remain} 张未添加',
        );
      } else if (errors.isNotEmpty) {
        _showError(errors.first);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeImage(int index) {
    final next = List<String>.from(_list)..removeAt(index);
    setState(() => _list = List.unmodifiable(next));
    widget.onImagesChanged(_list);
  }

  /// 可点击上传框
  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _busy ? null : _pickImages,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: _borderRadius,
          border: Border.all(color: Colors.grey, width: 1),
          color: Colors.grey[50],
        ),
        child: _busy
            ? SizedBox(
          width: widget.size * 0.32,
          height: widget.size * 0.32,
          child: const CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }

  /// 已满：禁用态占位，让用户知道「这里是上传区，但已经满了」
  Widget _buildDisabledBox() {
    return widget.fullPlaceholder ??
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
            color: Colors.grey[100],
          ),
          child: Icon(Icons.block, size: 22, color: Colors.grey[400]),
        );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    // ① 已上传图片，全部展示
    for (int i = 0; i < _list.length; i++) {
      final b64 = _list[i];
      children.add(
        // 同样必须钉死尺寸
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: _borderRadius,
                child: Image.memory(
                  base64Decode(b64),
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    size: widget.size * 0.4,
                    color: Colors.red,
                  ),
                ),
              ),
              if (widget.enableUpload)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => _removeImage(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // ② 未满 → 可点上传框；已满 → 禁用态占位
    if (widget.enableUpload) {
      children.add(_isFull ? _buildDisabledBox() : _buildUploadBox());
    }

    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}