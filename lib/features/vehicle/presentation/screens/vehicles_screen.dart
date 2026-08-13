import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/theme/app_colors.dart';
import 'package:multiparking_tower/core/theme/app_theme.dart';
import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/core/utils/extensions.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/widgets/empty_state.dart';
import 'package:multiparking_tower/core/widgets/loading_shimmer.dart';
import 'package:multiparking_tower/core/widgets/premium_card.dart';
import 'package:multiparking_tower/core/widgets/shell_back_button.dart';
import 'package:multiparking_tower/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:multiparking_tower/features/vehicle/presentation/widgets/vehicle_form.dart';
import 'package:multiparking_tower/models/vehicle_model.dart';

/// Vehicle management tab: list, add, set default and remove vehicles.
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('My vehicles'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(vehicleListProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.peachDeep,
        foregroundColor: AppColors.tealDark,
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add vehicle'),
      ),
      body: vehiclesAsync.when(
        loading: () => const ShimmerList(itemCount: 4),
        error: (_, __) => EmptyState.error(
          title: 'Could not load your vehicles',
          subtitle: 'Check your connection and try again.',
          onAction: () => ref.read(vehicleListProvider.notifier).refresh(),
        ),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return EmptyState(
              icon: Icons.directions_car_filled_outlined,
              title: 'No vehicles yet',
              subtitle:
                  'Add a vehicle to link it to your parking slot and QR pass.',
              actionLabel: 'Add vehicle',
              onAction: () => _openAddSheet(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(vehicleListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, index) => _VehicleTile(
                vehicle: vehicles[index],
                canDelete: vehicles.length > 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: 24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a vehicle',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 20),
              VehicleForm(
                autofocus: true,
                submitLabel: 'ADD VEHICLE',
                showDefaultToggle: true,
                onSaved: (_) => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleTile extends ConsumerWidget {
  const _VehicleTile({required this.vehicle, required this.canDelete});

  final VehicleModel vehicle;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final descriptors = [vehicle.make, vehicle.model, vehicle.color]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              gradient: vehicle.isDefault
                  ? AppColors.peachGradient
                  : null,
              color: vehicle.isDefault ? null : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: vehicle.isDefault
                  ? AppColors.tealDark
                  : scheme.onSurfaceVariant,
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
                const SizedBox(height: 4),
                Text(
                  descriptors.isEmpty
                      ? 'Added ${Formatters.date(vehicle.createdAt)}'
                      : descriptors,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<_VehicleAction>(
            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
            onSelected: (action) => _handle(context, ref, action),
            itemBuilder: (_) => [
              if (!vehicle.isDefault)
                const PopupMenuItem(
                  value: _VehicleAction.setDefault,
                  child: Text('Set as default'),
                ),
              PopupMenuItem(
                value: _VehicleAction.delete,
                enabled: canDelete,
                child: Text(
                  'Remove',
                  style: TextStyle(
                    color: canDelete ? AppColors.error : scheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _VehicleAction action,
  ) async {
    final controller = ref.read(vehicleListProvider.notifier);
    try {
      switch (action) {
        case _VehicleAction.setDefault:
          await controller.setDefault(vehicle.id);
          if (context.mounted) {
            context.showSnack('${vehicle.numberPlate} is now your default.');
          }
        case _VehicleAction.delete:
          final confirmed = await _confirmDelete(context);
          if (!confirmed) return;
          await controller.remove(vehicle.id);
          if (context.mounted) {
            context.showSnack('${vehicle.numberPlate} removed.');
          }
      }
    } catch (error) {
      if (!context.mounted) return;
      context.showSnack(
        describeError(error, fallback: 'That action could not be completed.'),
        isError: true,
      );
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text(
          '${vehicle.numberPlate} will lose access to your parking slot and '
          'QR pass.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

enum _VehicleAction { setDefault, delete }
