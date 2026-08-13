import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/qr_repository.dart';

class DemoQrRepository implements QrRepository {
  DemoQrRepository({DemoDataStore? store})
      : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;

  bool _isPermanentPlan(SubscriptionPlanType planType) =>
      planType == SubscriptionPlanType.annual ||
      planType == SubscriptionPlanType.monthly;

  @override
  Future<QrCodeModel?> getCurrentQr() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final existing = _store.currentQr;
    if (existing != null &&
        (existing.isPermanent || !existing.isExpired)) {
      return existing;
    }
    return null;
  }

  @override
  Future<QrCodeModel> refreshQr() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (_store.currentUser == null) {
      throw const ServerException(message: 'Not authenticated');
    }
    if (_store.currentSlot == null) {
      _store.allocateForPlan(SubscriptionPlanType.monthly);
    }

    final planType =
        _store.subscription?.planType ?? SubscriptionPlanType.hourly;
    final isPermanent = _isPermanentPlan(planType);
    final validity = isPermanent
        ? const Duration(days: 365)
        : const Duration(hours: 2);

    return _store.rebuildQr(isPermanent: isPermanent, validity: validity);
  }
}
