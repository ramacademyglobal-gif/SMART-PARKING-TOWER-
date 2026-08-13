import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multiparking_tower/core/constants/storage_keys.dart';

/// Wrapper around [SharedPreferences] for non-sensitive user preferences.
///
/// Call [init] once during app startup before accessing any getters/setters.
class LocalStorageService {
  LocalStorageService({SharedPreferences? preferences}) : _prefs = preferences;

  SharedPreferences? _prefs;

  SharedPreferences get _requirePrefs {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
        'LocalStorageService.init() must be called before use.',
      );
    }
    return prefs;
  }

  /// Loads the underlying [SharedPreferences] instance.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- Theme mode ---
  ThemeMode getThemeMode() {
    final raw = _requirePrefs.getString(StorageKeys.themeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _requirePrefs.setString(StorageKeys.themeMode, mode.name);

  // --- Language ---
  String getLanguage({String fallback = 'en'}) =>
      _requirePrefs.getString(StorageKeys.language) ?? fallback;

  Future<void> setLanguage(String code) =>
      _requirePrefs.setString(StorageKeys.language, code);

  // --- Default vehicle ---
  String? getDefaultVehicleId() =>
      _requirePrefs.getString(StorageKeys.defaultVehicleId);

  Future<void> setDefaultVehicleId(String id) =>
      _requirePrefs.setString(StorageKeys.defaultVehicleId, id);

  Future<void> clearDefaultVehicleId() =>
      _requirePrefs.remove(StorageKeys.defaultVehicleId);

  // --- Onboarding ---
  bool getOnboardingSeen() =>
      _requirePrefs.getBool(StorageKeys.onboardingSeen) ?? false;

  Future<void> setOnboardingSeen(bool seen) =>
      _requirePrefs.setBool(StorageKeys.onboardingSeen, seen);

  // --- FCM token ---
  String? getFcmToken() => _requirePrefs.getString(StorageKeys.fcmToken);

  Future<void> setFcmToken(String token) =>
      _requirePrefs.setString(StorageKeys.fcmToken, token);

  // --- Last synced ---
  DateTime? getLastSyncedAt() {
    final raw = _requirePrefs.getString(StorageKeys.lastSyncedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastSyncedAt(DateTime dt) => _requirePrefs.setString(
        StorageKeys.lastSyncedAt,
        dt.toUtc().toIso8601String(),
      );

  // --- Biometric ---
  bool getBiometricEnabled() =>
      _requirePrefs.getBool(StorageKeys.biometricEnabled) ?? false;

  Future<void> setBiometricEnabled(bool enabled) =>
      _requirePrefs.setBool(StorageKeys.biometricEnabled, enabled);

  // --- Notifications ---
  bool getNotificationsEnabled() =>
      _requirePrefs.getBool(StorageKeys.notificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) =>
      _requirePrefs.setBool(StorageKeys.notificationsEnabled, enabled);

  /// Clears all stored preferences.
  Future<void> clear() => _requirePrefs.clear();
}
