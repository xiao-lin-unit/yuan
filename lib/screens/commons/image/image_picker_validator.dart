import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();

  ui.decodeImageFromList(bytes, (image) {
    if (!completer.isCompleted) {
      completer.complete(image);
    }
  });

  completer.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      throw '图片解析超时或图片已损坏';
    },
  );

  return completer.future;
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
  static Future<ImagePickResult> validateWithFile({
    required File file,
    int? maxFileSize,
    List<String>? allowedExtensions,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();

    if (allowedExtensions != null &&
        !allowedExtensions.contains(ext)) {
      throw '不支持的图片格式，仅允许: ${allowedExtensions.join(',')}';
    }

    if (maxFileSize != null && bytes.length > maxFileSize) {
      throw '图片大小不能超过 ${maxFileSize ~/ 1024} KB';
    }

    final img = await _decodeImage(bytes);

    if (minWidth != null && img.width < minWidth) {
      throw '图片宽度不能小于 ${minWidth}px';
    }
    if (maxWidth != null && img.width > maxWidth) {
      throw '图片宽度不能大于 ${maxWidth}px';
    }
    if (minHeight != null && img.height < minHeight) {
      throw '图片高度不能小于 ${minHeight}px';
    }
    if (maxHeight != null && img.height > maxHeight) {
      throw '图片高度不能大于 ${maxHeight}px';
    }

    return ImagePickResult(
      base64: base64Encode(bytes),
      width: img.width,
      height: img.height,
    );
  }
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

    if (allowedExtensions != null &&
        !allowedExtensions.contains(fileExt)) {
      throw '不支持的图片格式，仅允许: ${allowedExtensions.join(',')}';
    }

    if (maxFileSize != null && bytes.length > maxFileSize) {
      throw '图片大小不能超过 ${maxFileSize ~/ 1024} KB';
    }

    final img = await _decodeImage(bytes);

    if (minWidth != null && img.width < minWidth) {
      throw '图片宽度不能小于 ${minWidth}px';
    }
    if (maxWidth != null && img.width > maxWidth) {
      throw '图片宽度不能大于 ${maxWidth}px';
    }
    if (minHeight != null && img.height < minHeight) {
      throw '图片高度不能小于 ${minHeight}px';
    }
    if (maxHeight != null && img.height > maxHeight) {
      throw '图片高度不能大于 ${maxHeight}px';
    }

    return ImagePickResult(
      base64: base64Encode(bytes),
      width: img.width,
      height: img.height,
    );
  }

}