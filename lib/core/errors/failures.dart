import 'package:equatable/equatable.dart';

/// Base type for all recoverable, user-facing error results.
///
/// Failures are returned from the domain/data layers (as opposed to
/// [Exception]s which are thrown lower down and mapped into failures).
sealed class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
    this.cause,
  });

  /// Human-readable, display-safe message.
  final String message;

  /// Optional machine-readable code (e.g. HTTP status or backend error code).
  final String? code;

  /// Optional underlying cause for logging/debugging.
  final Object? cause;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// A failure originating from the server (5xx / unexpected API responses).
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Something went wrong on our servers. Please try again.',
    super.code,
    super.cause,
    this.statusCode,
  });

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

/// Connectivity related failure (no internet, timeouts).
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code,
    super.cause,
  });
}

/// Authentication / authorization failure (401 / 403 / expired session).
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Your session has expired. Please sign in again.',
    super.code,
    super.cause,
  });
}

/// Validation failure, optionally with per-field error messages.
class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message = 'Please check the highlighted fields and try again.',
    super.code,
    super.cause,
    this.fieldErrors = const {},
  });

  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Payment gateway / transaction failure.
class PaymentFailure extends Failure {
  const PaymentFailure({
    super.message = 'Payment could not be completed. Please try again.',
    super.code,
    super.cause,
  });
}

/// Local cache / persistence failure.
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Unable to access local data.',
    super.code,
    super.cause,
  });
}

/// Catch-all for anything not otherwise classified.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code,
    super.cause,
  });
}
