/// App-wide constant values that do not depend on runtime environment.
class AppConstants {
  const AppConstants._();

  // --- Identity ---
  static const String appName = 'MultiParking Tower';
  static const String appTagline = 'Smart parking, elevated.';
  static const String supportEmail = 'support@multiparking.local';
  static const String supportPhone = '+911800123456';

  // --- OTP ---
  static const int otpLength = 6;
  static const Duration otpResendCooldown = Duration(seconds: 30);
  static const Duration otpExpiry = Duration(minutes: 5);

  // --- Timeouts ---
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 45);
  static const Duration sendTimeout = Duration(seconds: 30);
  /// Firebase ID-token exchange can be slow on first cert fetch.
  static const Duration firebaseAuthTimeout = Duration(seconds: 60);
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration debounceDuration = Duration(milliseconds: 400);

  // --- QR ---
  static const Duration qrRefreshInterval = Duration(seconds: 30);

  // --- Pagination ---
  static const int defaultPageSize = 20;

  // --- Phone / country ---
  static const String defaultCountryCode = '+91';
  static const int indianPhoneLength = 10;

  /// Matches a 10-digit Indian mobile number (optionally prefixed with +91 or
  /// 0). Valid mobile numbers begin with 6-9.
  static final RegExp indianPhoneRegex = RegExp(r'^(?:\+91|0)?[6-9]\d{9}$');

  /// Strict 10-digit local form (no country code, first digit 6-9).
  static final RegExp indianPhoneLocalRegex = RegExp(r'^[6-9]\d{9}$');

  /// Matches a 6-digit numeric OTP.
  static final RegExp otpRegex = RegExp(r'^\d{6}$');

  /// Matches a standard Indian vehicle registration, e.g. `MH12AB1234`.
  /// Format: 2 state letters, 1-2 RTO digits, 1-3 series letters, 4 digits.
  static final RegExp indianVehicleRegex =
      RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}$');

  /// Matches an Indian email address (generic RFC-lite check).
  static final RegExp emailRegex =
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  // --- Subscription pricing (INR) ---
  static const Map<String, double> subscriptionPrices = {
    'daily': 99.0,
    'weekly': 499.0,
    'monthly': 1499.0,
    'quarterly': 3999.0,
    'yearly': 13999.0,
  };

  static const Map<String, String> subscriptionLabels = {
    'daily': 'Daily Pass',
    'weekly': 'Weekly Pass',
    'monthly': 'Monthly Pass',
    'quarterly': 'Quarterly Pass',
    'yearly': 'Annual Pass',
  };

  static const String currencyCode = 'INR';
  static const String currencySymbol = '\u20B9';

  // --- Vehicle types ---
  static const List<String> vehicleTypes = <String>[
    'Hatchback',
    'Sedan',
    'SUV',
    'Electric',
    'Bike',
  ];
}
