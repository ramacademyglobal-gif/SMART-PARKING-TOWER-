import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/app.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/features/hub/domain/parking_service_mode.dart';
import 'package:multiparking_tower/features/hub/presentation/providers/parking_service_provider.dart';
import 'package:multiparking_tower/features/hub/presentation/screens/service_chooser_screen.dart';
import 'package:multiparking_tower/features/hub/presentation/widgets/open_space_service_host.dart';
import 'package:multiparking_tower/features/hub/presentation/widgets/service_switch_banner.dart';

/// Root of the single APK: chooser, or Tower / Open Space service trees.
class HubApp extends ConsumerWidget {
  const HubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(parkingServiceModeProvider);

    if (mode == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const ServiceChooserScreen(),
      );
    }

    return switch (mode) {
      ParkingServiceMode.tower => const _TowerServiceHost(),
      ParkingServiceMode.openSpace => const OpenSpaceServiceHost(),
    };
  }
}

class _TowerServiceHost extends StatelessWidget {
  const _TowerServiceHost();

  @override
  Widget build(BuildContext context) {
    // Theme wraps the overlay banner (sibling of MaterialApp.router).
    return Theme(
      data: AppTheme.light,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const MultiParkingApp(),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: ServiceSwitchBanner(
                  label: 'Tower service',
                  foreground: AppColors.tealDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
