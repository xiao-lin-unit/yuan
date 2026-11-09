import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yuan/service/image/image_category.dart';
import 'package:yuan/service/image/image_policy.dart';
import 'package:yuan/service/image/image_ref.dart';
import 'package:yuan/service/image/image_validator.dart';

import 'app_image.dart';

// 兼容旧 import：ImageShape 现在由统一展示组件定义
export 'app_image.dart' show ImageShape, AppImage;

/// ================== 单图组件 ==================
///
/// 输入：已存图片的 [initialRef]（由统一展示组件渲染）
/// 输出：[imageUndefined] 不会出现；[ImageCandidate] = 换了新图，null = 清空
///
/// 组件只管「选 + 预览」，压缩/校验走 ImagePolicy，落盘由业务层
/// 调 ImageService 完成 —— 组件本身永不碰数据库、永不拼路径。
class SingleImagePickerWidget extends StatefulWidget {
  /// 已持久化的图片引用
  final ImageRef? initialRef;

  /// false = 纯预览，不显示上传/删除控件
  final bool enableUpload;

  /// 决定压缩尺寸、画质、体积、格式上限
  final ImageCategory category;

  final double size;
  final ImageShape shape;
  final double radius;

  /// 无图且不可上传时的占位
  final Widget? placeholder;

  /// ImageCandidate = 新图；null = 删除/清空
  final ValueChanged<Object?> onImageChanged;

  const SingleImagePickerWidget({
    super.key,
    this.initialRef,
    this.enableUpload = true,
    this.category = ImageCategory.avatar,
    this.size = 80,
    this.shape = ImageShape.rect,
    this.radius = 8,
    this.placeholder,
    required this.onImageChanged,
  });

  @override
  State<SingleImagePickerWidget> createState() =>
      _SingleImagePickerWidgetState();
}

class _SingleImagePickerWidgetState extends State<SingleImagePickerWidget> {
  ImageCandidate? _candidate;

  /// true = 用户主动删掉/清空了已有图，此时不再回显 initialRef
  bool _cleared = false;

  bool _busy = false;
  final ImagePicker _picker = ImagePicker();

  ImagePolicy get _policy => ImagePolicy.of(widget.category);

  @override
  void didUpdateWidget(covariant SingleImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部引用真的换了才重置本地编辑态，避免普通 rebuild 冲掉刚选的图
    if (oldWidget.initialRef != widget.initialRef) {
      _candidate = null;
      _cleared = false;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    if (!widget.enableUpload || _busy) return;
    setState(() => _busy = true);

    try {
      final policy = _policy;
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: policy.maxLongSide,
        maxHeight: policy.maxLongSide,
        imageQuality: policy.imageQuality,
      );
      if (picked == null) return; // 用户取消

      final candidate = await ImageValidator.validateWithFile(
        file: File(picked.path),
        policy: policy,
      );

      if (!mounted) return;
      setState(() {
        _candidate = candidate;
        _cleared = false;
      });
      widget.onImageChanged(candidate);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeImage() {
    setState(() {
      _candidate = null;
      _cleared = true;
    });
    widget.onImageChanged(null);
  }

  BorderRadius get _borderRadius => widget.shape == ImageShape.circle
      ? BorderRadius.circular(widget.size / 2)
      : BorderRadius.circular(widget.radius);

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
            ? Center(
                child: SizedBox(
                  width: widget.size * 0.32,
                  height: widget.size * 0.32,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final hasNew = candidate != null;
    final hasStored = !_cleared && widget.initialRef != null;
    final hasImage = hasNew || hasStored;

    if (hasImage) {
      final Widget picture = hasNew
          ? Image.memory(
              candidate.bytes,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              cacheWidth: (widget.size * 2).toInt(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            )
          : AppImage(
              ref: widget.initialRef,
              size: widget.size,
              shape: widget.shape,
              radius: widget.radius,
              placeholder: widget.placeholder,
            );

      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.shape == ImageShape.circle
                ? ClipOval(child: picture)
                : ClipRRect(
                    borderRadius: _borderRadius,
                    child: picture,
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

    if (widget.enableUpload) return _buildUploadBox();

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.placeholder ??
          ClipRRect(
            borderRadius: _borderRadius,
            child: Container(color: Colors.grey[100]),
          ),
    );
  }
}

/// ================== 多图组件 ==================
///
/// 输出 List<ImageEntry>：StoredImage = 原有图，NewImage = 本次新选。
/// 业务层把它整体交给 ImageService.plan，与单图走完全相同的落盘/回滚逻辑。
class MultiImagePickerWidget extends StatefulWidget {
  final List<ImageRef> initialRefs;

  final bool enableUpload;
  final int maxCount;
  final ImageCategory category;

  final double size;
  final ImageShape shape;
  final double radius;

  final Widget? fullPlaceholder;

  final ValueChanged<List<ImageEntry>> onImagesChanged;

  const MultiImagePickerWidget({
    super.key,
    this.initialRefs = const [],
    this.enableUpload = true,
    this.maxCount = 9,
    this.category = ImageCategory.receipt,
    this.size = 80,
    this.shape = ImageShape.rect,
    this.radius = 8,
    this.fullPlaceholder,
    required this.onImagesChanged,
  });

  @override
  State<MultiImagePickerWidget> createState() =>
      _MultiImagePickerWidgetState();
}

class _MultiImagePickerWidgetState extends State<MultiImagePickerWidget> {
  late List<ImageEntry> _entries;
  bool _busy = false;
  final ImagePicker _picker = ImagePicker();

  ImagePolicy get _policy => ImagePolicy.of(widget.category);

  @override
  void initState() {
    super.initState();
    _entries = widget.initialRefs.map((r) => StoredImage(r)).toList();
  }

  @override
  void didUpdateWidget(covariant MultiImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRefs != widget.initialRefs) {
      _entries = widget.initialRefs.map((r) => StoredImage(r)).toList();
    }
  }

  bool get _isFull => _entries.length >= widget.maxCount;

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _notify() => widget.onImagesChanged(List.unmodifiable(_entries));

  Future<void> _pickImages() async {
    if (!widget.enableUpload || _busy || _isFull) return;
    setState(() => _busy = true);

    try {
      final policy = _policy;
      final remain = widget.maxCount - _entries.length;
      final pickedList = await _picker.pickMultiImage(
        maxWidth: policy.maxLongSide,
        maxHeight: policy.maxLongSide,
        imageQuality: policy.imageQuality,
      );
      if (pickedList.isEmpty) return;

      final added = <ImageEntry>[];
      final errors = <String>[];

      for (final picked in pickedList.take(remain)) {
        try {
          final candidate = await ImageValidator.validateWithFile(
            file: File(picked.path),
            policy: policy,
          );
          added.add(NewImage(candidate));
        } catch (e) {
          errors.add(e.toString()); // 单张失败不影响其余张
        }
      }

      if (!mounted) return;

      if (added.isNotEmpty) {
        setState(() => _entries = [..._entries, ...added]);
        _notify();
      }

      if (pickedList.length > remain) {
        _showError(
          '最多上传 ${widget.maxCount} 张，本次仅添加 $remain 张，'
          '其余 ${pickedList.length - remain} 张未添加',
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
    setState(() => _entries = List<ImageEntry>.from(_entries)..removeAt(index));
    _notify();
  }

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _busy ? null : _pickImages,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            widget.shape == ImageShape.circle ? widget.size / 2 : widget.radius,
          ),
          border: Border.all(color: Colors.grey, width: 1),
          color: Colors.grey[50],
        ),
        child: _busy
            ? Center(
                child: SizedBox(
                  width: widget.size * 0.32,
                  height: widget.size * 0.32,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }

  Widget _buildDisabledBox() {
    return widget.fullPlaceholder ??
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
            color: Colors.grey[100],
          ),
          child: Icon(Icons.block, size: 22, color: Colors.grey[400]),
        );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      final Widget picture = entry is StoredImage
          ? AppImage(
              ref: entry.ref,
              size: widget.size,
              shape: widget.shape,
              radius: widget.radius,
            )
          : Image.memory(
              (entry as NewImage).candidate.bytes,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              cacheWidth: (widget.size * 2).toInt(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            );

      children.add(
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.shape == ImageShape.circle
                  ? ClipOval(child: picture)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
                      child: picture,
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

    if (widget.enableUpload) {
      children.add(_isFull ? _buildDisabledBox() : _buildUploadBox());
    }

    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}
