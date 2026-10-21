import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/widgets/gradient_background.dart';
import 'package:multiparking_tower/features/hub/domain/parking_service_mode.dart';
import 'package:multiparking_tower/features/hub/presentation/providers/parking_service_provider.dart';

/// First screen of the hub APK — pick Tower or Open Space, then that service's login.
class ServiceChooserScreen extends ConsumerWidget {
  const ServiceChooserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GradientBackground(
      useScaffold: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),
            Text(
              'MultiParking',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose a service to continue',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.white.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 36),
            _ServiceCard(
              icon: Icons.apartment_rounded,
              title: ParkingServiceMode.tower.title,
              subtitle: ParkingServiceMode.tower.subtitle,
              onTap: () => ref
                  .read(parkingServiceModeProvider.notifier)
                  .select(ParkingServiceMode.tower),
            ),
            const SizedBox(height: 16),
            _ServiceCard(
              icon: Icons.map_rounded,
              title: ParkingServiceMode.openSpace.title,
              subtitle: ParkingServiceMode.openSpace.subtitle,
              onTap: () => ref
                  .read(parkingServiceModeProvider.notifier)
                  .select(ParkingServiceMode.openSpace),
            ),
            const Spacer(flex: 3),
            Text(
              'Each service has its own login and features',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.peachSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.tealDeep, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.tealDeep,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.tealDeep),
            ],
          ),
        ),
      ),
    );
  }
}
