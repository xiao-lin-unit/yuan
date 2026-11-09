import 'image_category.dart';

/// 一类图片的统一处理策略：压缩尺寸、画质、体积、格式、最小尺寸。
///
/// 原先这些魔法数字散落在 `_AvatarField` 里（512 / 85 / 2MB / jpg,png,webp），
/// 换一个业务就得复制一遍。现在集中在策略表，组件只读策略，不自己写常量。
class ImagePolicy {
  /// 最长边上限，同时交给 image_picker 压缩与校验尺寸
  final double maxLongSide;

  /// image_picker 压缩质量（0-100）
  final int imageQuality;

  /// 原始/压缩后字节数上限
  final int maxFileSize;

  /// 允许的扩展名（不带点，小写）
  final List<String> allowedExtensions;

  final int? minWidth;
  final int? minHeight;

  const ImagePolicy({
    required this.maxLongSide,
    required this.imageQuality,
    required this.maxFileSize,
    required this.allowedExtensions,
    this.minWidth,
    this.minHeight,
  });

  int get maxSide => maxLongSide.toInt();

  static const Map<ImageCategory, ImagePolicy> presets = {
    ImageCategory.avatar: ImagePolicy(
      maxLongSide: 512,
      imageQuality: 85,
      maxFileSize: 2 * 1024 * 1024,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      minWidth: 64,
      minHeight: 64,
    ),
    ImageCategory.receipt: ImagePolicy(
      maxLongSide: 1600,
      imageQuality: 82,
      maxFileSize: 8 * 1024 * 1024,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    ),
    ImageCategory.categoryIcon: ImagePolicy(
      maxLongSide: 256,
      imageQuality: 90,
      maxFileSize: 1024 * 1024,
      allowedExtensions: ['png', 'webp', 'jpg', 'jpeg'],
    ),
    ImageCategory.attachment: ImagePolicy(
      maxLongSide: 2048,
      imageQuality: 85,
      maxFileSize: 12 * 1024 * 1024,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    ),
    ImageCategory.general: ImagePolicy(
      maxLongSide: 1024,
      imageQuality: 85,
      maxFileSize: 5 * 1024 * 1024,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    ),
  };

  static ImagePolicy of(ImageCategory category) =>
      presets[category] ?? presets[ImageCategory.general]!;
}
