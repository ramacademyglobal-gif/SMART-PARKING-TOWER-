import 'package:equatable/equatable.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

enum PaymentStatus {
  created,
  pending,
  success,
  failed,
  cancelled;

  String get apiValue => name;

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PaymentStatus.pending,
    );
  }
}

class PaymentModel extends Equatable {
  const PaymentModel({
    required this.id,
    required this.amountInPaise,
    required this.currency,
    required this.planType,
    required this.status,
    required this.createdAt,
    this.razorpayOrderId,
    this.razorpayPaymentId,
  });

  final String id;
  final int amountInPaise;
  final String currency;
  final SubscriptionPlanType planType;
  final PaymentStatus status;
  final DateTime createdAt;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;

  double get amountInRupees => amountInPaise / 100.0;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      amountInPaise: json['amountInPaise'] as int? ??
          json['amount_in_paise'] as int? ??
          json['amount'] as int? ??
          0,
      currency: json['currency'] as String? ?? 'INR',
      planType: SubscriptionPlanType.fromString(
        json['planType'] as String? ??
            json['plan_type'] as String? ??
            'monthly',
      ),
      status: PaymentStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
      createdAt: DateTime.parse(
        json['createdAt'] as String? ??
            json['created_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      razorpayOrderId: json['razorpayOrderId'] as String? ??
          json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpayPaymentId'] as String? ??
          json['razorpay_payment_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amountInPaise': amountInPaise,
      'currency': currency,
      'planType': planType.apiValue,
      'status': status.apiValue,
      'createdAt': createdAt.toIso8601String(),
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
    };
  }

  PaymentModel copyWith({
    String? id,
    int? amountInPaise,
    String? currency,
    SubscriptionPlanType? planType,
    PaymentStatus? status,
    DateTime? createdAt,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    bool clearRazorpayOrderId = false,
    bool clearRazorpayPaymentId = false,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      amountInPaise: amountInPaise ?? this.amountInPaise,
      currency: currency ?? this.currency,
      planType: planType ?? this.planType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      razorpayOrderId: clearRazorpayOrderId
          ? null
          : (razorpayOrderId ?? this.razorpayOrderId),
      razorpayPaymentId: clearRazorpayPaymentId
          ? null
          : (razorpayPaymentId ?? this.razorpayPaymentId),
    );
  }

  @override
  List<Object?> get props => [
        id,
        amountInPaise,
        currency,
        planType,
        status,
        createdAt,
        razorpayOrderId,
        razorpayPaymentId,
      ];
}
