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
  /// 是否开启上传编辑，false仅预览
  final bool enableUpload;
  final double size;
  final ImageShape shape;
  final double radius;

  /// 选择图片时压缩参数（image_picker参数，并非校验阈值）
  final double? pickMaxWidth;
  final double? pickMaxHeight;
  final int imageQuality;

  /// 业务校验规则
  final int? maxFileSize;
  final List<String>? allowedExtensions;
  final int? minWidth;
  final int? minHeight;
  final int? maxWidth;
  final int? maxHeight;

  final ValueChanged<String?> onImageChanged;

  const SingleImagePickerWidget({
    super.key,
    this.initialBase64,
    this.enableUpload = true,
    this.size = 80,
    this.shape = ImageShape.rect,
    this.radius = 8,
    this.pickMaxWidth,
    this.pickMaxHeight,
    this.imageQuality = 90,
    this.maxFileSize,
    this.allowedExtensions,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    required this.onImageChanged,
  });

  @override
  State<SingleImagePickerWidget> createState() => _SingleImagePickerWidgetState();
}

class _SingleImagePickerWidgetState extends State<SingleImagePickerWidget> {
  String? _base64;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _base64 = widget.initialBase64;
  }

  @override
  void didUpdateWidget(covariant SingleImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBase64 != widget.initialBase64) {
      _base64 = widget.initialBase64;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    if (!widget.enableUpload) return;

    // 加载原图
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: widget.pickMaxWidth,
      maxHeight: widget.pickMaxHeight,
      imageQuality: widget.imageQuality
    );
    if (picked == null) return;

    try {
      final result = await ImagePickerValidator.validateWithFile(
        file: File(picked.path),
        maxFileSize: widget.maxFileSize,
        allowedExtensions: widget.allowedExtensions,
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      );
      setState(() => _base64 = result.base64);
      widget.onImageChanged(result.base64);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _removeImage() {
    setState(() => _base64 = null);
    widget.onImageChanged(null);
  }

  BorderRadius get _borderRadius => widget.shape == ImageShape.circle
      ? BorderRadius.circular(widget.size)
      : BorderRadius.circular(widget.radius);

  /// 公共上传占位框
  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: _borderRadius,
          border: Border.all(color: Colors.grey, width: 1),
          color: Colors.grey[50],
        ),
        child: const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 已有图片
    if (_base64 != null && _base64!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: _borderRadius,
            child: Image.memory(
              base64Decode(_base64!),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
            ),
          ),
          if (widget.enableUpload)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: _removeImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            )
        ],
      );
    }

    // 无图片
    if (widget.enableUpload) {
      return _buildUploadBox();
    }
    return const SizedBox.shrink();
  }
}

/// ================== 多图组件 ==================
class MultiImagePickerWidget extends StatefulWidget {
  final List<String> initialBase64List;
  final bool enableUpload;
  /// 最大图片数量
  final int maxCount;
  final double size;
  final ImageShape shape;
  final double radius;

  final double? pickMaxWidth;
  final double? pickMaxHeight;
  final int imageQuality;

  final int? maxFileSize;
  final List<String>? allowedExtensions;
  final int? minWidth;
  final int? minHeight;
  final int? maxWidth;
  final int? maxHeight;

  final ValueChanged<List<String>> onImagesChanged;

  const MultiImagePickerWidget({
    super.key,
    this.initialBase64List = const [],
    this.enableUpload = true,
    this.maxCount = 9,
    this.size = 80,
    this.shape = ImageShape.rect,
    this.radius = 8,
    this.pickMaxWidth,
    this.pickMaxHeight,
    this.imageQuality = 90,
    this.maxFileSize,
    this.allowedExtensions,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    required this.onImagesChanged,
  });

  @override
  State<MultiImagePickerWidget> createState() => _MultiImagePickerWidgetState();
}

class _MultiImagePickerWidgetState extends State<MultiImagePickerWidget> {
  late List<String> _list;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.initialBase64List);
  }

  @override
  void didUpdateWidget(covariant MultiImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBase64List != widget.initialBase64List) {
      _list = List.from(widget.initialBase64List);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImages() async {
    if (!widget.enableUpload) return;

    if (_list.length >= widget.maxCount) {
      _showError('最多只能上传 ${widget.maxCount} 张图片');
      return;
    }

    final pickedList = await _picker.pickMultiImage(
      maxWidth: widget.pickMaxWidth,
      maxHeight: widget.pickMaxHeight,
      imageQuality: widget.imageQuality,
    );

    if (pickedList.isEmpty) return;

    final remain = widget.maxCount - _list.length;
    final targetList = pickedList.take(remain).toList();

    final newBase64List = <String>[];
    final errors = <String>[];

    for (final picked in targetList) {
      try {
        final result = await ImagePickerValidator.validateWithFile(
          file: File(picked.path),
          maxFileSize: widget.maxFileSize,
          allowedExtensions: widget.allowedExtensions,
          minWidth: widget.minWidth,
          minHeight: widget.minHeight,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
        );
        newBase64List.add(result.base64);
      } catch (e) {
        errors.add(e.toString());
      }
    }

    if (errors.isNotEmpty) {
      _showError(errors.first);
    }

    if (newBase64List.isNotEmpty) {
      setState(() {
        _list = [..._list, ...newBase64List];
      });
      widget.onImagesChanged(_list);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _list = List.from(_list)..removeAt(index);
    });
    widget.onImagesChanged(_list);
  }

  BorderRadius get _borderRadius => widget.shape == ImageShape.circle
      ? BorderRadius.circular(widget.size)
      : BorderRadius.circular(widget.radius);

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: _borderRadius,
          border: Border.all(color: Colors.grey, width: 1),
          color: Colors.grey[50],
        ),
        child: const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    // 已上传图片
    for (int i = 0; i < _list.length; i++) {
      final b64 = _list[i];
      children.add(
        Stack(
          children: [
            ClipRRect(
              borderRadius: _borderRadius,
              child: Image.memory(
                base64Decode(b64),
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
              ),
            ),
            if (widget.enableUpload)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              )
          ],
        ),
      );
    }

    // 上传占位框，达到最大数量自动隐藏
    if (widget.enableUpload && _list.length < widget.maxCount) {
      children.add(_buildUploadBox());
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}