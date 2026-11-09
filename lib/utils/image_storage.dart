import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


/// 应用内所有图片的统一本地存储（头像、以后的账单凭证 / 票据 / 分类图标都走这里）。
///
/// 约定：**数据库里只存相对路径**（如 `avatar/1/1699....jpg`、`bill/2026-11/....jpg`），
/// 绝不存 base64。一张 512px 的图 base64 后约 0.3～1MB，直接进库会让每次查询、
/// 每次 rebuild 都带上整张图，数据库也会快速膨胀。
///
/// 路径规则：
/// - 根目录：`<ApplicationSupport>/images`
/// - 分桶：[ImageBucket] 决定一级目录，用户 id 决定二级目录（多账号时互不干扰）
/// - 落盘方式：先写 `.tmp` 再原子 rename，避免写一半崩溃留下损坏文件
abstract interface class ImageStorage {
  /// 相对路径 → 可显示的文件；路径为空或文件不存在返回 null
  Future<File?> resolve(String? relativePath);

  /// 字节 → 本地文件，返回相对路径；[bytes] 为空返回 null
  Future<String?> save(Uint8List bytes, ImageBucket bucket, {int ownerId = 0});

  /// 删除单个文件（相对路径）
  Future<void> delete(String? relativePath);

  /// 删除某桶某 owner 下除 [keep] 之外的所有文件（替换图片后清理旧图）
  Future<void> deleteOthers(ImageBucket bucket, int ownerId, {String? keep});

  /// 删除某桶某 owner 下的全部文件（删除用户 / 清空数据时调用）
  Future<void> deleteAll(ImageBucket bucket, int ownerId);

  /// 启动时清理上次残留的 `.tmp` 草稿文件
  Future<void> cleanTemp();

  static Future<ImageStorage> create() => LocalImageStorage._init();
}

/// 图片用途分桶，新增业务只加枚举值，不碰存储实现
enum ImageBucket {
  avatar('avatar'),
  bill('bill'), // 预留：账单凭证 / 票据
  other('other');

  const ImageBucket(this.dir);
  final String dir;
}

final class LocalImageStorage implements ImageStorage {
  final Directory _root;

  LocalImageStorage(this._root);

  static Future<LocalImageStorage> _init() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'images'));
    if (!root.existsSync()) root.createSync(recursive: true);
    return LocalImageStorage(root);
  }

  File _file(String relativePath) => File(p.join(_root.path, _safe(relativePath)));

  /// 防目录穿越：去掉所有 `..` 段
  String _safe(String relativePath) =>
      p.joinAll(p.split(relativePath)..removeWhere((e) => e == '..' || e.isEmpty));

  @override
  Future<File?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final f = _file(relativePath);
    return f.existsSync() ? f : null;
  }

  @override
  Future<String?> save(Uint8List bytes, ImageBucket bucket, {int ownerId = 0}) async {
    if (bytes.isEmpty) return null;
    final dir = Directory(p.join(_root.path, bucket.dir, '$ownerId'));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final target = File(p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.img'));
    final tmp = File('${target.path}.tmp');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      if (target.existsSync()) await target.delete();
      await tmp.rename(target.path);
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    }
    return p.join(bucket.dir, '$ownerId', p.basename(target.path));
  }

  @override
  Future<void> delete(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    try {
      final f = _file(relativePath);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // 删除失败不影响主流程，最多留一个垃圾文件
    }
  }

  @override
  Future<void> deleteOthers(ImageBucket bucket, int ownerId, {String? keep}) async {
    for (final f in _list(bucket, ownerId)) {
      if (keep == null || p.basename(f.path) != p.basename(keep)) {
        await f.delete();
      }
    }
  }

  @override
  Future<void> deleteAll(ImageBucket bucket, int ownerId) async {
    final dir = Directory(p.join(_root.path, bucket.dir, '$ownerId'));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  @override
  Future<void> cleanTemp() async {
    final root = Directory(p.join(_root.path));
    if (!root.existsSync()) return;
    await for (final f in root.list(recursive: true, followLinks: false)) {
      if (f is File && f.path.endsWith('.tmp')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  Iterable<File> _list(ImageBucket bucket, int ownerId) {
    final dir = Directory(p.join(_root.path, bucket.dir, '$ownerId'));
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<File>().where((f) => !f.path.endsWith('.tmp'));
  }
}
