import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';
import 'package:multiparking_tower/core/utils/parking_tariff.dart';
import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/models/notification_model.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';
import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/parking_repository.dart';

class DemoParkingRepository implements ParkingRepository {
  DemoParkingRepository({DemoDataStore? store})
      : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;

  @override
  Future<ParkingSlotModel?> getCurrentSlot() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _store.currentSlot;
  }

  @override
  Future<ParkingSlotModel> allocateSlot() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final sub = _store.subscription;
    final planType = (sub != null && sub.isActive)
        ? sub.planType
        : SubscriptionPlanType.hourly;
    final slot = _store.allocateForPlan(
      planType == SubscriptionPlanType.hourly
          ? SubscriptionPlanType.monthly
          : planType,
    );
    final isPermanent = planType == SubscriptionPlanType.annual ||
        planType == SubscriptionPlanType.monthly;
    _store.rebuildQr(
      isPermanent: isPermanent,
      validity: isPermanent
          ? Duration(days: _store.planFor(planType).durationDays)
          : const Duration(hours: 2),
    );
    return slot;
  }

  @override
  Future<List<ParkingHistoryModel>> getHistory({
    String? search,
    String? filter,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    var results = List<ParkingHistoryModel>.from(_store.history);

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toUpperCase();
      results = results
          .where(
            (h) =>
                h.vehicleNumber.contains(q) ||
                h.slotNumber.toUpperCase().contains(q) ||
                h.tower.toUpperCase().contains(q) ||
                h.zone.toUpperCase().contains(q),
          )
          .toList();
    }

    if (filter != null && filter.trim().isNotEmpty) {
      final f = filter.trim().toLowerCase();
      if (f == 'parked' || f == 'completed') {
        results = results
            .where((h) => h.status.apiValue == f)
            .toList();
      } else if (f == 'monthly' || f == 'annual' || f == 'hourly') {
        results = results
            .where((h) => h.subscriptionType.apiValue == f)
            .toList();
      } else if (f == 'pending') {
        results = results.where((h) => h.needsPayment).toList();
      }
    }

    results.sort((a, b) => b.entryAt.compareTo(a.entryAt));
    return results;
  }

  @override
  Future<ParkingHistoryModel> simulateEntry() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    var slot = _store.currentSlot ??=
        _store.allocateForPlan(SubscriptionPlanType.monthly);
    if (slot.isOccupied) {
      throw const ServerException(message: 'Vehicle is already parked');
    }

    final vehicle = _store.defaultVehicle;
    final hasSub = _store.subscription?.isActive ?? false;
    final planType = hasSub
        ? (_store.subscription!.planType)
        : SubscriptionPlanType.hourly;
    final now = DateTime.now();

    _store.currentSlot = slot.copyWith(isOccupied: true);

    final entry = ParkingHistoryModel(
      id: _store.newId('hist'),
      vehicleNumber: vehicle?.numberPlate ?? DemoDataStore.demoVehiclePlate,
      entryAt: now,
      tower: slot.tower,
      floor: slot.floor,
      zone: slot.zone,
      slotNumber: slot.slotNumber,
      subscriptionType: planType,
      billingType: planType.apiValue,
      status: ParkingHistoryStatus.parked,
    );
    _store.history.insert(0, entry);

    _store.notifications.insert(
      0,
      AppNotificationModel(
        id: _store.newId('notif'),
        title: 'Vehicle entered',
        body: '${entry.vehicleNumber} parked at ${slot.displayLabel}',
        type: 'parking',
        createdAt: now,
        isRead: false,
        data: {'historyId': entry.id},
      ),
    );

    return entry;
  }

  @override
  Future<ParkingHistoryModel> simulateExit() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final slot = _store.currentSlot;
    if (slot == null || !slot.isOccupied) {
      throw const ServerException(message: 'No active parking session to exit');
    }

    final index = _store.history.indexWhere(
      (h) => h.status == ParkingHistoryStatus.parked,
    );
    if (index < 0) {
      throw const ServerException(message: 'No active parking session found');
    }

    final now = DateTime.now();
    final current = _store.history[index];
    final duration = now.difference(current.entryAt);
    final hasSub = _store.subscription?.isActive ?? false;
    final amount = hasSub ? 0 : ParkingTariff.chargePaise(duration);
    final billing = hasSub
        ? (_store.subscription!.planType.apiValue)
        : 'hourly';

    final completed = current.copyWith(
      exitAt: now,
      duration: duration,
      status: ParkingHistoryStatus.completed,
      amountInPaise: amount,
      billingType: billing,
      paymentStatus: amount > 0 ? 'pending' : 'free',
      subscriptionType: hasSub
          ? _store.subscription!.planType
          : SubscriptionPlanType.hourly,
    );
    _store.history[index] = completed;
    _store.currentSlot = slot.copyWith(isOccupied: false);

    final chargeText = amount > 0
        ? ' · ₹${(amount / 100).toStringAsFixed(0)}'
        : ' · covered by plan';
    _store.notifications.insert(
      0,
      AppNotificationModel(
        id: _store.newId('notif'),
        title: 'Vehicle exited',
        body:
            '${completed.vehicleNumber} · ${Formatters.duration(duration)}$chargeText',
        type: 'parking',
        createdAt: now,
        isRead: false,
        data: {
          'historyId': completed.id,
          'amountInPaise': amount,
        },
      ),
    );

    return completed;
  }

  @override
  Future<GateScanResult> scanPass(String token, {String action = 'auto'}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final qr = _store.currentQr;
    if (qr == null || qr.token != token.trim()) {
      return const GateScanResult(
        valid: false,
        message: 'Unrecognized or expired parking QR',
      );
    }

    final parked = _store.history.any(
      (h) => h.status == ParkingHistoryStatus.parked,
    );
    var resolved = action.trim().toLowerCase();
    if (resolved.isEmpty || resolved == 'auto') {
      resolved = parked ? 'exit' : 'entry';
    }

    if (resolved == 'entry') {
      try {
        final session = await simulateEntry();
        return GateScanResult(
          valid: true,
          message: 'Entry authorized. Gate opening.',
          action: 'entry',
          vehicleNumber: session.vehicleNumber,
          slotLabel: session.slotLabel,
          entryAt: session.entryAt,
          billingType: session.billingType,
          historyId: session.id,
          paymentStatus: 'free',
        );
      } on ServerException catch (e) {
        return GateScanResult(
          valid: false,
          message: e.message,
          action: 'entry',
          vehicleNumber: qr.vehicleNumber,
          slotLabel: qr.slotLabel,
        );
      }
    }

    if (resolved == 'exit') {
      try {
        final session = await simulateExit();
        final amount = session.amountInPaise ?? 0;
        final duration = session.duration ?? Duration.zero;
        return GateScanResult(
          valid: true,
          message: amount > 0
              ? 'Exit authorized. ${session.vehicleNumber} · '
                  '${Formatters.duration(duration)} · '
                  '₹${(amount / 100).toStringAsFixed(0)}'
              : 'Exit authorized. Covered by your subscription.',
          action: 'exit',
          vehicleNumber: session.vehicleNumber,
          slotLabel: session.slotLabel,
          entryAt: session.entryAt,
          exitAt: session.exitAt,
          durationSeconds: duration.inSeconds,
          durationLabel: Formatters.duration(duration),
          amountInPaise: amount,
          amountRupees: amount / 100.0,
          billingType: session.billingType,
          hourlyRateRupees: 50,
          historyId: session.id,
          paymentStatus: session.paymentStatus,
        );
      } on ServerException catch (e) {
        return GateScanResult(
          valid: false,
          message: e.message,
          action: 'exit',
          vehicleNumber: qr.vehicleNumber,
          slotLabel: qr.slotLabel,
        );
      }
    }

    return const GateScanResult(
      valid: false,
      message: 'action must be entry, exit, or auto',
    );
  }

  @override
  Future<Map<String, dynamic>> createParkingOrder(String historyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final index = _store.history.indexWhere((h) => h.id == historyId);
    if (index < 0) {
      throw const ServerException(message: 'Parking session not found');
    }
    final session = _store.history[index];
    final amount = session.amountInPaise ?? 0;
    if (session.isPaid) {
      throw const ServerException(message: 'This session is already paid');
    }
    if (amount <= 0) {
      throw const ServerException(message: 'No payment is due for this session');
    }
    final suffix = DateTime.now().millisecondsSinceEpoch;
    return {
      'orderId': 'order_demo_$suffix',
      'amount': amount,
      'currency': 'INR',
      'key': 'rzp_test_demo',
    };
  }

  @override
  Future<ParkingHistoryModel> verifyParkingPayment({
    required String historyId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final index = _store.history.indexWhere((h) => h.id == historyId);
    if (index < 0) {
      throw const ServerException(message: 'Parking session not found');
    }
    final paid = _store.history[index].copyWith(paymentStatus: 'paid');
    _store.history[index] = paid;

    final amount = paid.amountInPaise ?? 0;
    _store.payments.insert(
      0,
      PaymentModel(
        id: _store.newId('pay'),
        amountInPaise: amount,
        currency: 'INR',
        planType: SubscriptionPlanType.hourly,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
      ),
    );
    _store.notifications.insert(
      0,
      AppNotificationModel(
        id: _store.newId('notif'),
        title: 'Parking paid',
        body:
            '${paid.vehicleNumber} · ₹${(amount / 100).toStringAsFixed(0)} paid. Thank you!',
        type: 'payment',
        createdAt: DateTime.now(),
        isRead: false,
        data: {'historyId': paid.id, 'amountInPaise': amount},
      ),
    );
    return paid;
  }
}
