import 'package:equatable/equatable.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

enum ParkingHistoryStatus {
  parked,
  completed;

  String get apiValue => name;

  static ParkingHistoryStatus fromString(String value) {
    return ParkingHistoryStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ParkingHistoryStatus.completed,
    );
  }
}

class ParkingHistoryModel extends Equatable {
  const ParkingHistoryModel({
    required this.id,
    required this.vehicleNumber,
    required this.entryAt,
    this.exitAt,
    this.duration,
    required this.tower,
    required this.floor,
    required this.zone,
    required this.slotNumber,
    required this.subscriptionType,
    required this.status,
    this.amountInPaise,
    this.billingType = 'hourly',
    this.paymentStatus = 'free',
  });

  final String id;
  final String vehicleNumber;
  final DateTime entryAt;
  final DateTime? exitAt;
  final Duration? duration;
  final String tower;
  final int floor;
  final String zone;
  final String slotNumber;
  final SubscriptionPlanType subscriptionType;
  final ParkingHistoryStatus status;
  final int? amountInPaise;
  final String billingType;

  /// free | pending | paid
  final String paymentStatus;

  String get slotLabel =>
      'Tower $tower · Floor $floor · Zone $zone · Slot $slotNumber';

  double? get amountInRupees =>
      amountInPaise == null ? null : amountInPaise! / 100.0;

  bool get isHourly => billingType == 'hourly' || subscriptionType == SubscriptionPlanType.hourly;

  bool get isPaid => paymentStatus == 'paid';

  /// True when an hourly charge is still owed for this (completed) session.
  bool get needsPayment =>
      paymentStatus == 'pending' && (amountInPaise ?? 0) > 0;

  factory ParkingHistoryModel.fromJson(Map<String, dynamic> json) {
    final durationSeconds = json['durationSeconds'] as int? ??
        json['duration_seconds'] as int? ??
        json['duration'] as int?;
    final billing = json['billingType'] as String? ??
        json['billing_type'] as String? ??
        json['subscriptionType'] as String? ??
        json['subscription_type'] as String? ??
        'hourly';
    return ParkingHistoryModel(
      id: json['id'] as String,
      vehicleNumber: (json['vehicleNumber'] as String? ??
              json['vehicle_number'] as String? ??
              '')
          .toUpperCase(),
      entryAt: DateTime.parse(
        json['entryAt'] as String? ??
            json['entry_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      exitAt: () {
        final rawExit =
            json['exitAt'] as String? ?? json['exit_at'] as String?;
        return rawExit != null ? DateTime.parse(rawExit) : null;
      }(),
      duration:
          durationSeconds != null ? Duration(seconds: durationSeconds) : null,
      tower: json['tower'] as String? ?? '',
      floor: json['floor'] as int? ?? 0,
      zone: json['zone'] as String? ?? '',
      slotNumber: json['slotNumber'] as String? ??
          json['slot_number'] as String? ??
          '',
      subscriptionType: SubscriptionPlanType.fromString(billing),
      status: ParkingHistoryStatus.fromString(
        json['status'] as String? ?? 'completed',
      ),
      amountInPaise: json['amountInPaise'] as int? ??
          json['amount_in_paise'] as int?,
      billingType: billing,
      paymentStatus: json['paymentStatus'] as String? ??
          json['payment_status'] as String? ??
          'free',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleNumber': vehicleNumber,
      'entryAt': entryAt.toIso8601String(),
      'exitAt': exitAt?.toIso8601String(),
      'durationSeconds': duration?.inSeconds,
      'tower': tower,
      'floor': floor,
      'zone': zone,
      'slotNumber': slotNumber,
      'subscriptionType': subscriptionType.apiValue,
      'status': status.apiValue,
      'amountInPaise': amountInPaise,
      'billingType': billingType,
      'paymentStatus': paymentStatus,
    };
  }

  ParkingHistoryModel copyWith({
    String? id,
    String? vehicleNumber,
    DateTime? entryAt,
    DateTime? exitAt,
    Duration? duration,
    String? tower,
    int? floor,
    String? zone,
    String? slotNumber,
    SubscriptionPlanType? subscriptionType,
    ParkingHistoryStatus? status,
    int? amountInPaise,
    String? billingType,
    String? paymentStatus,
    bool clearExitAt = false,
    bool clearDuration = false,
    bool clearAmount = false,
  }) {
    return ParkingHistoryModel(
      id: id ?? this.id,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      entryAt: entryAt ?? this.entryAt,
      exitAt: clearExitAt ? null : (exitAt ?? this.exitAt),
      duration: clearDuration ? null : (duration ?? this.duration),
      tower: tower ?? this.tower,
      floor: floor ?? this.floor,
      zone: zone ?? this.zone,
      slotNumber: slotNumber ?? this.slotNumber,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      status: status ?? this.status,
      amountInPaise: clearAmount ? null : (amountInPaise ?? this.amountInPaise),
      billingType: billingType ?? this.billingType,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  @override
  List<Object?> get props => [
        id,
        vehicleNumber,
        entryAt,
        exitAt,
        duration,
        tower,
        floor,
        zone,
        slotNumber,
        subscriptionType,
        status,
        amountInPaise,
        billingType,
        paymentStatus,
      ];
}
