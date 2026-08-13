import 'package:equatable/equatable.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

class QrCodeModel extends Equatable {
  const QrCodeModel({
    required this.token,
    required this.userName,
    required this.vehicleNumber,
    required this.slotLabel,
    required this.subscriptionType,
    required this.expiresAt,
    required this.isPermanent,
  });

  /// Opaque encrypted payload for scanner validation — never expose raw IDs.
  final String token;
  final String userName;
  final String vehicleNumber;
  final String slotLabel;
  final SubscriptionPlanType subscriptionType;
  final DateTime expiresAt;
  final bool isPermanent;

  bool get isExpired => !isPermanent && expiresAt.isBefore(DateTime.now());

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(
      token: json['token'] as String? ?? '',
      userName: json['userName'] as String? ??
          json['user_name'] as String? ??
          '',
      vehicleNumber: (json['vehicleNumber'] as String? ??
              json['vehicle_number'] as String? ??
              '')
          .toUpperCase(),
      slotLabel: json['slotLabel'] as String? ??
          json['slot_label'] as String? ??
          '',
      subscriptionType: SubscriptionPlanType.fromString(
        json['subscriptionType'] as String? ??
            json['subscription_type'] as String? ??
            'monthly',
      ),
      expiresAt: DateTime.parse(
        json['expiresAt'] as String? ??
            json['expires_at'] as String? ??
            DateTime.now().toIso8601String(),
      ).toLocal(),
      isPermanent: json['isPermanent'] as bool? ??
          json['is_permanent'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'userName': userName,
      'vehicleNumber': vehicleNumber,
      'slotLabel': slotLabel,
      'subscriptionType': subscriptionType.apiValue,
      'expiresAt': expiresAt.toIso8601String(),
      'isPermanent': isPermanent,
    };
  }

  QrCodeModel copyWith({
    String? token,
    String? userName,
    String? vehicleNumber,
    String? slotLabel,
    SubscriptionPlanType? subscriptionType,
    DateTime? expiresAt,
    bool? isPermanent,
  }) {
    return QrCodeModel(
      token: token ?? this.token,
      userName: userName ?? this.userName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      slotLabel: slotLabel ?? this.slotLabel,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      expiresAt: expiresAt ?? this.expiresAt,
      isPermanent: isPermanent ?? this.isPermanent,
    );
  }

  @override
  List<Object?> get props => [
        token,
        userName,
        vehicleNumber,
        slotLabel,
        subscriptionType,
        expiresAt,
        isPermanent,
      ];
}
