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
    String? avatar,
    String? username,
    String? userSub,
  }) {
    return UserInfo(
      id: id,
      avatar: avatar ?? this.avatar,
      username: username ?? this.username,
      userSub: userSub ?? this.userSub,
    );
  }
}