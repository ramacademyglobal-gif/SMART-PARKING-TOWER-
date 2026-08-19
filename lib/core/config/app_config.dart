import 'package:flutter/foundation.dart';

/// Runtime mode of the application.
///
/// [demo] uses mocked data and bypasses live integrations, while [production]
/// talks to real backend services and payment gateways.
enum AppMode {
  demo,
  production;

  static AppMode fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'production':
      case 'prod':
        return AppMode.production;
      case 'demo':
      default:
        return AppMode.demo;
    }
  }
}

/// Immutable, compile-time-overridable application configuration.
///
/// Values are read from `--dart-define` flags via [String.fromEnvironment] with
/// sensible defaults so the app runs out of the box in demo mode.
class AppConfig {
  const AppConfig({
    required this.appMode,
    required this.apiBaseUrl,
    required this.razorpayKeyId,
    required this.enableFirebase,
  });

  final AppMode appMode;
  final String apiBaseUrl;
  final String razorpayKeyId;
  final bool enableFirebase;

  bool get isDemo => appMode == AppMode.demo;
  bool get isProduction => appMode == AppMode.production;

  /// Builds an [AppConfig] from `--dart-define` environment values.
  factory AppConfig.fromEnvironment() {
    const modeRaw = String.fromEnvironment(
      'APP_MODE',
      defaultValue: 'demo',
    );
    const baseUrlRaw = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.multiparking.local/v1',
    );
    const razorpayKey = String.fromEnvironment(
      'RAZORPAY_KEY_ID',
      defaultValue: 'rzp_test_placeholder',
    );
    const enableFirebase = bool.fromEnvironment(
      'ENABLE_FIREBASE',
      defaultValue: true,
    );

    // Strip accidental trailing "." / "/" from dart-define typos (e.g. `/v1.`).
    var baseUrl = baseUrlRaw.trim();
    while (baseUrl.endsWith('.') || baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    final mode = AppMode.fromString(modeRaw);
    final lower = baseUrl.toLowerCase();
    final looksLocal = lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2') ||
        lower.contains('192.168.') ||
        lower.contains('multiparking.local');
    if (mode == AppMode.production && looksLocal) {
      debugPrint(
        'API_BASE_URL looks like a local/LAN host ($baseUrl). '
        'Release APKs must use a hosted HTTPS API, e.g. '
        'https://your-api.onrender.com/v1',
      );
    }

    return AppConfig(
      appMode: mode,
      apiBaseUrl: baseUrl,
      razorpayKeyId: razorpayKey,
      enableFirebase: enableFirebase,
    );
  }

  AppConfig copyWith({
    AppMode? appMode,
    String? apiBaseUrl,
    String? razorpayKeyId,
    bool? enableFirebase,
  }) {
    return AppConfig(
      appMode: appMode ?? this.appMode,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      razorpayKeyId: razorpayKeyId ?? this.razorpayKeyId,
      enableFirebase: enableFirebase ?? this.enableFirebase,
    );
  }

  @override
  String toString() =>
      'AppConfig(mode: ${appMode.name}, baseUrl: $apiBaseUrl, '
      'firebase: $enableFirebase)';
}
