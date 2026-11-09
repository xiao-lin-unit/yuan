import 'package:yuan/service/image/image_ref.dart';

class UserInfo {
  final int? id;

  /// 头像只是「统一图片层」的一个业务分类；DB 里只存 ImageRef。
  /// null = 未设置头像。
  final ImageRef? avatarRef;
  final String username;
  final String userSub;

  const UserInfo({
    this.id,
    this.avatarRef,
    required this.username,
    required this.userSub,
  });

  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      id: map['id'] as int?,
      // tryDecode 自动兼容旧 base64（返回 null）与旧纯文件名
      avatarRef: ImageRef.tryDecode(map['avatar'] as String?),
      username: map['username'] as String,
      userSub: map['user_sub'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    // avatar 列是 NOT NULL：清空时必须写空串，写 null 会抛约束错
    return {
      'id': id,
      'avatar': avatarRef?.encode() ?? '',
      'username': username,
      'user_sub': userSub,
    };
  }

  UserInfo copyWith({
    String? username,
    String? userSub,
    Object? avatarRef = imageUndefined,
  }) {
    return UserInfo(
      // ⚠️ 原实现漏了 id，导致 update 的 whereArgs 变成 [null]，
      // WHERE id = NULL 永远不成立 → 更新 0 行且静默失败。
      id: id,
      username: username ?? this.username,
      userSub: userSub ?? this.userSub,
      avatarRef: identical(avatarRef, imageUndefined)
          ? this.avatarRef
          : avatarRef as ImageRef?,
    );
  }
}
