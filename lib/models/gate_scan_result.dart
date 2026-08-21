import 'package:equatable/equatable.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';

/// Result of scanning a parking QR at the tower gate (entry or exit).
class GateScanResult extends Equatable {
  const GateScanResult({
    required this.valid,
    required this.message,
    this.action,
    this.vehicleNumber,
    this.slotLabel,
    this.entryAt,
    this.exitAt,
    this.durationSeconds,
    this.durationLabel,
    this.amountInPaise,
    this.amountRupees,
    this.billingType,
    this.hourlyRateRupees,
    this.historyId,
    this.paymentStatus,
    this.userName,
    this.userPhone,
    this.subscriptionType,
    this.tower,
    this.floor,
    this.zone,
    this.slotNumber,
    this.isWalkIn = false,
    this.bookingFeePaise,
    this.bookingFeeCreditPaise,
    this.grossAmountInPaise,
  });

  final bool valid;
  final String message;

  /// `entry` or `exit` when known.
  final String? action;
  final String? vehicleNumber;
  final String? slotLabel;
  final DateTime? entryAt;
  final DateTime? exitAt;
  final int? durationSeconds;
  final String? durationLabel;
  final int? amountInPaise;
  final double? amountRupees;
  final String? billingType;
  final double? hourlyRateRupees;
  final String? historyId;
  final String? paymentStatus;
  final String? userName;
  final String? userPhone;
  final String? subscriptionType;
  final String? tower;
  final int? floor;
  final String? zone;
  final String? slotNumber;
  final bool isWalkIn;
  final int? bookingFeePaise;
  final int? bookingFeeCreditPaise;
  final int? grossAmountInPaise;

  bool get isEntry {
    final a = action?.toLowerCase().trim();
    if (a == 'entry') return true;
    if (a == 'exit') return false;
    // Infer when action is missing from older responses.
    return valid && exitAt == null && entryAt != null;
  }

  bool get isExit {
    final a = action?.toLowerCase().trim();
    if (a == 'exit') return true;
    if (a == 'entry') return false;
    return exitAt != null || (amountInPaise ?? 0) > 0;
  }

  bool get needsPayment =>
      isExit &&
      paymentStatus == 'pending' &&
      (amountInPaise ?? 0) > 0;

  /// Builds a [ParkingHistoryModel] for the exit-receipt / pay flow.
  ParkingHistoryModel? toHistorySession() {
    final id = historyId;
    final plate = vehicleNumber;
    if (id == null || plate == null || entryAt == null) return null;

    final slotParts = _parseSlotLabel(slotLabel);
    final billing = billingType ?? subscriptionType ?? 'hourly';
    return ParkingHistoryModel(
      id: id,
      vehicleNumber: plate,
      entryAt: entryAt!,
      exitAt: exitAt,
      duration: durationSeconds != null
          ? Duration(seconds: durationSeconds!)
          : null,
      tower: tower ?? slotParts.$1,
      floor: floor ?? slotParts.$2,
      zone: zone ?? slotParts.$3,
      slotNumber: slotNumber ?? slotParts.$4,
      subscriptionType: SubscriptionPlanType.fromString(billing),
      billingType: billing,
      status: isExit
          ? ParkingHistoryStatus.completed
          : ParkingHistoryStatus.parked,
      amountInPaise: amountInPaise,
      paymentStatus: paymentStatus ?? (isExit ? 'pending' : 'free'),
      bookingFeePaise: bookingFeePaise ?? bookingFeeCreditPaise ?? 0,
      bookingFeePaid: (bookingFeePaise ?? bookingFeeCreditPaise ?? 0) > 0,
      grossAmountInPaise: grossAmountInPaise,
    );
  }

  factory GateScanResult.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    return GateScanResult(
      valid: json['valid'] as bool? ?? false,
      message: (json['message'] ?? '').toString(),
      action: json['action']?.toString().toLowerCase().trim(),
      vehicleNumber: (json['vehicleNumber'] ?? json['vehicle_number'])
          ?.toString(),
      slotLabel: (json['slotLabel'] ?? json['slot_label'])?.toString(),
      entryAt: parseDt(json['entryAt'] ?? json['entry_at']),
      exitAt: parseDt(json['exitAt'] ?? json['exit_at']),
      durationSeconds:
          asInt(json['durationSeconds'] ?? json['duration_seconds']),
      durationLabel:
          (json['durationLabel'] ?? json['duration_label'])?.toString(),
      amountInPaise: asInt(json['amountInPaise'] ?? json['amount_in_paise']),
      amountRupees: asDouble(json['amountRupees'] ?? json['amount_rupees']),
      billingType: (json['billingType'] ?? json['billing_type'])?.toString(),
      hourlyRateRupees:
          asDouble(json['hourlyRateRupees'] ?? json['hourly_rate_rupees']),
      historyId: (json['historyId'] ?? json['history_id'])?.toString(),
      paymentStatus:
          (json['paymentStatus'] ?? json['payment_status'])?.toString(),
      userName: (json['userName'] ?? json['user_name'])?.toString(),
      userPhone: (json['userPhone'] ?? json['user_phone'])?.toString(),
      subscriptionType:
          (json['subscriptionType'] ?? json['subscription_type'])?.toString(),
      tower: json['tower']?.toString(),
      floor: asInt(json['floor']),
      zone: json['zone']?.toString(),
      slotNumber: (json['slotNumber'] ?? json['slot_number'])?.toString(),
      isWalkIn: json['isWalkIn'] as bool? ??
          json['is_walk_in'] as bool? ??
          false,
      bookingFeePaise:
          asInt(json['bookingFeePaise'] ?? json['booking_fee_paise']),
      bookingFeeCreditPaise: asInt(
        json['bookingFeeCreditPaise'] ?? json['booking_fee_credit_paise'],
      ),
      grossAmountInPaise:
          asInt(json['grossAmountInPaise'] ?? json['gross_amount_in_paise']),
    );
  }

  /// Best-effort parse of labels like `Tower A · Floor 1 · Zone C · Slot C-01`.
  static (String, int, String, String) _parseSlotLabel(String? label) {
    if (label == null || label.isEmpty) {
      return ('A', 0, '-', '-');
    }
    String tower = 'A';
    int floor = 0;
    String zone = '-';
    String slot = '-';
    final towerMatch = RegExp(r'Tower\s+([A-Za-z0-9]+)').firstMatch(label);
    if (towerMatch != null) tower = towerMatch.group(1)!;
    final floorMatch = RegExp(r'Floor\s+(\d+)').firstMatch(label);
    if (floorMatch != null) floor = int.parse(floorMatch.group(1)!);
    final zoneMatch = RegExp(r'Zone\s+([A-Za-z0-9]+)').firstMatch(label);
    if (zoneMatch != null) zone = zoneMatch.group(1)!;
    final slotMatch = RegExp(r'Slot\s+([A-Za-z0-9\-]+)').firstMatch(label);
    if (slotMatch != null) slot = slotMatch.group(1)!;
    return (tower, floor, zone, slot);
  }

  @override
  List<Object?> get props => [
        valid,
        message,
        action,
        vehicleNumber,
        slotLabel,
        historyId,
        paymentStatus,
        amountInPaise,
      ];
}
