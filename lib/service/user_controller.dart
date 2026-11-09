import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/user/user_dao.dart';
import '../database/user/user_info.dart';
import 'image/image_category.dart';
import 'image/image_ref.dart';
import 'image/image_service.dart';
import 'image/image_validator.dart';

class UserController extends ChangeNotifier {
  final Database db;
  final UserInfoDao dao;
  final ImageService _images;

  UserController(this.db, this.dao, {ImageService? images})
      : _images = images ?? ImageService.instance;

  UserInfo? _user;
  UserInfo? get user => _user;

  bool _saving = false;
  bool get saving => _saving;

  Future<void> load() async {
    _user = await dao.getUser(db);
    notifyListeners();
  }

  /// 统一更新资料。
  ///
  /// [avatar] 传 [imageUndefined] = 不改；null = 清空；(ImageCandidate) = 新图。
  ///
  /// 图片与资料共用一条「两阶段」链路，由 [ImageService.plan] 统一编排：
  /// 新图先落盘 → await 写数据库 → 成功才删旧图 / 失败回滚新图。
  /// 这段逻辑与业务无关，账单凭证等多图场景调用的是同一个 plan。
  Future<void> updateProfile({
    String? username,
    String? userSub,
    Object? avatar = imageUndefined,
  }) async {
    final current = _user;
    if (current == null || _saving) return;

    _saving = true;
    notifyListeners();

    ImageCommitPlan? plan;
    try {
      final changed = !identical(avatar, imageUndefined);
      final existing = current.avatarRef == null
          ? <ImageRef>[]
          : <ImageRef>[current.avatarRef!];
      ImageRef? nextRef = current.avatarRef;

      if (changed) {
        final entries = <ImageEntry>[];
        if (avatar != null) {
          entries.add(NewImage(avatar as ImageCandidate));
        }
        plan = await _images.plan(
          ImageCategory.avatar,
          entries,
          existing: existing,
          ownerId: '${current.id ?? 1}',
        );
        nextRef = plan.refs.isEmpty ? null : plan.refs.first;
      }

      final updated = current.copyWith(
        username: username,
        userSub: userSub,
        avatarRef: changed ? nextRef : imageUndefined,
      );

      // ✅ await 到底：调用方 await 返回时，数据一定已落库
      final affected = await dao.updateUser(db, updated);
      if (affected == 0) {
        throw StateError('资料写入未生效（未匹配到用户记录）');
      }

      // 落库成功后才清理旧图。先把 plan 摘掉：
      // 万一 commit 抛错，catch 也不能再回滚这批已被 DB 引用的新图。
      final committed = plan;
      plan = null;
      await committed?.commit();

      _user = updated;
      notifyListeners();
    } catch (_) {
      // 写失败：内存保持旧值，回滚本次新落盘的文件
      await plan?.discard();
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// 单独更新头像，复用同一条链路，避免两套逻辑分叉。
  Future<void> updateAvatar(Object? avatar) => updateProfile(avatar: avatar);
}
