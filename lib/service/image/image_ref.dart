import 'image_category.dart';
import 'image_validator.dart';

/// 语义哨兵：区分「没动过图片」与「清空图片（传 null）」。
/// 替代原来头像专用的 avatarUndefined，全项目共用这一个。
const Object imageUndefined = Object();

/// 数据库里唯一允许存的图片形态：`分类目录/文件名`。
///
/// 图片本体永远在磁盘上；DB 只存这个轻量引用。
/// 业务层拿到的永远是 [ImageRef]，不再各自解析 base64 或裸路径。
class ImageRef {
  final ImageCategory category;
  final String name;

  const ImageRef(this.category, this.name);

  String get relativePath => '${category.dirName}/$name';

  /// 写库时用
  String encode() => relativePath;

  /// 读库时用。兼容三种历史形态：
  /// 1. `avatar/xxx.jpg` —— 当前规范格式
  /// 2. `avatar_1_xxx.jpg` —— 上一版补丁的纯文件名（自动补 avatar 分类）
  /// 3. 长 base64 —— 返回 null，交给 ImageMigration 处理
  static ImageRef? tryDecode(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    if (isLegacyBase64(stored)) return null;

    final parts = stored.split('/');
    if (parts.length == 2) {
      final c = ImageCategory.fromDirName(parts[0]);
      if (c != null && parts[1].isNotEmpty) return ImageRef(c, parts[1]);
      return null;
    }
    if (parts.length == 1) return ImageRef(ImageCategory.avatar, stored);
    return null;
  }

  static bool isLegacyBase64(String s) {
    if (s.length < 256) return false;
    if (s.contains('/') || s.contains('\\') || s.contains('.')) return false;
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(s);
  }

  @override
  bool operator ==(Object other) =>
      other is ImageRef && other.category == category && other.name == name;

  @override
  int get hashCode => Object.hash(category, name);

  @override
  String toString() => encode();
}

/// 编辑态的一条图片：要么已存在（引用），要么是新选的（内存字节）。
/// 单图和多图组件统一输出它，业务层再统一交给 ImageService.plan 落库。
sealed class ImageEntry {
  const ImageEntry();
}

class StoredImage extends ImageEntry {
  final ImageRef ref;
  const StoredImage(this.ref);
}

class NewImage extends ImageEntry {
  final ImageCandidate candidate;
  const NewImage(this.candidate);
}
