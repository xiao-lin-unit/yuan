import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/user/user_dao.dart';
import '../database/user/user_info.dart';
import 'image/image_category.dart';
import 'image/image_ref.dart';
import 'image/image_service.dart';
import 'image/image_validator.dart';
import 'core/image_transaction.dart';
import 'core/unit_of_work.dart';

class UserController extends ChangeNotifier {
  final Database db;
  final UserInfoDao dao;

  final UnitOfWork uow;
  final ImageTransaction imageTx;

  UserController(
    this.db,
    this.dao, {
    ImageService? images,
    UnitOfWork? uow,
    ImageTransaction? imageTx,
  })  : uow = uow ?? UnitOfWork(db),
        imageTx = imageTx ??
            ImageTransaction(
              uow ?? UnitOfWork(db),
              images ?? ImageService.instance,
            );

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
  /// 图片与资料的一致性由 [ImageTransaction] 统一编排：新图落盘 →
  /// 在 [UnitOfWork.run] 的一个事务里写 DB → 提交成功删旧图 /
  /// 回滚删新图。与 CategoryController.save 共用同一个功能接口，
  /// 不再各写一套 try/catch。
  Future<void> updateProfile({
    String? username,
    String? userSub,
    Object? avatar = imageUndefined,
  }) async {
    final UserInfo? current = _user;
    if (current == null || _saving) return;

    _saving = true;
    notifyListeners();

    try {
      final bool changed = !identical(avatar, imageUndefined);
      final List<ImageRef> existing = current.avatarRef == null
          ? <ImageRef>[]
          : <ImageRef>[current.avatarRef!];
      late UserInfo updated;

      if (changed) {
        final List<ImageEntry> entries = <ImageEntry>[];
        if (avatar != null) {
          entries.add(NewImage(avatar as ImageCandidate));
        }
        await imageTx.run<void>(
          category: ImageCategory.avatar,
          entries: entries,
          existing: existing,
          ownerId: '${current.id ?? 1}',
          body: (ImageCommitPlan plan, DatabaseExecutor txn) async {
            final ImageRef? nextRef =
                plan.refs.isEmpty ? null : plan.refs.first;
            updated = current.copyWith(
              username: username,
              userSub: userSub,
              avatarRef: nextRef,
            );
            final int affected = await dao.updateUser(txn, updated);
            if (affected == 0) {
              throw StateError('资料写入未生效（未匹配到用户记录）');
            }
          },
          afterCommit: () async {
            _user = updated;
            notifyListeners();
          },
        );
      } else {
        updated = current.copyWith(
          username: username,
          userSub: userSub,
          avatarRef: imageUndefined,
        );
        await uow.run(
          (txn) async {
            final int affected = await dao.updateUser(txn, updated);
            if (affected == 0) {
              throw StateError('资料写入未生效（未匹配到用户记录）');
            }
          },
          afterCommit: () async {
            _user = updated;
            notifyListeners();
          },
        );
      }
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// 单独更新头像，复用同一条链路，避免两套逻辑分叉。
  Future<void> updateAvatar(Object? avatar) => updateProfile(avatar: avatar);
}
