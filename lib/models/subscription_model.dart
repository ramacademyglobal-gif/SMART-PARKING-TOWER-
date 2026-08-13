import 'package:equatable/equatable.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

enum SubscriptionStatus {
  active,
  expired,
  pending,
  cancelled;

  String get apiValue => name;

  static SubscriptionStatus fromString(String value) {
    return SubscriptionStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SubscriptionStatus.pending,
    );
  }
}

class SubscriptionModel extends Equatable {
  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.planType,
    required this.status,
    required this.startDate,
    required this.expiryDate,
    this.razorpayPaymentId,
  });

  final String id;
  final String userId;
  final SubscriptionPlanType planType;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime expiryDate;
  final String? razorpayPaymentId;

  bool get isActive =>
      status == SubscriptionStatus.active && expiryDate.isAfter(DateTime.now());

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      planType: SubscriptionPlanType.fromString(
        json['planType'] as String? ??
            json['plan_type'] as String? ??
            'monthly',
      ),
      status: SubscriptionStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
      startDate: DateTime.parse(
        json['startDate'] as String? ??
            json['start_date'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      expiryDate: DateTime.parse(
        json['expiryDate'] as String? ??
            json['expiry_date'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      razorpayPaymentId: json['razorpayPaymentId'] as String? ??
          json['razorpay_payment_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planType': planType.apiValue,
      'status': status.apiValue,
      'startDate': startDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'razorpayPaymentId': razorpayPaymentId,
    };
  }

  SubscriptionModel copyWith({
    String? id,
    String? userId,
    SubscriptionPlanType? planType,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? expiryDate,
    String? razorpayPaymentId,
    bool clearRazorpayPaymentId = false,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planType: planType ?? this.planType,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      razorpayPaymentId: clearRazorpayPaymentId
          ? null
          : (razorpayPaymentId ?? this.razorpayPaymentId),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        planType,
        status,
        startDate,
        expiryDate,
        razorpayPaymentId,
      ];
}
