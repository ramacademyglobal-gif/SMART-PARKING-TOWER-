import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/providers/core_providers.dart';
import 'package:multiparking_tower/core/services/local_storage_service.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._storage) : super(_storage.getThemeMode());

  final LocalStorageService _storage;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _storage.setThemeMode(mode);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(localStorageProvider));
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier(this._storage) : super(_storage.getLanguage());

  final LocalStorageService _storage;

  Future<void> setLanguage(String languageCode) async {
    if (state == languageCode) return;
    state = languageCode;
    await _storage.setLanguage(languageCode);
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier(ref.watch(localStorageProvider));
});

final localeProvider = Provider<Locale>((ref) {
  return Locale(ref.watch(languageProvider));
});

class NotificationsEnabledNotifier extends StateNotifier<bool> {
  NotificationsEnabledNotifier(this._storage)
      : super(_storage.getNotificationsEnabled());

  final LocalStorageService _storage;

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    await _storage.setNotificationsEnabled(enabled);
  }

  Future<void> toggle() => setEnabled(!state);
}

final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
  return NotificationsEnabledNotifier(ref.watch(localStorageProvider));
});
