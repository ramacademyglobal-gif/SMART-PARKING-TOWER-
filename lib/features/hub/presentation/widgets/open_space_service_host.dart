import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/features/hub/presentation/widgets/service_switch_banner.dart';
import 'package:open_space_parking/core/bootstrap/app_bootstrap.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/firebase/firebase_bootstrap.dart';
import 'package:open_space_parking/main.dart' show OpenSpaceParkingApp;

/// Boots Open Space DI/config once, then shows its MaterialApp.router tree.
class OpenSpaceServiceHost extends ConsumerStatefulWidget {
  const OpenSpaceServiceHost({super.key});

  @override
  ConsumerState<OpenSpaceServiceHost> createState() =>
      _OpenSpaceServiceHostState();
}

class _OpenSpaceServiceHostState extends ConsumerState<OpenSpaceServiceHost> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await EnvironmentConfig.initialize();
    await configureDependencies();
    await FirebaseBootstrap.ensureInitialized();
    await AppBootstrap.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Open Space failed to start.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const ServiceSwitchBanner(label: 'Open Space service'),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting Open Space Parking…'),
                  ],
                ),
              ),
            ),
          );
        }

        return Theme(
          data: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.tealDeep),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              fit: StackFit.expand,
              children: [
                OpenSpaceParkingApp(),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: SafeArea(
                    child: ServiceSwitchBanner(
                      label: 'Open Space service',
                      foreground: AppColors.tealDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
