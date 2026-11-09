import 'dart:io';

import 'image_category.dart';
import 'image_policy.dart';
import 'image_ref.dart';
import 'image_storage.dart';
import 'image_validator.dart';

/// 一次图片变更的「提交计划」。
///
/// 关键约束：**图片先落盘，数据库写成功后才删旧图**。
/// 之前这套回滚逻辑是 UserController 里手写的 pendingNewPath，
/// 现在抽成通用能力，单图、多图、任何业务共用。
class ImageCommitPlan {
  /// 最终应写进数据库的引用（顺序与 UI 一致）
  final List<ImageRef> refs;

  /// 数据库写成功后要删除的旧图
  final List<ImageRef> toDiscard;

  /// 本次新落盘的文件；数据库写失败时全部回滚
  final List<ImageRef> pending;

  final ImageStorage _storage;

  ImageCommitPlan._(
    this.refs,
    this.toDiscard,
    this.pending,
    this._storage,
  );

  /// 数据库写入成功后调用。删旧图失败不影响主流程。
  Future<void> commit() => _storage.deleteMany(toDiscard);

  /// 数据库写入失败时调用。只回滚新图，不动已存在的引用。
  Future<void> discard() => _storage.deleteMany(pending);
}

/// 图片处理的唯一门面。业务层只跟它打交道：
/// 选择结果 → plan/prepare → 写 DB → commit 或 discard。
class ImageService {
  ImageService(this._storage);

  static final ImageService instance = ImageService(ImageStorage.instance);

  final ImageStorage _storage;

  ImagePolicy policyOf(ImageCategory category) => ImagePolicy.of(category);

  /// 单个新图落盘，返回引用（还未被任何记录引用，属 pending）。
  Future<ImageRef> prepare(
    ImageCategory category,
    ImageCandidate candidate, {
    String? ownerId,
  }) =>
      _storage.save(
        category,
        candidate.bytes,
        ext: candidate.ext,
        ownerId: ownerId,
      );

  /// 单图 / 多图共用的编排入口。
  ///
  /// [entries] 是编辑后的完整列表（StoredImage = 保留旧图，NewImage = 新选的图）；
  /// [existing] 是数据库里当前已有的引用，用于算出哪些旧图该删。
  /// 任一新图落盘失败 → 自动回滚本次已落盘的所有新图并抛异常。
  Future<ImageCommitPlan> plan(
    ImageCategory category,
    List<ImageEntry> entries, {
    Iterable<ImageRef> existing = const <ImageRef>[],
    String? ownerId,
  }) async {
    final refs = <ImageRef>[];
    final pending = <ImageRef>[];

    try {
      for (final entry in entries) {
        if (entry is StoredImage) {
          refs.add(entry.ref);
        } else if (entry is NewImage) {
          final ref = await prepare(category, entry.candidate, ownerId: ownerId);
          pending.add(ref);
          refs.add(ref);
        }
      }
    } catch (_) {
      await _storage.deleteMany(pending);
      rethrow;
    }

    final keep = refs.toSet();
    final toDiscard =
        existing.where((r) => !keep.contains(r)).toList(growable: false);

    return ImageCommitPlan._(refs, toDiscard, pending, _storage);
  }

  Future<File?> resolve(ImageRef? ref) => _storage.resolve(ref);

  Future<void> delete(ImageRef? ref) => _storage.delete(ref);

  /// 全局孤儿文件回收
  Future<int> sweep(Set<ImageRef> referenced) => _storage.sweep(referenced);
}
