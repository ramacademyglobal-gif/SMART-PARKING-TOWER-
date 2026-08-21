import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/repositories/parking_repository.dart';

class ApiParkingRepository implements ParkingRepository {
  ApiParkingRepository(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<ParkingSlotModel?> getCurrentSlot() async {
    try {
      final response = await _dio.get(ApiEndpoints.parkingSlot);
      if (response.data == null) return null;
      return ParkingSlotModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapDio(e);
    }
  }

  @override
  Future<ParkingSlotModel> allocateSlot() async {
    try {
      final response = await _dio.post(ApiEndpoints.allocateSlot);
      return ParkingSlotModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<List<ParkingHistoryModel>> getHistory({
    String? search,
    String? filter,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.parkingHistory,
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (filter != null && filter.isNotEmpty) 'filter': filter,
        },
      );
      final list = _asList(response.data);
      return list
          .map((e) => ParkingHistoryModel.fromJson(_asMap(e)))
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<ParkingHistoryModel> simulateEntry() async {
    try {
      final response = await _dio.post(ApiEndpoints.simulateEntry);
      _ensureOk(response);
      return ParkingHistoryModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<ParkingHistoryModel> simulateExit() async {
    try {
      final response = await _dio.post(ApiEndpoints.simulateExit);
      _ensureOk(response);
      return ParkingHistoryModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<GateScanResult> scanPass(String token, {String action = 'auto'}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.parkingScan,
        data: {'token': token, 'action': action},
      );
      _ensureOk(response);
      return GateScanResult.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<Map<String, dynamic>> createParkingOrder(String historyId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.createParkingOrder,
        data: {'historyId': historyId},
      );
      _ensureOk(response);
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
  Future<ParkingHistoryModel> verifyParkingPayment({
    required String historyId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyParkingPayment,
        data: {
          'historyId': historyId,
          'orderId': orderId,
          'paymentId': paymentId,
          'signature': signature,
        },
      );
      _ensureOk(response);
      return ParkingHistoryModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<Map<String, dynamic>> createBookingFeeOrder() async {
    try {
      final response = await _dio.post(ApiEndpoints.createBookingFeeOrder);
      _ensureOk(response);
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
  Future<QrCodeModel> verifyBookingFeePayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyBookingFeePayment,
        data: {
          'orderId': orderId,
          'paymentId': paymentId,
          'signature': signature,
        },
      );
      _ensureOk(response);
      return QrCodeModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  void _ensureOk(Response response) {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      final data = response.data;
      String message = 'Request failed';
      if (data is Map) {
        message = (data['message'] ?? data['error'] ?? message).toString();
      }
      throw ServerException(message: message, statusCode: status);
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
