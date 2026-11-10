import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_category.dart';
import 'image_ref.dart';

/// 唯一的图片落盘服务：按 [ImageCategory] 分子目录，
/// 负责 写 / 读 / 删 / 旧目录兼容 / 孤儿文件回收。
///
/// 目录结构：应用文档目录/images/<category.dirName>/<文件名>
/// 业务代码不接触 File、不拼路径、不关心扩展名。
class ImageStorage {
  ImageStorage._();
  static final ImageStorage instance = ImageStorage._();

  static const _rootDirName = 'images';

  /// 上一版补丁把头像放在 avatars/，这里保留只读兼容
  static const _legacyAvatarDirName = 'avatars';

  Future<Directory> get _root async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(doc.path, _rootDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _dirOf(ImageCategory category) async {
    final dir = Directory(p.join((await _root).path, category.dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileOf(ImageRef ref) async =>
      File(p.join((await _dirOf(ref.category)).path, ref.name));

  /// 写盘成功才返回引用；调用方拿到引用后再写数据库。
  Future<ImageRef> save(
    ImageCategory category,
    Uint8List bytes, {
    String? ext,
    String? ownerId,
  }) async {
    if (bytes.isEmpty) throw const FormatException('图片数据为空');

    String suffix;
    if (ext == null || ext.isEmpty) {
      suffix = sniffExt(bytes);
    } else {
      suffix = ext.startsWith('.') ? ext : '.$ext';
    }

    final name =
        '${category.dirName}_${ownerId ?? 'x'}_'
        '${DateTime.now().microsecondsSinceEpoch}$suffix';
    final file = File(p.join((await _dirOf(category)).path, name));
    await file.writeAsBytes(bytes, flush: true);
    return ImageRef(category, name);
  }

  /// 引用 → 实际文件。文件丢失时返回 null，UI 自动降级成占位图。
  Future<File?> resolve(ImageRef? ref) async {
    if (ref == null) return null;
    final file = await _fileOf(ref);
    if (await file.exists()) return file;

    // v2 兼容：旧 avatars/ 目录还没迁移完时也能显示
    if (ref.category == ImageCategory.avatar) {
      final doc = await getApplicationDocumentsDirectory();
      final legacy = File(p.join(doc.path, _legacyAvatarDirName, ref.name));
      if (await legacy.exists()) return legacy;
    }
    return null;
  }

  Future<Uint8List?> readBytes(ImageRef? ref) async {
    final file = await resolve(ref);
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// 删除永远容错：删不掉只是留一个孤儿文件，不能影响主流程。
  Future<void> delete(ImageRef? ref) async {
    if (ref == null) return;
    try {
      final file = await resolve(ref);
      if (file != null) await file.delete();
    } catch (_) {
      // 忽略
    }
  }

  Future<void> deleteMany(Iterable<ImageRef?> refs) async {
    for (final ref in refs) {
      await delete(ref);
    }
  }

  /// 把旧目录里的文件收编进统一目录（保持原文件名，DB 只补分类前缀）。
  Future<ImageRef?> adoptLegacy(
    String name, {
    ImageCategory category = ImageCategory.avatar,
  }) async {
    final doc = await getApplicationDocumentsDirectory();
    final legacy = File(p.join(doc.path, _legacyAvatarDirName, name));
    if (!await legacy.exists()) return null;
    return adopt(category, legacy);
  }

  Future<ImageRef> adopt(ImageCategory category, File source) async {
    final name = p.basename(source.path);
    final dest = File(p.join((await _dirOf(category)).path, name));
    if (!await dest.exists()) await source.copy(dest.path);
    return ImageRef(category, name);
  }

  /// 孤儿文件回收：传入「当前被 DB 引用的全部 ImageRef」，
  /// 删除 images/ 下没被引用的文件。可在启动后或设置页调用。
  Future<int> sweep(Set<ImageRef> referenced) async {
    final keep = referenced.map((r) => r.encode()).toSet();
    final root = await _root;
    var removed = 0;

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: root.path)
          .replaceAll('\\', '/');
      final ref = ImageRef.tryDecode(relative);
      if (ref == null || keep.contains(ref.encode())) continue;
      try {
        await entity.delete();
        removed++;
      } catch (_) {
        // 忽略
      }
    }
    return removed;
  }

  /// 按 magic bytes 嗅探扩展名，不信任文件后缀
  static String sniffExt(List<int> b) {
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50) return '.png';
    if (b.length >= 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46) {
      return '.webp';
    }
    if (b.length >= 12 &&
        b[4] == 0x66 &&
        b[5] == 0x74 &&
        b[6] == 0x79 &&
        b[7] == 0x70) return '.heic';
    return '.jpg';
  }
}
