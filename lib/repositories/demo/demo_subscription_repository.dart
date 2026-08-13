import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/subscription_repository.dart';

class DemoSubscriptionRepository implements SubscriptionRepository {
  DemoSubscriptionRepository({DemoDataStore? store})
      : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;

  @override
  Future<List<SubscriptionPlanModel>> getPlans() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<SubscriptionPlanModel>.unmodifiable(_store.plans);
  }

  @override
  Future<SubscriptionModel?> getCurrent() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final userId = _store.currentUser?.id;
    final sub = _store.subscription;
    if (sub == null || userId == null || sub.userId != userId) return null;
    if (sub.expiryDate.isBefore(DateTime.now()) &&
        sub.status == SubscriptionStatus.active) {
      _store.subscription = sub.copyWith(status: SubscriptionStatus.expired);
    }
    return _store.subscription;
  }

  @override
  Future<List<PaymentModel>> getPaymentHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sorted = List<PaymentModel>.from(_store.payments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<PaymentModel>.unmodifiable(sorted);
  }
}
