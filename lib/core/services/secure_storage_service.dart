import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:multiparking_tower/core/constants/storage_keys.dart';

/// Secure, encrypted storage for sensitive values such as JWT tokens.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  // --- Access token ---
  Future<String?> getAccessToken() =>
      _storage.read(key: StorageKeys.accessToken);

  Future<void> setAccessToken(String token) =>
      _storage.write(key: StorageKeys.accessToken, value: token);

  // --- Refresh token ---
  Future<String?> getRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  Future<void> setRefreshToken(String token) =>
      _storage.write(key: StorageKeys.refreshToken, value: token);

  // --- Token expiry ---
  Future<DateTime?> getTokenExpiry() async {
    final raw = await _storage.read(key: StorageKeys.tokenExpiry);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setTokenExpiry(DateTime expiry) => _storage.write(
        key: StorageKeys.tokenExpiry,
        value: expiry.toUtc().toIso8601String(),
      );

  // --- User id ---
  Future<String?> getUserId() => _storage.read(key: StorageKeys.userId);

  Future<void> setUserId(String id) =>
      _storage.write(key: StorageKeys.userId, value: id);

  // --- Composite helpers ---

  /// Persists a full token pair (and optional expiry/user id) in one call.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiry,
    String? userId,
  }) async {
    await Future.wait([
      setAccessToken(accessToken),
      setRefreshToken(refreshToken),
      if (expiry != null) setTokenExpiry(expiry),
      if (userId != null) setUserId(userId),
    ]);
  }

  /// True when an access token is present.
  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Clears only the auth token pair and related metadata.
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.refreshToken),
      _storage.delete(key: StorageKeys.tokenExpiry),
      _storage.delete(key: StorageKeys.userId),
    ]);
  }

  /// Wipes all secure storage (use on full logout / account deletion).
  Future<void> clearAll() => _storage.deleteAll();
}
