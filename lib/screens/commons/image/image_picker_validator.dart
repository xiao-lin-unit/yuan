import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 解码图片，带真实超时保护
Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();

  ui.decodeImageFromList(bytes, (image) {
    if (!completer.isCompleted) completer.complete(image);
  });

  // 注意：必须 return，之前的写法 timeout 被丢弃了，等于没设超时
  return completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => throw '图片解析超时或图片已损坏',
  );
}

class ImagePickResult {
  final String base64;
  final int width;
  final int height;

  ImagePickResult({
    required this.base64,
    required this.width,
    required this.height,
  });
}

class ImagePickerValidator {
  /// 校验文件
  /// 尺寸参数不传 = 不校验尺寸（推荐：交给 image_picker 的 maxLongSide 控制）
  static Future<ImagePickResult> validateWithFile({
    required File file,
    int? maxFileSize,
    List<String>? allowedExtensions,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();

    if (allowedExtensions != null && !allowedExtensions.contains(ext)) {
      throw '不支持的图片格式，仅允许: ${allowedExtensions.join(',')}';
    }

    final bytes = await file.readAsBytes();

    if (maxFileSize != null && bytes.length > maxFileSize) {
      throw '图片大小不能超过 ${maxFileSize ~/ 1024} KB';
    }

    final img = await _decodeImage(bytes);
    _checkSize(img.width, img.height, minWidth, minHeight, maxWidth, maxHeight);

    return ImagePickResult(
      base64: base64Encode(bytes),
      width: img.width,
      height: img.height,
    );
  }

  /// 校验字节（压缩后的场景用这个）
  static Future<ImagePickResult> validateWithBytes({
    required Uint8List bytes,
    required String fileExt,
    int? maxFileSize,
    List<String>? allowedExtensions,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
  }) async {
    final ext = fileExt.toLowerCase();

    if (allowedExtensions != null && !allowedExtensions.contains(ext)) {
      throw '不支持的图片格式，仅允许: ${allowedExtensions.join(',')}';
    }

    if (maxFileSize != null && bytes.length > maxFileSize) {
      throw '图片大小不能超过 ${maxFileSize ~/ 1024} KB';
    }

    final img = await _decodeImage(bytes);
    _checkSize(img.width, img.height, minWidth, minHeight, maxWidth, maxHeight);

    return ImagePickResult(
      base64: base64Encode(bytes),
      width: img.width,
      height: img.height,
    );
  }

  static void _checkSize(
      int w,
      int h,
      int? minW,
      int? minH,
      int? maxW,
      int? maxH,
      ) {
    if (minW != null && w < minW) throw '图片宽度不能小于 ${minW}px';
    if (maxW != null && w > maxW) throw '图片宽度不能大于 ${maxW}px';
    if (minH != null && h < minH) throw '图片高度不能小于 ${minH}px';
    if (maxH != null && h > maxH) throw '图片高度不能大于 ${maxH}px';
  }
}