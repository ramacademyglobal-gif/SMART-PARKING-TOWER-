import 'package:equatable/equatable.dart';

/// Live bay / session shown on the staff console.
class StaffSessionModel extends Equatable {
  const StaffSessionModel({
    required this.id,
    required this.vehicleNumber,
    required this.slotLabel,
    required this.tower,
    required this.floor,
    required this.zone,
    required this.slotNumber,
    required this.entryAt,
    required this.status,
    this.driverName,
    this.contactPhone,
    this.userName,
    this.userPhone,
    this.isWalkIn = false,
    this.exitAt,
    this.durationSeconds,
    this.durationLabel,
    this.billingType = 'hourly',
    this.paymentStatus = 'free',
    this.amountInPaise,
    this.amountRupees,
    this.hourlyRateRupees = 50,
  });

  final String id;
  final String vehicleNumber;
  final String? driverName;
  final String? contactPhone;
  final String? userName;
  final String? userPhone;
  final bool isWalkIn;
  final String slotLabel;
  final String tower;
  final int floor;
  final String zone;
  final String slotNumber;
  final DateTime entryAt;
  final DateTime? exitAt;
  final int? durationSeconds;
  final String? durationLabel;
  final String status;
  final String billingType;
  final String paymentStatus;
  final int? amountInPaise;
  final double? amountRupees;
  final double hourlyRateRupees;

  bool get isParked => status == 'parked';
  bool get needsPayment =>
      paymentStatus == 'pending' && (amountInPaise ?? 0) > 0;

  factory StaffSessionModel.fromJson(Map<String, dynamic> json) {
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

    final label = (json['slotLabel'] ?? json['slot_label'] ?? '').toString();
    final labelFloor = _floorFromSlotLabel(label);
    final jsonFloor = asInt(json['floor']);
    // Filter uses [floor]; the card shows [slotLabel]. Keep them aligned.
    final floor = labelFloor != 0 ? labelFloor : (jsonFloor ?? 0);

    return StaffSessionModel(
      id: (json['id'] ?? '').toString(),
      vehicleNumber:
          (json['vehicleNumber'] ?? json['vehicle_number'] ?? '').toString(),
      driverName: (json['driverName'] ?? json['driver_name'])?.toString(),
      contactPhone:
          (json['contactPhone'] ?? json['contact_phone'])?.toString(),
      userName: (json['userName'] ?? json['user_name'])?.toString(),
      userPhone: (json['userPhone'] ?? json['user_phone'])?.toString(),
      isWalkIn: json['isWalkIn'] as bool? ??
          json['is_walk_in'] as bool? ??
          false,
      slotLabel: label,
      tower: (json['tower'] ?? 'A').toString(),
      floor: floor,
      zone: (json['zone'] ?? '-').toString(),
      slotNumber: (json['slotNumber'] ?? json['slot_number'] ?? '-').toString(),
      entryAt: parseDt(json['entryAt'] ?? json['entry_at']) ?? DateTime.now(),
      exitAt: parseDt(json['exitAt'] ?? json['exit_at']),
      durationSeconds:
          asInt(json['durationSeconds'] ?? json['duration_seconds']),
      durationLabel:
          (json['durationLabel'] ?? json['duration_label'])?.toString(),
      status: (json['status'] ?? 'parked').toString(),
      billingType:
          (json['billingType'] ?? json['billing_type'] ?? 'hourly').toString(),
      paymentStatus:
          (json['paymentStatus'] ?? json['payment_status'] ?? 'free')
              .toString(),
      amountInPaise: asInt(json['amountInPaise'] ?? json['amount_in_paise']),
      amountRupees: asDouble(json['amountRupees'] ?? json['amount_rupees']),
      hourlyRateRupees: asDouble(
            json['hourlyRateRupees'] ?? json['hourly_rate_rupees'],
          ) ??
          50,
    );
  }

  @override
  List<Object?> get props => [id, vehicleNumber, status, paymentStatus];

  static int _floorFromSlotLabel(String label) {
    final match = RegExp(r'Floor\s+(\d+)').firstMatch(label);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }
}

/// Dashboard snapshot for the gate-staff home screen.
class StaffOverviewModel extends Equatable {
  const StaffOverviewModel({
    required this.staffName,
    required this.role,
    required this.totalSlots,
    required this.occupiedSlots,
    required this.availableSlots,
    required this.parkedNow,
    required this.walkInsParked,
    required this.entriesToday,
    required this.exitsToday,
    required this.pendingPayments,
    required this.collectedTodayRupees,
    this.hourlyRateRupees = 50,
  });

  final String staffName;
  final String role;
  final int totalSlots;
  final int occupiedSlots;
  final int availableSlots;
  final int parkedNow;
  final int walkInsParked;
  final int entriesToday;
  final int exitsToday;
  final int pendingPayments;
  final double collectedTodayRupees;
  final double hourlyRateRupees;

  factory StaffOverviewModel.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    return StaffOverviewModel(
      staffName: (json['staffName'] ?? json['staff_name'] ?? 'Staff').toString(),
      role: (json['role'] ?? 'staff').toString(),
      totalSlots: asInt(json['totalSlots'] ?? json['total_slots']),
      occupiedSlots: asInt(json['occupiedSlots'] ?? json['occupied_slots']),
      availableSlots: asInt(json['availableSlots'] ?? json['available_slots']),
      parkedNow: asInt(json['parkedNow'] ?? json['parked_now']),
      walkInsParked: asInt(json['walkInsParked'] ?? json['walk_ins_parked']),
      entriesToday: asInt(json['entriesToday'] ?? json['entries_today']),
      exitsToday: asInt(json['exitsToday'] ?? json['exits_today']),
      pendingPayments:
          asInt(json['pendingPayments'] ?? json['pending_payments']),
      collectedTodayRupees: asDouble(
        json['collectedTodayRupees'] ?? json['collected_today_rupees'],
      ),
      hourlyRateRupees: () {
        final rate = asDouble(
          json['hourlyRateRupees'] ?? json['hourly_rate_rupees'],
        );
        return rate <= 0 ? 50.0 : rate;
      }(),
    );
  }

  @override
  List<Object?> get props => [
        staffName,
        parkedNow,
        availableSlots,
        entriesToday,
        exitsToday,
      ];
}
