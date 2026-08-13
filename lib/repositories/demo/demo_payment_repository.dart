import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/models/notification_model.dart';
import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/payment_repository.dart';

class DemoPaymentRepository implements PaymentRepository {
  DemoPaymentRepository({DemoDataStore? store})
      : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;

  @override
  Future<Map<String, dynamic>> createOrder(SubscriptionPlanType planType) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final plan = _store.planFor(planType);
    final orderId = _store.newId('order');
    _store.pendingOrders[orderId] = planType;

    _store.payments.insert(
      0,
      PaymentModel(
        id: _store.newId('pay'),
        amountInPaise: plan.priceInPaise,
        currency: 'INR',
        planType: planType,
        status: PaymentStatus.created,
        createdAt: DateTime.now(),
        razorpayOrderId: orderId,
      ),
    );

    return {
      'orderId': orderId,
      'amount': plan.priceInPaise,
      'currency': 'INR',
      'key': 'rzp_test_demo_multiparking',
    };
  }

  @override
  Future<SubscriptionModel> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final planType = _store.pendingOrders[orderId];
    if (planType == null) {
      throw const ServerException(message: 'Unknown payment order');
    }
    _store.pendingOrders.remove(orderId);

    final plan = _store.planFor(planType);
    final userId = _store.currentUser?.id ?? 'user_demo_001';
    final now = DateTime.now();

    final paymentIndex =
        _store.payments.indexWhere((p) => p.razorpayOrderId == orderId);
    if (paymentIndex >= 0) {
      _store.payments[paymentIndex] = _store.payments[paymentIndex].copyWith(
        status: PaymentStatus.success,
        razorpayPaymentId: paymentId,
      );
    } else {
      _store.payments.insert(
        0,
        PaymentModel(
          id: _store.newId('pay'),
          amountInPaise: plan.priceInPaise,
          currency: 'INR',
          planType: planType,
          status: PaymentStatus.success,
          createdAt: now,
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
        ),
      );
    }

    final subscription = SubscriptionModel(
      id: _store.newId('sub'),
      userId: userId,
      planType: planType,
      status: SubscriptionStatus.active,
      startDate: now,
      expiryDate: now.add(Duration(days: plan.durationDays)),
      razorpayPaymentId: paymentId,
    );
    _store.subscription = subscription;

    final slot = _store.allocateForPlan(planType);
    final isPermanent = planType == SubscriptionPlanType.annual ||
        planType == SubscriptionPlanType.monthly;
    _store.rebuildQr(
      isPermanent: isPermanent,
      validity: isPermanent
          ? Duration(days: plan.durationDays)
          : const Duration(hours: 2),
    );

    _store.notifications.insert(
      0,
      AppNotificationModel(
        id: _store.newId('notif'),
        title: 'Payment successful',
        body:
            '${plan.name} activated. Slot ${slot.displayLabel} allocated.',
        type: 'billing',
        createdAt: now,
        isRead: false,
        data: {
          'subscriptionId': subscription.id,
          'slotId': slot.id,
        },
      ),
    );

    return subscription;
  }
}
