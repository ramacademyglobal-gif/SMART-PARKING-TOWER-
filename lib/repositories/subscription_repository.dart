import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

abstract class SubscriptionRepository {
  Future<List<SubscriptionPlanModel>> getPlans();

  Future<SubscriptionModel?> getCurrent();

  Future<List<PaymentModel>> getPaymentHistory();
}
