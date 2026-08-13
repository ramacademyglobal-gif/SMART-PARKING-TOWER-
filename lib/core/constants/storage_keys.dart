/// Keys used for persistent storage (secure storage & shared preferences).
///
/// Grouping keys here avoids typos and accidental collisions between the
/// secure-storage and preferences layers.
class StorageKeys {
  const StorageKeys._();

  // --- Secure storage (flutter_secure_storage) ---
  static const String accessToken = 'sk_access_token';
  static const String refreshToken = 'sk_refresh_token';
  static const String tokenExpiry = 'sk_token_expiry';
  static const String userId = 'sk_user_id';

  // --- Shared preferences ---
  static const String themeMode = 'pref_theme_mode';
  static const String language = 'pref_language';
  static const String defaultVehicleId = 'pref_default_vehicle_id';
  static const String onboardingSeen = 'pref_onboarding_seen';
  static const String fcmToken = 'pref_fcm_token';
  static const String lastSyncedAt = 'pref_last_synced_at';
  static const String biometricEnabled = 'pref_biometric_enabled';
  static const String notificationsEnabled = 'pref_notifications_enabled';
}
