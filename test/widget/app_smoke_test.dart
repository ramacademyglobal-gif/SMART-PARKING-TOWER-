import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multiparking_tower/app.dart';
import 'package:multiparking_tower/core/config/app_config.dart';
import 'package:multiparking_tower/core/providers/core_providers.dart';
import 'package:multiparking_tower/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash screen renders MultiParking branding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              appMode: AppMode.demo,
              apiBaseUrl: 'https://api.multiparking.local/v1',
              razorpayKeyId: 'rzp_test_placeholder',
              enableFirebase: false,
            ),
          ),
        ],
        child: const MultiParkingApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('MultiParking'), findsWidgets);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
