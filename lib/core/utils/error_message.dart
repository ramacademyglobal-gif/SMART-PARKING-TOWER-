import 'package:multiparking_tower/core/errors/exceptions.dart';

/// Converts a thrown error into a message safe to show to the user.
///
/// [AppException]s already carry curated, user-facing copy; anything else is
/// collapsed into a generic message so internal details never leak into the UI.
String describeError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is AppException) {
    return error.message.trim().isEmpty ? fallback : error.message;
  }
  return fallback;
}
