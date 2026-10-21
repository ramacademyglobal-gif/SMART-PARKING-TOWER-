import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/providers/core_providers.dart';
import 'package:multiparking_tower/features/hub/domain/parking_service_mode.dart';

/// Currently selected service. `null` means show the chooser.
final parkingServiceModeProvider =
    NotifierProvider<ParkingServiceModeNotifier, ParkingServiceMode?>(
  ParkingServiceModeNotifier.new,
);

class ParkingServiceModeNotifier extends Notifier<ParkingServiceMode?> {
  @override
  ParkingServiceMode? build() {
    final storage = ref.read(localStorageProvider);
    return ParkingServiceModeX.fromStorage(storage.getParkingServiceMode());
  }

  Future<void> select(ParkingServiceMode mode) async {
    await ref.read(localStorageProvider).setParkingServiceMode(mode.storageValue);
    state = mode;
  }

  Future<void> clear() async {
    await ref.read(localStorageProvider).clearParkingServiceMode();
    state = null;
  }
}
