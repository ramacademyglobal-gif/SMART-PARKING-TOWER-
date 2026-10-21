import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/features/hub/presentation/providers/parking_service_provider.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';

/// Compact control to leave the current service and return to the chooser.
class ServiceSwitchBanner extends ConsumerWidget {
  const ServiceSwitchBanner({
    super.key,
    required this.label,
    this.foreground,
  });

  final String label;
  final Color? foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = foreground ?? Theme.of(context).colorScheme.primary;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.apps_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(authProvider.notifier).logout();
                } catch (_) {
                  // Open Space / unauthenticated — ignore tower logout errors.
                }
                await ref.read(parkingServiceModeProvider.notifier).clear();
              },
              child: const Text('Change service'),
            ),
          ],
        ),
      ),
    );
  }
}
