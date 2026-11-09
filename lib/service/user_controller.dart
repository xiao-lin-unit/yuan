import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../database/user/user_dao.dart';
import '../database/user/user_info.dart';

class UserController extends ChangeNotifier {
  final Database db;
  final UserInfoDao dao;

  UserController(this.db, this.dao);

  UserInfo? _user;
  UserInfo? get user => _user;

  Future<void> load() async {
    _user = await dao.getUser(db);
    notifyListeners();
  }

  /// 统一更新资料
  /// 不传 avatar = 不改；传 null = 清空
  Future<void> updateProfile({
    String? username,
    String? userSub,
    Object? avatar = avatarUndefined,   // ← 用导入的常量
  }) async {
    final current = _user;
    if (current == null) return;

    _user = current.copyWith(
      username: username,
      userSub: userSub,
      avatar: avatar,
    );

    unawaited(dao.updateUser(db, _user!));
    notifyListeners();
  }

  /// 单独更新头像
  Future<void> updateAvatar(String? base64) async {
    final current = _user;
    if (current == null) return;

    _user = current.copyWith(avatar: base64);
    unawaited(dao.updateUser(db, _user!));
    notifyListeners();
  }
}