import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';

abstract class ParkingRepository {
  Future<ParkingSlotModel?> getCurrentSlot();

  Future<ParkingSlotModel> allocateSlot();

  Future<List<ParkingHistoryModel>> getHistory({
    String? search,
    String? filter,
  });

  /// Demo-only helpers for simulating entry/exit cycles.
  Future<ParkingHistoryModel> simulateEntry();

  Future<ParkingHistoryModel> simulateExit();

  /// Gate scan: first successful scan = entry, second = exit (+ amount).
  Future<GateScanResult> scanPass(String token, {String action = 'auto'});

  /// Creates a Razorpay order for the hourly charge owed on [historyId].
  /// Returns a map with `orderId`, `amount`, `currency` and `key`.
  Future<Map<String, dynamic>> createParkingOrder(String historyId);

  /// Verifies a parking payment and returns the settled (paid) session.
  Future<ParkingHistoryModel> verifyParkingPayment({
    required String historyId,
    required String orderId,
    required String paymentId,
    required String signature,
  });
}
