import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/payment_repository.dart';

class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<Map<String, dynamic>> createOrder(SubscriptionPlanType planType) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.createOrder,
        data: {'planType': planType.apiValue},
      );
      final map = _asMap(response.data);
      return {
        'orderId': map['orderId'] ?? map['order_id'],
        'amount': map['amount'] ?? map['amountInPaise'] ?? map['amount_in_paise'],
        'currency': map['currency'] ?? 'INR',
        'key': map['key'] ?? map['razorpayKey'] ?? map['razorpay_key'],
      };
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<SubscriptionModel> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyPayment,
        data: {
          'orderId': orderId,
          'paymentId': paymentId,
          'signature': signature,
        },
      );
      return SubscriptionModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
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
