import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/vehicle_model.dart';
import 'package:multiparking_tower/repositories/vehicle_repository.dart';

class ApiVehicleRepository implements VehicleRepository {
  ApiVehicleRepository(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<List<VehicleModel>> list() async {
    try {
      final response = await _dio.get(ApiEndpoints.vehicles);
      final list = _asList(response.data);
      return list.map((e) => VehicleModel.fromJson(_asMap(e))).toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<VehicleModel> add({
    required String numberPlate,
    String? make,
    String? model,
    String? color,
    bool isDefault = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.vehicles,
        data: {
          'numberPlate': numberPlate.toUpperCase(),
          'make': make,
          'model': model,
          'color': color,
          'isDefault': isDefault,
        },
      );
      return VehicleModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<VehicleModel> update(VehicleModel vehicle) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.vehicleById(vehicle.id),
        data: vehicle.toJson(),
      );
      return VehicleModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<void> delete(String vehicleId) async {
    try {
      await _dio.delete(ApiEndpoints.vehicleById(vehicleId));
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<VehicleModel> setDefault(String vehicleId) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.vehicleById(vehicleId)}/default',
      );
      return VehicleModel.fromJson(_asMap(response.data));
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
