import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/auth_session_model.dart';
import 'package:multiparking_tower/models/user_model.dart';
import 'package:multiparking_tower/repositories/auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<void> sendOtp(String phone) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.sendOtp,
        data: {'phone': phone},
        options: Options(extra: {'skipAuth': true}),
      );
      _ensureOk(response);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<AuthSession> verifyOtp(String phone, String otp) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyOtp,
        data: {'phone': phone, 'otp': otp},
        options: Options(extra: {'skipAuth': true}),
      );
      _ensureOk(response);
      return AuthSession.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<AuthSession> staffLogin(String username, String password) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.staffLogin,
        data: {'username': username, 'password': password},
        options: Options(extra: {'skipAuth': true}),
      );
      _ensureOk(response);
      return AuthSession.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<AuthSession> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      return AuthSession.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiEndpoints.me);
      if (response.data == null) return null;
      return UserModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      throw _mapDio(e);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ServerException(message: 'Unexpected response format');
  }

  void _ensureOk(Response response) {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      final data = response.data;
      String message = 'Request failed';
      if (data is Map) {
        message = (data['message'] ??
                data['error'] ??
                data['detail'] ??
                message)
            .toString();
      }
      throw ServerException(message: message, statusCode: status);
    }
  }

  AppException _mapDio(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkException(
        message:
            'Cannot reach the parking API. Keep the PC server running and stay on the same Wi‑Fi.',
        code: 'connection',
      );
    }
    return _client.mapError(e);
  }
}
