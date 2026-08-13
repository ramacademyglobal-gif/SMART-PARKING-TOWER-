import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/utils/validators.dart';
import 'package:multiparking_tower/models/vehicle_model.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// The user's garage, ordered with the default vehicle first.
class VehicleListController extends AsyncNotifier<List<VehicleModel>> {
  @override
  Future<List<VehicleModel>> build() async {
    return _sorted(await ref.watch(vehicleRepositoryProvider).list());
  }

  Future<void> refresh() async {
    state = const AsyncValue<List<VehicleModel>>.loading()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return _sorted(await ref.read(vehicleRepositoryProvider).list());
    });
  }

  /// Registers a vehicle after normalising and validating its number plate.
  ///
  /// Throws a [ValidationException] for an invalid plate so callers can show
  /// the message inline without the list falling into an error state.
  Future<VehicleModel> add({
    required String numberPlate,
    String? make,
    String? model,
    String? color,
    bool isDefault = false,
  }) async {
    final plate = Validators.normalizeVehicleRegistration(numberPlate);
    final plateError = Validators.vehicleRegistration(plate);
    if (plateError != null) {
      throw ValidationException(
        message: plateError,
        fieldErrors: {'numberPlate': plateError},
      );
    }

    final existing = state.valueOrNull ?? const <VehicleModel>[];
    if (existing.any((vehicle) => vehicle.numberPlate == plate)) {
      throw const ValidationException(
        message: 'This vehicle is already registered.',
      );
    }

    final created = await ref.read(vehicleRepositoryProvider).add(
          numberPlate: plate,
          make: _trimmed(make),
          model: _trimmed(model),
          color: _trimmed(color),
          isDefault: isDefault || existing.isEmpty,
        );

    // A newly added default demotes the others, so re-read the source of truth.
    await refresh();
    ref.read(selectedVehicleIdProvider.notifier).select(created.id);
    return created;
  }

  Future<VehicleModel> edit(VehicleModel vehicle) async {
    final plate = Validators.normalizeVehicleRegistration(vehicle.numberPlate);
    final plateError = Validators.vehicleRegistration(plate);
    if (plateError != null) {
      throw ValidationException(
        message: plateError,
        fieldErrors: {'numberPlate': plateError},
      );
    }

    final updated = await ref
        .read(vehicleRepositoryProvider)
        .update(vehicle.copyWith(numberPlate: plate));
    await refresh();
    return updated;
  }

  Future<void> remove(String vehicleId) async {
    await ref.read(vehicleRepositoryProvider).delete(vehicleId);
    if (ref.read(selectedVehicleIdProvider) == vehicleId) {
      ref.read(selectedVehicleIdProvider.notifier).clear();
    }
    await refresh();
  }

  Future<VehicleModel> setDefault(String vehicleId) async {
    final updated =
        await ref.read(vehicleRepositoryProvider).setDefault(vehicleId);
    await refresh();
    return updated;
  }

  List<VehicleModel> _sorted(List<VehicleModel> vehicles) {
    final sorted = [...vehicles]..sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final vehicleListProvider =
    AsyncNotifierProvider<VehicleListController, List<VehicleModel>>(
  VehicleListController.new,
);

/// The vehicle chosen for the current onboarding/parking flow.
class SelectedVehicleController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String vehicleId) => state = vehicleId;

  void clear() => state = null;
}

final selectedVehicleIdProvider =
    NotifierProvider<SelectedVehicleController, String?>(
  SelectedVehicleController.new,
);

final defaultVehicleProvider = Provider<VehicleModel?>((ref) {
  final vehicles = ref.watch(vehicleListProvider).valueOrNull;
  if (vehicles == null || vehicles.isEmpty) return null;
  for (final vehicle in vehicles) {
    if (vehicle.isDefault) return vehicle;
  }
  return vehicles.first;
});

/// The explicitly selected vehicle, falling back to the default one.
final selectedVehicleProvider = Provider<VehicleModel?>((ref) {
  final vehicles = ref.watch(vehicleListProvider).valueOrNull;
  if (vehicles == null || vehicles.isEmpty) return null;
  final selectedId = ref.watch(selectedVehicleIdProvider);
  if (selectedId != null) {
    for (final vehicle in vehicles) {
      if (vehicle.id == selectedId) return vehicle;
    }
  }
  return ref.watch(defaultVehicleProvider);
});

final hasVehiclesProvider = Provider<bool>((ref) {
  final vehicles = ref.watch(vehicleListProvider).valueOrNull;
  return vehicles != null && vehicles.isNotEmpty;
});
