import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/models/staff_models.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/staff_repository.dart';

class DemoStaffRepository implements StaffRepository {
  DemoStaffRepository({DemoDataStore? store})
      : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;
  final List<StaffSessionModel> _sessions = [];

  @override
  Future<StaffOverviewModel> getOverview() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final parked = _sessions.where((s) => s.isParked).length;
    final walkIns = _sessions.where((s) => s.isParked && s.isWalkIn).length;
    return StaffOverviewModel(
      staffName: _store.currentUser?.displayName ?? 'Gate Staff',
      role: _store.currentUser?.role ?? 'staff',
      totalSlots: 1100,
      occupiedSlots: parked,
      availableSlots: 1100 - parked,
      parkedNow: parked,
      walkInsParked: walkIns,
      entriesToday: _sessions.length,
      exitsToday: _sessions.where((s) => !s.isParked).length,
      pendingPayments:
          _sessions.where((s) => s.needsPayment).length,
      collectedTodayRupees: 0,
      hourlyRateRupees: 50,
    );
  }

  @override
  Future<GateScanResult> scanPass(String token, {String action = 'auto'}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final cleaned = token.trim();
    final qr = _store.currentQr;
    if (qr == null || qr.token.trim() != cleaned) {
      return const GateScanResult(
        valid: false,
        message:
            'QR is unknown or was refreshed. Ask the member to show the latest code.',
      );
    }
    if (!qr.isPermanent && qr.isExpired) {
      return const GateScanResult(
        valid: false,
        message: 'QR has expired. Ask the member to refresh.',
      );
    }
    final existing = _sessions
        .where(
          (s) =>
              s.isParked &&
              s.vehicleNumber.toUpperCase() == qr.vehicleNumber.toUpperCase(),
        )
        .toList();
    if (existing.isEmpty) {
      final now = DateTime.now();
      final bay = _bayFromAllocatedPass(qr.slotLabel);
      final session = StaffSessionModel(
        id: _store.newId('hist'),
        vehicleNumber: qr.vehicleNumber,
        userName: qr.userName,
        slotLabel: bay.label,
        tower: bay.tower,
        floor: bay.floor,
        zone: bay.zone,
        slotNumber: bay.slotNumber,
        entryAt: now,
        status: 'parked',
        billingType: qr.subscriptionType.apiValue,
        isWalkIn: false,
      );
      _sessions.insert(0, session);
      return GateScanResult(
        valid: true,
        message: 'ENTRY · Allotted slot ${session.slotLabel}',
        action: 'entry',
        vehicleNumber: session.vehicleNumber,
        slotLabel: session.slotLabel,
        entryAt: now,
        billingType: session.billingType,
        historyId: session.id,
        paymentStatus: 'free',
        userName: session.userName,
        subscriptionType: session.billingType,
        tower: session.tower,
        floor: session.floor,
        zone: session.zone,
        slotNumber: session.slotNumber,
      );
    }

    final open = existing.first;
    final now = DateTime.now();
    final duration = now.difference(open.entryAt);
    final hours = duration.inSeconds <= 0 ? 1 : ((duration.inSeconds + 3599) ~/ 3600);
    final amountPaise =
        open.billingType == 'hourly' ? hours * 5000 : 0;
    final closed = StaffSessionModel(
      id: open.id,
      vehicleNumber: open.vehicleNumber,
      userName: open.userName,
      userPhone: open.userPhone,
      slotLabel: open.slotLabel,
      tower: open.tower,
      floor: open.floor,
      zone: open.zone,
      slotNumber: open.slotNumber,
      entryAt: open.entryAt,
      exitAt: now,
      durationSeconds: duration.inSeconds,
      durationLabel: '${duration.inMinutes}m',
      status: 'completed',
      billingType: open.billingType,
      paymentStatus: amountPaise > 0 ? 'pending' : 'free',
      amountInPaise: amountPaise,
      amountRupees: amountPaise / 100,
    );
    _sessions.removeWhere((s) => s.id == open.id);
    _sessions.insert(0, closed);
    return GateScanResult(
      valid: true,
      message: amountPaise > 0
          ? 'EXIT · ${closed.vehicleNumber} · ${closed.durationLabel} · ₹${amountPaise ~/ 100} due'
          : 'EXIT · Covered by your ${closed.billingType} plan',
      action: 'exit',
      vehicleNumber: closed.vehicleNumber,
      slotLabel: closed.slotLabel,
      entryAt: closed.entryAt,
      exitAt: closed.exitAt,
      durationSeconds: closed.durationSeconds,
      durationLabel: closed.durationLabel,
      amountInPaise: closed.amountInPaise,
      amountRupees: closed.amountRupees,
      billingType: closed.billingType,
      historyId: closed.id,
      paymentStatus: closed.paymentStatus,
      userName: closed.userName,
      subscriptionType: closed.billingType,
      tower: closed.tower,
      floor: closed.floor,
      zone: closed.zone,
      slotNumber: closed.slotNumber,
    );
  }

  @override
  Future<List<StaffSessionModel>> listSessions({
    String? search,
    String status = 'parked',
    int? floor,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    var rows = _sessions.where((s) => s.status == status).toList();
    if (floor != null) {
      rows = rows.where((s) => s.floor == floor).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toUpperCase();
      rows = rows
          .where(
            (s) =>
                s.vehicleNumber.toUpperCase().contains(q) ||
                s.slotNumber.toUpperCase().contains(q) ||
                (s.driverName?.toUpperCase().contains(q) ?? false),
          )
          .toList();
    }
    return rows;
  }

  @override
  Future<StaffSessionModel?> lookupByPlate(String plate) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final normalized = plate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    try {
      return _sessions.firstWhere(
        (s) =>
            s.isParked &&
            s.vehicleNumber.toUpperCase().replaceAll(RegExp(r'[\s-]'), '') ==
                normalized,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<StaffSessionModel> registerWalkIn({
    required String numberPlate,
    String? driverName,
    String? contactPhone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final plate = numberPlate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    final existing = await lookupByPlate(plate);
    if (existing != null) {
      throw ServerException(
        message: '$plate is already parked at ${existing.slotNumber}',
      );
    }
    final bayIndex = _sessions.where((s) => s.isParked).length + 1;
    const tower = 'A';
    const floor = 1;
    const zone = 'C';
    final slotNumber = 'C-${bayIndex.toString().padLeft(2, '0')}';
    final session = StaffSessionModel(
      id: _store.newId('hist'),
      vehicleNumber: plate,
      driverName: driverName,
      contactPhone: contactPhone,
      userName: driverName,
      userPhone: contactPhone,
      isWalkIn: true,
      slotLabel: 'Tower $tower · Floor $floor · Zone $zone · Slot $slotNumber',
      tower: tower,
      floor: floor,
      zone: zone,
      slotNumber: slotNumber,
      entryAt: DateTime.now(),
      status: 'parked',
      billingType: 'hourly',
      paymentStatus: 'free',
    );
    _sessions.insert(0, session);
    return session;
  }

  @override
  Future<StaffSessionModel> checkout(String historyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final index = _sessions.indexWhere((s) => s.id == historyId);
    if (index < 0) {
      throw const ServerException(message: 'Parking session not found');
    }
    final open = _sessions[index];
    if (!open.isParked) return open;
    final now = DateTime.now();
    final duration = now.difference(open.entryAt);
    final hours =
        duration.inSeconds <= 0 ? 1 : ((duration.inSeconds + 3599) ~/ 3600);
    final amountPaise = hours * 5000;
    final closed = StaffSessionModel(
      id: open.id,
      vehicleNumber: open.vehicleNumber,
      driverName: open.driverName,
      contactPhone: open.contactPhone,
      userName: open.userName,
      userPhone: open.userPhone,
      isWalkIn: open.isWalkIn,
      slotLabel: open.slotLabel,
      tower: open.tower,
      floor: open.floor,
      zone: open.zone,
      slotNumber: open.slotNumber,
      entryAt: open.entryAt,
      exitAt: now,
      durationSeconds: duration.inSeconds,
      durationLabel: '${duration.inMinutes}m',
      status: 'completed',
      billingType: 'hourly',
      paymentStatus: 'pending',
      amountInPaise: amountPaise,
      amountRupees: amountPaise / 100,
      hourlyRateRupees: 50,
    );
    _sessions[index] = closed;
    return closed;
  }

  @override
  Future<StaffSessionModel> collectPayment(String historyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _sessions.indexWhere((s) => s.id == historyId);
    if (index < 0) {
      throw const ServerException(message: 'Parking session not found');
    }
    final session = _sessions[index];
    final paid = StaffSessionModel(
      id: session.id,
      vehicleNumber: session.vehicleNumber,
      driverName: session.driverName,
      contactPhone: session.contactPhone,
      userName: session.userName,
      userPhone: session.userPhone,
      isWalkIn: session.isWalkIn,
      slotLabel: session.slotLabel,
      tower: session.tower,
      floor: session.floor,
      zone: session.zone,
      slotNumber: session.slotNumber,
      entryAt: session.entryAt,
      exitAt: session.exitAt,
      durationSeconds: session.durationSeconds,
      durationLabel: session.durationLabel,
      status: session.status,
      billingType: session.billingType,
      paymentStatus: 'paid',
      amountInPaise: session.amountInPaise,
      amountRupees: session.amountRupees,
      hourlyRateRupees: session.hourlyRateRupees,
    );
    _sessions[index] = paid;
    return paid;
  }

  /// Prefer the live allocated slot; fall back to parsing the QR label.
  /// [slotLabel] is always rebuilt from tower/floor/zone/slot so filters match the card.
  ({String tower, int floor, String zone, String slotNumber, String label})
      _bayFromAllocatedPass(String qrSlotLabel) {
    final slot = _store.currentSlot;
    final parsed = _parseSlotLabel(qrSlotLabel);
    final tower = slot?.tower ?? parsed.$1;
    final floor = slot?.floor ?? parsed.$2;
    final zone = slot?.zone ?? parsed.$3;
    final slotNumber = slot?.slotNumber ?? parsed.$4;
    return (
      tower: tower,
      floor: floor,
      zone: zone,
      slotNumber: slotNumber,
      label: 'Tower $tower · Floor $floor · Zone $zone · Slot $slotNumber',
    );
  }

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
}
