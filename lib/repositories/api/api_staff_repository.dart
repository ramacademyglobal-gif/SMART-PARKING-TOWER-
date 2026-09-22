import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/models/staff_models.dart';
import 'package:multiparking_tower/repositories/staff_repository.dart';

class ApiStaffRepository implements StaffRepository {
  ApiStaffRepository(this._client);

  final DioClient _client;
  Dio get _dio => _client.dio;

  @override
  Future<StaffOverviewModel> getOverview() async {
    try {
      final response = await _dio.get(ApiEndpoints.staffOverview);
      return StaffOverviewModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<GateScanResult> scanPass(String token, {String action = 'auto'}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.staffScan,
        data: {'token': token, 'action': action},
      );
      return GateScanResult.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<List<StaffSessionModel>> listSessions({
    String? search,
    String status = 'parked',
    int? floor,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.staffSessions,
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search,
          'status': status,
          'floor': ?floor,
        },
      );
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((row) => StaffSessionModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<StaffSessionModel?> lookupByPlate(String plate) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.staffSessionLookup,
        queryParameters: {'plate': plate},
      );
      if (response.data == null) return null;
      return StaffSessionModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapDio(e);
    }
  }

  @override
  Future<StaffSessionModel> registerWalkIn({
    required String numberPlate,
    String? driverName,
    String? contactPhone,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.staffWalkIn,
        data: {
          'numberPlate': numberPlate,
          if (driverName != null && driverName.trim().isNotEmpty)
            'driverName': driverName.trim(),
          if (contactPhone != null && contactPhone.trim().isNotEmpty)
            'contactPhone': contactPhone.trim(),
        },
      );
      return StaffSessionModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<StaffSessionModel> checkout(String historyId) async {
    try {
      final response = await _dio.post(ApiEndpoints.staffCheckout(historyId));
      return StaffSessionModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<StaffSessionModel> collectPayment(String historyId) async {
    try {
      final response = await _dio.post(ApiEndpoints.staffCollect(historyId));
      return StaffSessionModel.fromJson(_asMap(response.data));
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
      message = (data['message'] ?? data['detail'] ?? data['error'] ?? message).toString();
    }
    return ServerException(message: message, statusCode: e.response?.statusCode);
  }
}
