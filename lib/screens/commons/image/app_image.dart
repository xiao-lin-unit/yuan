import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yuan/service/image/image_ref.dart';
import 'package:yuan/service/image/image_storage.dart';

/// 图片展示形态
enum ImageShape { rect, circle }

/// 全项目唯一的图片展示组件。
///
/// 传 [ref] 或直接传数据库里的 [stored] 字符串都行；
/// 内部统一 resolve → Image.file → 缓存解码 → 失败降级占位。
/// 头像、凭证、分类图标……不再各写一遍 FutureBuilder + Image.file。
class AppImage extends StatelessWidget {
  final ImageRef? ref;

  /// 数据库里的原始值，方便直接传，不必先解析
  final String? stored;

  final double size;
  final ImageShape shape;
  final double radius;
  final BoxFit fit;
  final Widget? placeholder;

  const AppImage({
    super.key,
    this.ref,
    this.stored,
    required this.size,
    this.shape = ImageShape.rect,
    this.radius = 8,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  ImageRef? get _ref => ref ?? ImageRef.tryDecode(stored);

  Widget _fallback(BuildContext context) =>
      placeholder ??
      Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );

  @override
  Widget build(BuildContext context) {
    final imageRef = _ref;

    if (imageRef == null) {
      return SizedBox(width: size, height: size, child: _fallback(context));
    }

    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<File?>(
        future: ImageStorage.instance.resolve(imageRef),
        builder: (context, snapshot) {
          Widget child;
          final file = snapshot.data;

          if (file == null) {
            child = _fallback(context);
          } else {
            child = Image.file(
              file,
              width: size,
              height: size,
              fit: fit,
              // 38px 头像只解码 76px，避免整张大图进内存
              cacheWidth: (size * 2).toInt(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback(context),
            );
          }

          return shape == ImageShape.circle
              ? ClipOval(child: child)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: child,
                );
        },
      ),
    );
  }
}
