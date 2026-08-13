/// Low-level exceptions thrown by the data layer (network, storage, etc.).
///
/// These are caught at repository boundaries and mapped into the matching
/// [Failure] types before being surfaced to the presentation layer.
abstract class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.cause,
  });

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// Thrown for server-side / unexpected API errors.
class ServerException extends AppException {
  const ServerException({
    super.message = 'Server error.',
    super.code,
    super.cause,
    this.statusCode,
  });

  final int? statusCode;
}

/// Thrown when the device has no usable network connection or a request
/// times out.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Network error.',
    super.code,
    super.cause,
  });
}

/// Thrown on authentication/authorization errors (401 / 403).
class AuthException extends AppException {
  const AuthException({
    super.message = 'Authentication error.',
    super.code,
    super.cause,
  });
}

/// Thrown on request validation errors (422 / 400).
class ValidationException extends AppException {
  const ValidationException({
    super.message = 'Validation error.',
    super.code,
    super.cause,
    this.fieldErrors = const {},
  });

  final Map<String, String> fieldErrors;
}

/// Thrown on payment gateway/transaction errors.
class PaymentException extends AppException {
  const PaymentException({
    super.message = 'Payment error.',
    super.code,
    super.cause,
  });
}

/// Thrown on local cache/persistence errors.
class CacheException extends AppException {
  const CacheException({
    super.message = 'Cache error.',
    super.code,
    super.cause,
  });
}

/// Catch-all for anything not otherwise classified.
class UnexpectedException extends AppException {
  const UnexpectedException({
    super.message = 'Unexpected error.',
    super.code,
    super.cause,
  });
}
