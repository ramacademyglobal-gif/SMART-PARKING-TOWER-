import 'package:multiparking_tower/models/auth_session_model.dart';
import 'package:multiparking_tower/models/user_model.dart';

abstract class AuthRepository {
  Future<void> sendOtp(String phone);

  Future<AuthSession> verifyOtp(String phone, String otp);

  Future<AuthSession> staffLogin(String username, String password);

  Future<AuthSession> refreshToken(String refreshToken);

  Future<void> logout();

  Future<UserModel?> getCurrentUser();
}
