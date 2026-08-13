import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/notification_model.dart';
import 'package:multiparking_tower/repositories/notification_repository.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<List<AppNotificationModel>> list() async {
    try {
      final response = await _dio.get(ApiEndpoints.notifications);
      final list = _asList(response.data);
      return list
          .map((e) => AppNotificationModel.fromJson(_asMap(e)))
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await _dio.post(
        ApiEndpoints.markNotificationRead,
        data: {'notificationId': notificationId},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<void> registerFcmToken(String token) async {
    try {
      await _dio.post(
        ApiEndpoints.registerFcm,
        data: {'token': token},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    throw const ServerException(message: 'Unexpected response format');
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ServerException(message: 'Unexpected response format');
  }

  ServerException _mapDio(DioException e) {
    final data = e.response?.data;
    String message = e.message ?? 'Network request failed';
    if (data is Map) {
      message = (data['message'] ?? data['error'] ?? message).toString();
    }
    return ServerException(message: message, statusCode: e.response?.statusCode);
  }
}
