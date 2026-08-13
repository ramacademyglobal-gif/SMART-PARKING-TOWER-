import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/providers/auth_provider.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

enum OnboardingStep { none, vehicle, allocation, complete }

/// True once the user has confirmed which vehicle they are entering with during
/// the current app session. It resets on a cold start (and on logout).
/// Skipped when the member already has an active QR pass.
final vehicleSessionConfirmedProvider = StateProvider<bool>((ref) => false);

class OnboardingNotifier extends AsyncNotifier<OnboardingStep> {
  @override
  Future<OnboardingStep> build() async {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated) return OnboardingStep.none;
    // Recompute the step whenever the vehicle confirmation flag flips.
    ref.watch(vehicleSessionConfirmedProvider);
    return _resolveStep();
  }

  Future<OnboardingStep> _resolveStep() async {
    final user = ref.read(authProvider).user;
    if (user?.isStaff == true) return OnboardingStep.complete;

    // Subscriptions are optional — pay-as-you-go hourly users only need a vehicle.
    final vehicles = await ref.read(vehicleRepositoryProvider).list();
    if (vehicles.isEmpty) return OnboardingStep.vehicle;

    // Active visit / permanent QR → go straight to Home (skip vehicle re-pick).
    final qr = await ref.read(qrRepositoryProvider).getCurrentQr();
    if (qr != null && !qr.isExpired) {
      return OnboardingStep.complete;
    }

    // Returning users without an active pass confirm their vehicle each launch.
    if (!ref.read(vehicleSessionConfirmedProvider)) return OnboardingStep.vehicle;

    // Slot/QR can be created on demand; skip forced allocation for hourly users.
    return OnboardingStep.complete;
  }

  Future<void> refresh() async {
    if (!ref.read(authProvider).isAuthenticated) {
      state = const AsyncData(OnboardingStep.none);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(_resolveStep);
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, OnboardingStep>(
  OnboardingNotifier.new,
);
