import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/config/app_config.dart';
import 'package:multiparking_tower/core/services/connectivity_service.dart';
import 'package:multiparking_tower/core/services/dio_client.dart';
import 'package:multiparking_tower/core/services/local_storage_service.dart';
import 'package:multiparking_tower/core/services/logger_service.dart';
import 'package:multiparking_tower/core/services/secure_storage_service.dart';

/// Application configuration, resolved from `--dart-define` at build time.
///
/// Override this in `ProviderScope` for tests or custom environments.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// App-wide logger.
final loggerProvider = Provider<AppLogger>((ref) {
  final logger = AppLogger();
  ref.onDispose(logger.close);
  return logger;
});

/// Secure (encrypted) storage for tokens.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Shared-preferences backed local storage.
///
/// This must be overridden in `main()` after calling
/// [LocalStorageService.init], e.g.:
///
/// ```dart
/// final storage = LocalStorageService();
/// await storage.init();
/// runApp(ProviderScope(
///   overrides: [localStorageProvider.overrideWithValue(storage)],
///   child: const App(),
/// ));
/// ```
final localStorageProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
    'localStorageProvider must be overridden with an initialised instance.',
  );
});

/// Configured HTTP client (Dio wrapper) with auth + error mapping.
final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient(
    config: ref.watch(appConfigProvider),
    secureStorage: ref.watch(secureStorageProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});

/// Connectivity service instance.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Reactive stream of the current [ConnectivityResult].
final connectivityStatusProvider = StreamProvider<ConnectivityResult>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onStatusChanged;
});

/// Convenience boolean provider indicating whether the device is online.
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.maybeWhen(
    data: (result) => result != ConnectivityResult.none,
    orElse: () => true,
  );
});
