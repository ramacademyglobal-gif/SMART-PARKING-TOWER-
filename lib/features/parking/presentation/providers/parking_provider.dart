import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/core/utils/error_message.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// The slot currently assigned to the user, or `null` before allocation.
final currentSlotProvider = FutureProvider<ParkingSlotModel?>((ref) {
  return ref.watch(parkingRepositoryProvider).getCurrentSlot();
});

/// True only when staff has recorded a live parked session (not mere allotment).
final activeParkedSessionProvider =
    FutureProvider.autoDispose<ParkingHistoryModel?>((ref) async {
  final rows = await ref
      .watch(parkingRepositoryProvider)
      .getHistory(filter: 'parked');
  if (rows.isEmpty) return null;
  return rows.first;
});

/// Latest hourly exit that still needs payment — shown on Home until settled.
final pendingParkingPaymentProvider =
    FutureProvider.autoDispose<ParkingHistoryModel?>((ref) async {
  final rows = await ref
      .watch(parkingRepositoryProvider)
      .getHistory(filter: 'pending');
  for (final row in rows) {
    if (row.needsPayment) return row;
  }
  return null;
});

/// Poll Home parking state so exit payments appear soon after a staff scan.
final homeParkingPulseProvider = StreamProvider.autoDispose<int>((ref) {
  final controller = StreamController<int>();
  var tick = 0;
  controller.add(tick);
  final timer = Timer.periodic(const Duration(seconds: 4), (_) {
    tick += 1;
    controller.add(tick);
    ref.invalidate(pendingParkingPaymentProvider);
    ref.invalidate(activeParkedSessionProvider);
    ref.invalidate(currentSlotProvider);
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Search/segment filters applied to the parking history list.
class ParkingHistoryFilter extends Equatable {
  const ParkingHistoryFilter({this.search = '', this.filter});

  final String search;

  /// Backend filter token, e.g. `parked`, `completed`, `monthly`, `annual`.
  final String? filter;

  ParkingHistoryFilter copyWith({
    String? search,
    String? filter,
    bool clearFilter = false,
  }) {
    return ParkingHistoryFilter(
      search: search ?? this.search,
      filter: clearFilter ? null : (filter ?? this.filter),
    );
  }

  @override
  List<Object?> get props => [search, filter];
}

class ParkingHistoryFilterController extends Notifier<ParkingHistoryFilter> {
  @override
  ParkingHistoryFilter build() => const ParkingHistoryFilter();

  void setSearch(String search) => state = state.copyWith(search: search);

  void setFilter(String? filter) {
    state = filter == null
        ? state.copyWith(clearFilter: true)
        : state.copyWith(filter: filter);
  }

  void reset() => state = const ParkingHistoryFilter();
}

final parkingHistoryFilterProvider = NotifierProvider<
    ParkingHistoryFilterController, ParkingHistoryFilter>(
  ParkingHistoryFilterController.new,
);

final parkingHistoryProvider =
    FutureProvider<List<ParkingHistoryModel>>((ref) {
  final filters = ref.watch(parkingHistoryFilterProvider);
  return ref.watch(parkingRepositoryProvider).getHistory(
        search: filters.search.trim().isEmpty ? null : filters.search.trim(),
        filter: filters.filter,
      );
});

/// Ordered stages shown on the allocation screen.
enum SlotAllocationStep {
  findingSlot('Finding nearest slot'),
  reserving('Reserving your slot'),
  generatingQr('Generating secure QR');

  const SlotAllocationStep(this.label);

  final String label;
}

enum SlotAllocationStatus { idle, inProgress, success, failed }

class SlotAllocationState extends Equatable {
  const SlotAllocationState({
    this.status = SlotAllocationStatus.idle,
    this.completedSteps = 0,
    this.slot,
    this.qrCode,
    this.errorMessage,
  });

  final SlotAllocationStatus status;

  /// Number of finished steps; equals `SlotAllocationStep.values.length` once
  /// allocation succeeds.
  final int completedSteps;
  final ParkingSlotModel? slot;
  final QrCodeModel? qrCode;
  final String? errorMessage;

  SlotAllocationStep? get activeStep {
    if (status != SlotAllocationStatus.inProgress) return null;
    if (completedSteps >= SlotAllocationStep.values.length) return null;
    return SlotAllocationStep.values[completedSteps];
  }

  double get progress =>
      completedSteps / SlotAllocationStep.values.length;

  SlotAllocationState copyWith({
    SlotAllocationStatus? status,
    int? completedSteps,
    ParkingSlotModel? slot,
    QrCodeModel? qrCode,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SlotAllocationState(
      status: status ?? this.status,
      completedSteps: completedSteps ?? this.completedSteps,
      slot: slot ?? this.slot,
      qrCode: qrCode ?? this.qrCode,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, completedSteps, slot, qrCode, errorMessage];
}

/// Runs slot allocation as visible stages so onboarding feels deliberate
/// rather than instantaneous.
class SlotAllocationController extends Notifier<SlotAllocationState> {
  /// Minimum time each stage stays on screen.
  static const Duration _stepDwell = Duration(milliseconds: 900);

  @override
  SlotAllocationState build() => const SlotAllocationState();

  Future<void> allocate() async {
    if (state.status == SlotAllocationStatus.inProgress) return;
    state = const SlotAllocationState(status: SlotAllocationStatus.inProgress);

    try {
      await Future<void>.delayed(_stepDwell);
      state = state.copyWith(completedSteps: 1);

      final slot = await ref.read(parkingRepositoryProvider).allocateSlot();
      state = state.copyWith(completedSteps: 2, slot: slot);

      final qrCode = await ref.read(qrRepositoryProvider).refreshQr();
      await Future<void>.delayed(_stepDwell);

      state = state.copyWith(
        status: SlotAllocationStatus.success,
        completedSteps: SlotAllocationStep.values.length,
        qrCode: qrCode,
      );
      ref.invalidate(currentSlotProvider);
    } catch (error) {
      state = state.copyWith(
        status: SlotAllocationStatus.failed,
        errorMessage: describeError(
          error,
          fallback: 'We could not reserve a slot right now.',
        ),
      );
    }
  }

  void reset() => state = const SlotAllocationState();
}

final slotAllocationControllerProvider =
    NotifierProvider<SlotAllocationController, SlotAllocationState>(
  SlotAllocationController.new,
);
