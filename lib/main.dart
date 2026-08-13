import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/app.dart';
import 'package:multiparking_tower/core/config/app_config.dart';
import 'package:multiparking_tower/core/providers/core_providers.dart';
import 'package:multiparking_tower/core/services/local_storage_service.dart';
import 'package:multiparking_tower/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localStorage = LocalStorageService();
  await localStorage.init();

  final config = AppConfig.fromEnvironment();

  // Firebase is optional (FCM later). Member OTP uses MSG91 via the API.
  if (config.enableFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint('Firebase initialization failed: $error');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
        appConfigProvider.overrideWithValue(config),
      ],
      child: const MultiParkingApp(),
    ),
  );
}
