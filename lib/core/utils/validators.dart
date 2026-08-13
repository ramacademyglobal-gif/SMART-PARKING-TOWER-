import 'package:multiparking_tower/core/constants/app_constants.dart';

/// Reusable form/input validators returning `null` when valid, or an error
/// message string when invalid (compatible with Flutter's `FormField`).
class Validators {
  const Validators._();

  // ---------------------------------------------------------------------------
  // Phone
  // ---------------------------------------------------------------------------

  /// Validates an Indian mobile number. Accepts `+91`, `0` prefixes or a plain
  /// 10-digit number starting with 6-9. Spaces and punctuation are ignored.
  static String? indianPhone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Phone number is required';
    final local = normalizePhone(input);
    if (!AppConstants.indianPhoneLocalRegex.hasMatch(local)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Normalises a phone number to its plain 10-digit local form, stripping any
  /// `+91`, `91` or leading `0`. Returns the input unchanged if it cannot be
  /// normalised.
  static String normalizePhone(String value) {
    var digits = _digitsOnly(value);
    if (digits.length > 10) {
      if (digits.startsWith('91')) {
        digits = digits.substring(digits.length - 10);
      } else if (digits.startsWith('0')) {
        digits = digits.substring(digits.length - 10);
      } else {
        digits = digits.substring(digits.length - 10);
      }
    }
    return digits;
  }

  /// Returns the E.164-style phone number with the `+91` country code.
  static String toE164(String value) {
    final local = normalizePhone(value);
    return '${AppConstants.defaultCountryCode}$local';
  }

  // ---------------------------------------------------------------------------
  // OTP
  // ---------------------------------------------------------------------------

  /// Validates a 6-digit numeric OTP.
  static String? otp(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'OTP is required';
    if (!AppConstants.otpRegex.hasMatch(input)) {
      return 'Enter the ${AppConstants.otpLength}-digit code';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Vehicle registration
  // ---------------------------------------------------------------------------

  /// Validates an Indian vehicle registration number, e.g. `MH12AB1234`.
  /// The value is normalised (uppercase, no spaces/hyphens) before matching.
  static String? vehicleRegistration(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Vehicle number is required';
    final normalized = normalizeVehicleRegistration(input);
    if (!AppConstants.indianVehicleRegex.hasMatch(normalized)) {
      return 'Enter a valid number, e.g. MH12AB1234';
    }
    return null;
  }

  /// Uppercases and removes spaces/hyphens from a registration number.
  static String normalizeVehicleRegistration(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  }

  // ---------------------------------------------------------------------------
  // Generic
  // ---------------------------------------------------------------------------

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Email is required';
    if (!AppConstants.emailRegex.hasMatch(input)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? name(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Name is required';
    if (input.length < 2) return 'Name is too short';
    return null;
  }

  static String? minLength(String? value, int min, {String field = 'Value'}) {
    final input = value?.trim() ?? '';
    if (input.length < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');
}
