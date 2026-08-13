import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// The plan recommended to first-time users and preselected on the selection
/// screen.
const SubscriptionPlanType kRecommendedPlanType = SubscriptionPlanType.annual;

/// All purchasable plans, cheapest first so the comparison UI reads
/// monthly -> annual.
final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  final plans = await ref.watch(subscriptionRepositoryProvider).getPlans();
  return [...plans]..sort((a, b) => a.priceInPaise.compareTo(b.priceInPaise));
});

/// The signed-in user's subscription, or `null` when they have never subscribed.
final currentSubscriptionProvider = FutureProvider<SubscriptionModel?>((ref) {
  return ref.watch(subscriptionRepositoryProvider).getCurrent();
});

final paymentHistoryProvider = FutureProvider<List<PaymentModel>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).getPaymentHistory();
});

/// Whether onboarding can proceed past the plan gate. Treated as `false` while
/// loading so a first-time user is never let through on an unresolved state.
final hasActiveSubscriptionProvider = Provider<bool>((ref) {
  return ref.watch(currentSubscriptionProvider).maybeWhen(
        data: (subscription) => subscription?.isActive ?? false,
        orElse: () => false,
      );
});

final planByTypeProvider =
    Provider.family<SubscriptionPlanModel?, SubscriptionPlanType>((ref, type) {
  final plans = ref.watch(subscriptionPlansProvider).valueOrNull;
  if (plans == null) return null;
  for (final plan in plans) {
    if (plan.type == type) return plan;
  }
  return null;
});

/// Days left before the current subscription lapses, clamped at zero.
final subscriptionDaysRemainingProvider = Provider<int?>((ref) {
  final subscription = ref.watch(currentSubscriptionProvider).valueOrNull;
  if (subscription == null) return null;
  final days = subscription.expiryDate.difference(DateTime.now()).inDays;
  return days < 0 ? 0 : days;
});

/// The plan the user is about to buy.
///
/// Starts on [kRecommendedPlanType] so the checkout call to action is always
/// actionable, and the selection screen never has to write state during build.
class SelectedPlanController extends Notifier<SubscriptionPlanType> {
  @override
  SubscriptionPlanType build() => kRecommendedPlanType;

  void select(SubscriptionPlanType type) => state = type;

  void reset() => state = kRecommendedPlanType;
}

final selectedPlanProvider =
    NotifierProvider<SelectedPlanController, SubscriptionPlanType>(
  SelectedPlanController.new,
);

/// The full plan model behind [selectedPlanProvider], or `null` until plans
/// have loaded.
final selectedPlanModelProvider = Provider<SubscriptionPlanModel?>((ref) {
  return ref.watch(planByTypeProvider(ref.watch(selectedPlanProvider)));
});

/// Reloads everything the subscription screens render.
void refreshSubscriptionData(WidgetRef ref) {
  ref.invalidate(subscriptionPlansProvider);
  ref.invalidate(currentSubscriptionProvider);
  ref.invalidate(paymentHistoryProvider);
}
