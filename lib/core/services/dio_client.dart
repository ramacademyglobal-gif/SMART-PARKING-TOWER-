import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:multiparking_tower/core/config/app_config.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/core/constants/app_constants.dart';
import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/services/logger_service.dart';
import 'package:multiparking_tower/core/services/secure_storage_service.dart';

/// Configured [Dio] HTTP client with auth, logging, refresh and error mapping.
///
/// Use [dio] to perform requests. All `DioException`s are converted into typed
/// [AppException]s so callers never need to inspect raw Dio errors.
class DioClient {
  DioClient({
    required AppConfig config,
    required SecureStorageService secureStorage,
    required AppLogger logger,
    Dio? dio,
  })  : _config = config,
        _secureStorage = secureStorage,
        _logger = logger {
    _dio = dio ?? Dio();
    _configure();
  }

  final AppConfig _config;
  final SecureStorageService _secureStorage;
  final AppLogger _logger;
  late final Dio _dio;

  /// Guards against concurrent refresh attempts.
  Future<String?>? _refreshCall;

  Dio get dio => _dio;

  void _configure() {
    _dio.options = BaseOptions(
      baseUrl: _config.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      responseType: ResponseType.json,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
    );

    _dio.interceptors.add(_authInterceptor());

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 100,
        ),
      );
    }
  }

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.extra['skipAuth'] == true;
        if (!skipAuth) {
          final token = await _secureStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final response = error.response;
        final requestOptions = error.requestOptions;
        final isUnauthorized = response?.statusCode == 401;
        final alreadyRetried = requestOptions.extra['retried'] == true;
        final isRefreshCall =
            requestOptions.path.contains(ApiEndpoints.refreshToken);

        if (isUnauthorized && !alreadyRetried && !isRefreshCall) {
          try {
            final newToken = await _refreshToken();
            if (newToken != null && newToken.isNotEmpty) {
              final retried = await _retryRequest(requestOptions, newToken);
              return handler.resolve(retried);
            }
          } catch (e, s) {
            _logger.w('Token refresh failed', error: e, stackTrace: s);
            await _secureStorage.clearTokens();
          }
        }

        handler.reject(error);
      },
    );
  }

  /// Refreshes the access token exactly once for concurrent 401s.
  Future<String?> _refreshToken() {
    return _refreshCall ??= _performRefresh().whenComplete(() {
      _refreshCall = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthException(message: 'Missing refresh token.');
    }

    // Use a bare Dio instance to avoid interceptor recursion.
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: _config.apiBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );

    final response = await refreshDio.post<Map<String, dynamic>>(
      ApiEndpoints.refreshToken,
      data: {'refresh_token': refreshToken},
    );

    final data = response.data ?? const {};
    final newAccess = (data['accessToken'] ?? data['access_token']) as String?;
    final newRefresh =
        (data['refreshToken'] ?? data['refresh_token']) as String?;

    if (newAccess == null || newAccess.isEmpty) {
      throw const AuthException(message: 'Refresh response missing token.');
    }

    await _secureStorage.setAccessToken(newAccess);
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await _secureStorage.setRefreshToken(newRefresh);
    }
    _logger.i('Access token refreshed.');
    return newAccess;
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions options,
    String token,
  ) {
    final newOptions = Options(
      method: options.method,
      headers: {
        ...options.headers,
        'Authorization': 'Bearer $token',
      },
      responseType: options.responseType,
      contentType: options.contentType,
      extra: {...options.extra, 'retried': true},
    );

    return _dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      cancelToken: options.cancelToken,
      options: newOptions,
    );
  }

  // ---------------------------------------------------------------------------
  // Typed request helpers with error mapping
  // ---------------------------------------------------------------------------

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(() => _dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(() => _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(() => _dio.put<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(() => _dio.patch<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(() => _dio.delete<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw mapError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
      }
      return response;
    } on DioException catch (e) {
      throw mapError(e);
    } on AppException {
      rethrow;
    } catch (e, s) {
      _logger.e('Unexpected request error', error: e, stackTrace: s);
      throw UnexpectedException(message: e.toString(), cause: e);
    }
  }

  /// Maps a [DioException] into a typed [AppException].
  AppException mapError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          message: 'The connection timed out. Please try again.',
          code: 'timeout',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          message: 'No internet connection. Please check your network.',
          code: 'connection',
        );
      case DioExceptionType.cancel:
        return const NetworkException(
          message: 'Request cancelled.',
          code: 'cancelled',
        );
      case DioExceptionType.badCertificate:
        return const NetworkException(
          message: 'Secure connection failed.',
          code: 'bad_certificate',
        );
      case DioExceptionType.badResponse:
        return _mapResponse(error);
      case DioExceptionType.unknown:
        return UnexpectedException(
          message: error.message ?? 'An unexpected error occurred.',
          cause: error.error,
        );
      default:
        return UnexpectedException(
          message: error.message ?? 'An unexpected error occurred.',
          cause: error.error,
        );
    }
  }

  AppException _mapResponse(DioException error) {
    final response = error.response;
    final status = response?.statusCode ?? 0;
    final data = response?.data;
    final serverMessage = _extractMessage(data);
    final serverCode = _extractCode(data);

    switch (status) {
      case 400:
      case 422:
        return ValidationException(
          message: serverMessage ?? 'Please check your input and try again.',
          code: serverCode ?? '$status',
          fieldErrors: _extractFieldErrors(data),
        );
      case 401:
        return AuthException(
          message: serverMessage ?? 'Your session has expired.',
          code: serverCode ?? '401',
        );
      case 403:
        return AuthException(
          message: serverMessage ?? 'You are not allowed to do that.',
          code: serverCode ?? '403',
        );
      case 402:
        return PaymentException(
          message: serverMessage ?? 'Payment required or failed.',
          code: serverCode ?? '402',
        );
      case 404:
        return ServerException(
          message: serverMessage ?? 'The requested resource was not found.',
          code: serverCode ?? '404',
          statusCode: status,
        );
      default:
        return ServerException(
          message: serverMessage ?? 'Something went wrong. Please try again.',
          code: serverCode ?? '$status',
          statusCode: status,
        );
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }

  String? _extractCode(dynamic data) {
    if (data is Map) {
      final code = data['code'] ?? data['error_code'];
      if (code != null) return code.toString();
    }
    return null;
  }

  Map<String, String> _extractFieldErrors(dynamic data) {
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      return errors.map(
        (key, value) => MapEntry(
          key.toString(),
          value is List ? value.join(', ') : value.toString(),
        ),
      );
    }
    return const {};
  }
}
