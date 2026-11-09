import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_policy.dart';

/// 「刚选好、还没落盘」的图片。
///
/// 只在内存里流转（选择器 → 弹窗 → controller），**绝不写进数据库**。
/// base64 仅作为遗留/调试用的内存传输格式，不是持久化格式。
class ImageCandidate {
  final Uint8List bytes;
  final int width;
  final int height;

  /// 不带点的小写扩展名，如 jpg / png / webp
  final String ext;

  const ImageCandidate({
    required this.bytes,
    required this.width,
    required this.height,
    required this.ext,
  });

  int get byteLength => bytes.length;

  /// 仅用于内存传输、日志、旧接口兼容；禁止入库。
  String get base64 => base64Encode(bytes);
}

/// 解码图片，带真实超时保护。
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

/// 唯一的图片校验入口：格式 + 体积 + 真实解码 + 尺寸。
/// 参数从散落的 maxFileSize / allowedExtensions / maxWidth… 收敛成一个 [ImagePolicy]。
class ImageValidator {
  static Future<ImageCandidate> validateWithFile({
    required File file,
    required ImagePolicy policy,
    bool checkSize = true,
  }) async {
    final ext = _extOfPath(file.path);
    _checkExt(ext, policy);

    final bytes = await file.readAsBytes();
    return _validate(bytes, ext, policy, checkSize);
  }

  static Future<ImageCandidate> validateWithBytes({
    required Uint8List bytes,
    required String fileExt,
    required ImagePolicy policy,
    bool checkSize = true,
  }) async {
    final ext = fileExt.startsWith('.')
        ? fileExt.substring(1).toLowerCase()
        : fileExt.toLowerCase();
    _checkExt(ext, policy);
    return _validate(bytes, ext, policy, checkSize);
  }

  static Future<ImageCandidate> _validate(
    Uint8List bytes,
    String ext,
    ImagePolicy policy,
    bool checkSize,
  ) async {
    if (bytes.isEmpty) throw const FormatException('图片数据为空');
    if (bytes.length > policy.maxFileSize) {
      throw '图片大小不能超过 ${policy.maxFileSize ~/ 1024} KB';
    }

    final img = await _decodeImage(bytes);
    // 迁移历史图片时跳过尺寸上限：老图不满足当前策略也应保住，不该被清空
    if (checkSize) _checkSize(img.width, img.height, policy);

    return ImageCandidate(
      bytes: bytes,
      width: img.width,
      height: img.height,
      ext: ext,
    );
  }

  static String _extOfPath(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return '';
    return name.substring(i + 1).toLowerCase();
  }

  static void _checkExt(String ext, ImagePolicy policy) {
    if (ext.isEmpty || !policy.allowedExtensions.contains(ext)) {
      throw '不支持的图片格式，仅允许: ${policy.allowedExtensions.join(',')}';
    }
  }

  static void _checkSize(int w, int h, ImagePolicy policy) {
    if (policy.minWidth != null && w < policy.minWidth!) {
      throw '图片宽度不能小于 ${policy.minWidth}px';
    }
    if (policy.minHeight != null && h < policy.minHeight!) {
      throw '图片高度不能小于 ${policy.minHeight}px';
    }
    if (w > policy.maxSide) throw '图片宽度不能大于 ${policy.maxSide}px';
    if (h > policy.maxSide) throw '图片高度不能大于 ${policy.maxSide}px';
  }
}
