import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

abstract class PaymentRepository {
  /// Creates a Razorpay order. Returns order metadata for checkout.
  Future<Map<String, dynamic>> createOrder(SubscriptionPlanType planType);

  Future<SubscriptionModel> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}
