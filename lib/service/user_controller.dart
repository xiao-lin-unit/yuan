import 'package:flutter/cupertino.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/user/user_dao.dart';
import '../database/user/user_info.dart';

class UserController extends ChangeNotifier {
  final UserInfoDao dao;
  final Database db;

  UserController(this.db, this.dao);

  UserInfo? _user;
  UserInfo? get user => _user;

  /// 初始化加载用户
  Future<void> load() async {
    _user = await dao.getUser(db);
    notifyListeners();
  }

  /// ✅ 统一更新资料（名称 / 介绍 / 头像）
  /// 只更新传入的字段，未传的保持不变
  Future<void> updateProfile({
    String? username,
    String? userSub,
    String? avatar,
  }) async {
    final current = _user;
    if (current == null) return;

    _user = current.copyWith(
      username: username,
      userSub: userSub,
      avatar: avatar,
    );

    await dao.updateUser(db, _user!);
    notifyListeners();
  }

  /// ✅ 保留：单独更新头像（可选，但推荐保留）
  Future<void> updateAvatar(String? base64) async {
    final current = _user;
    if (current == null) return;

    _user = current.copyWith(avatar: base64);
    await dao.updateUser(db, _user!);
    notifyListeners();
  }
}