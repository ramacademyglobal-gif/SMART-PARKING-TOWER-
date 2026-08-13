import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.phone,
    required this.displayName,
    this.photoUrl,
    required this.memberSince,
    required this.role,
    this.username,
  });

  final String id;
  final String phone;
  final String displayName;
  final String? photoUrl;
  final DateTime memberSince;
  final String role;
  final String? username;

  bool get isStaff => role == 'staff' || role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: (json['phone'] as String?) ?? '',
      displayName: json['displayName'] as String? ??
          json['display_name'] as String? ??
          '',
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String?,
      memberSince: DateTime.parse(
        json['memberSince'] as String? ??
            json['member_since'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      role: json['role'] as String? ?? 'user',
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'memberSince': memberSince.toIso8601String(),
      'role': role,
      'username': username,
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? displayName,
    String? photoUrl,
    DateTime? memberSince,
    String? role,
    String? username,
    bool clearPhotoUrl = false,
    bool clearUsername = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      memberSince: memberSince ?? this.memberSince,
      role: role ?? this.role,
      username: clearUsername ? null : (username ?? this.username),
    );
  }

  @override
  List<Object?> get props =>
      [id, phone, displayName, photoUrl, memberSince, role, username];
}
