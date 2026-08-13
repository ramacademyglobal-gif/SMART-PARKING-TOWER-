import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/premium_button.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/tower_loading.dart';
import 'package:multiparking_tower/features/qr/presentation/providers/qr_provider.dart';
import 'package:multiparking_tower/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:multiparking_tower/features/vehicle/presentation/widgets/vehicle_form.dart';
import 'package:multiparking_tower/models/vehicle_model.dart';
import 'package:multiparking_tower/providers/onboarding_provider.dart';

/// Onboarding step 3 — register the first vehicle, or pick one already saved.
class VehicleOnboardingScreen extends ConsumerStatefulWidget {
  const VehicleOnboardingScreen({super.key});

  @override
  ConsumerState<VehicleOnboardingScreen> createState() =>
      _VehicleOnboardingScreenState();
}

class _VehicleOnboardingScreenState
    extends ConsumerState<VehicleOnboardingScreen> {
  /// Set when a returning user explicitly asks to register another vehicle.
  bool _isAddingVehicle = false;
  bool _isBooking = false;

  Future<void> _continueToAllocation() async {
    if (_isBooking) return;
    final vehicle = ref.read(selectedVehicleProvider);
    if (vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a vehicle to continue.')),
      );
      return;
    }
    setState(() => _isBooking = true);
    try {
      ref.read(selectedVehicleIdProvider.notifier).select(vehicle.id);
      // Persist as default so API entry/exit use this plate.
      try {
        await ref.read(vehicleListProvider.notifier).setDefault(vehicle.id);
      } catch (_) {
        // Demo or offline — selection still works in-session.
      }
      // Authentication/onboarding redirects can dispose this screen while the
      // request is in flight. Never touch WidgetRef after that happens.
      if (!mounted) return;
      // Mark this vehicle confirmed for the session so routing lets us through.
      ref.read(vehicleSessionConfirmedProvider.notifier).state = true;
      // Mint / refresh the visit QR for this booking.
      await ref.read(qrControllerProvider.notifier).refreshQr();
      if (!mounted) return;
      await ref.read(onboardingProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/home');
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      body: TowerLoadingOverlay(
        visible: _isBooking,
        message: 'Booking your slot',
        detail: 'Setting up your vehicle and generating your QR pass…',
        child: SafeArea(
          child: vehiclesAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => const TowerLoadingPanel(
              title: 'Loading your vehicles',
              subtitle: 'Fetching saved plates…',
              onDark: false,
            ),
            error: (_, __) => EmptyState.error(
              title: 'Could not load your vehicles',
              subtitle: 'Check your connection and try again.',
              onAction: () => ref.read(vehicleListProvider.notifier).refresh(),
            ),
            data: (vehicles) => _Body(
              vehicles: vehicles,
              isAddingVehicle: _isAddingVehicle || vehicles.isEmpty,
              onAddAnother: () => setState(() => _isAddingVehicle = true),
              onCancelAdd: () => setState(() => _isAddingVehicle = false),
              onContinue: _continueToAllocation,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.vehicles,
    required this.isAddingVehicle,
    required this.onAddAnother,
    required this.onCancelAdd,
    required this.onContinue,
  });

  final List<VehicleModel> vehicles;
  final bool isAddingVehicle;
  final VoidCallback onAddAnother;
  final VoidCallback onCancelAdd;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFirstVehicle = vehicles.isEmpty;
    final selectedId = ref.watch(selectedVehicleProvider)?.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            gradient: AppColors.peachGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            color: AppColors.tealDark,
            size: 28,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isAddingVehicle
              ? (isFirstVehicle ? 'Register your vehicle' : 'Add a vehicle')
              : 'Confirm your vehicle',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isAddingVehicle
              ? 'Your QR pass is linked to this number plate. '
                  'Without a plan you pay ₹50/hour when you exit.'
              : 'Select the car you are entering with to generate your QR pass.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        if (isAddingVehicle)
          PremiumCard(
            padding: const EdgeInsets.all(20),
            child: VehicleForm(
              autofocus: isFirstVehicle,
              submitLabel: 'BOOK A SLOT',
              showDefaultToggle: !isFirstVehicle,
              onSaved: (_) => onContinue(),
            ),
          )
        else
          for (final vehicle in vehicles) ...[
            _VehicleOption(
              vehicle: vehicle,
              isSelected: vehicle.id == selectedId,
              onTap: () => ref
                  .read(selectedVehicleIdProvider.notifier)
                  .select(vehicle.id),
            ),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 12),
        if (isAddingVehicle && !isFirstVehicle)
          PremiumButton.text(
            label: 'Use a saved vehicle instead',
            onPressed: onCancelAdd,
            expand: true,
          )
        else if (!isAddingVehicle) ...[
          PremiumButton.secondary(
            label: 'ADD ANOTHER VEHICLE',
            icon: Icons.add_rounded,
            onPressed: onAddAnother,
          ),
          const SizedBox(height: 14),
          PremiumButton(
            label: 'BOOK A SLOT',
            icon: Icons.local_parking_rounded,
            onPressed: onContinue,
          ),
        ],
      ],
    );
  }
}

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  final VehicleModel vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final descriptors = [vehicle.make, vehicle.model, vehicle.color]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');

    return PremiumCard(
      onTap: onTap,
      selected: isSelected,
      padding: const EdgeInsets.all(16),
      color: isSelected
          ? AppColors.peachSoft.withValues(alpha: 0.35)
          : scheme.surface,
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              Icons.directions_car_filled_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vehicle.numberPlate,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (vehicle.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (descriptors.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    descriptors,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            isSelected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected ? AppColors.peachDeep : scheme.outline,
          ),
        ],
      ),
    );
  }
}

