import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/subscription_repository.dart';

class ApiSubscriptionRepository implements SubscriptionRepository {
  ApiSubscriptionRepository(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<List<SubscriptionPlanModel>> getPlans() async {
    try {
      final response = await _dio.get(ApiEndpoints.plans);
      final list = _asList(response.data);
      return list
          .map((e) => SubscriptionPlanModel.fromJson(_asMap(e)))
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<SubscriptionModel?> getCurrent() async {
    try {
      final response = await _dio.get(ApiEndpoints.subscriptions);
      if (response.data == null) return null;

      if (response.data is List) {
        final list = response.data as List;
        if (list.isEmpty) return null;
        return SubscriptionModel.fromJson(_asMap(list.first));
      }

      final map = _asMap(response.data);
      if (map.isEmpty) return null;
      if (map['data'] is List) {
        final list = map['data'] as List;
        if (list.isEmpty) return null;
        return SubscriptionModel.fromJson(_asMap(list.first));
      }
      return SubscriptionModel.fromJson(map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapDio(e);
    }
  }

  @override
  Future<List<PaymentModel>> getPaymentHistory() async {
    try {
      final response = await _dio.get(ApiEndpoints.paymentHistory);
      final list = _asList(response.data);
      return list.map((e) => PaymentModel.fromJson(_asMap(e))).toList();
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
