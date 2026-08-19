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

  // Production member OTP uses Firebase Phone Auth. Demo stays offline.
  final shouldInitFirebase = config.isProduction || config.enableFirebase;
  if (shouldInitFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error, stackTrace) {
      debugPrint('Firebase initialization failed: $error\n$stackTrace');
      if (config.isProduction) {
        throw StateError(
          'Firebase failed to start. Confirm android/app/google-services.json '
          'and lib/firebase_options.dart exist for project multiparking-tower '
          '(package com.multiparking.multiparking_tower). Original error: $error',
        );
      }
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
