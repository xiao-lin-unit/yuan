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

  Future<void> load() async {
    _user = await dao.getUser(db);
    notifyListeners();
  }

  Future<void> updateAvatar(String base64) async {
    _user = _user!.copyWith(avatar: base64);
    await dao.updateUser(db, _user!);
    notifyListeners();
  }

  Future<void> updateProfile({
    String? username,
    String? userSub,
  }) async {
    _user = _user!.copyWith(
      username: username,
      userSub: userSub,
    );
    await dao.updateUser(db, _user!);
    notifyListeners();
  }

}