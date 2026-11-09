
const Object avatarUndefined = Object();

class UserInfo {
  final int? id;
  final String? avatar; // base64 or null
  final String username;
  final String userSub;

  const UserInfo({
    this.id,
    this.avatar,
    required this.username,
    required this.userSub,
  });

  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      id: map['id'] as int?,
      avatar: map['avatar'] as String?,
      username: map['username'] as String,
      userSub: map['user_sub'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'avatar': avatar,
      'username': username,
      'user_sub': userSub,
    };
  }

  UserInfo copyWith({
    String? username,
    String? userSub,
    Object? avatar = avatarUndefined,
  }) {
    return UserInfo(
      username: username ?? this.username,
      userSub: userSub ?? this.userSub,
      avatar: identical(avatar, avatarUndefined) ? this.avatar : avatar as String?,
    );
  }
}