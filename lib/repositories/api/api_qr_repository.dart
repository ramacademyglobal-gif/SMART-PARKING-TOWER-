import 'package:dio/dio.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/repositories/qr_repository.dart';

class ApiQrRepository implements QrRepository {
  ApiQrRepository(this._client);

  final DioClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<QrCodeModel?> getCurrentQr() async {
    try {
      final response = await _dio.get(ApiEndpoints.currentQr);
      if (response.data == null) return null;
      return QrCodeModel.fromJson(_asMap(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapDio(e);
    }
  }

  @override
  Future<QrCodeModel> refreshQr() async {
    try {
      final response = await _dio.post(ApiEndpoints.refreshQr);
      return QrCodeModel.fromJson(_asMap(response.data));
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
