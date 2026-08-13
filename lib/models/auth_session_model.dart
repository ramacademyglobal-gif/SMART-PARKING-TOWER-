import 'package:equatable/equatable.dart';
import 'package:multiparking_tower/models/user_model.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.isNewUser,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final bool isNewUser;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthSession(
      accessToken: json['accessToken'] as String? ??
          json['access_token'] as String? ??
          '',
      refreshToken: json['refreshToken'] as String? ??
          json['refresh_token'] as String? ??
          '',
      user: UserModel.fromJson(
        userJson is Map<String, dynamic>
            ? userJson
            : Map<String, dynamic>.from(userJson as Map),
      ),
      isNewUser: json['isNewUser'] as bool? ??
          json['is_new_user'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
      'isNewUser': isNewUser,
    };
  }

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    UserModel? user,
    bool? isNewUser,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, user, isNewUser];
}
