import 'package:multiparking_tower/models/gate_scan_result.dart';
import 'package:multiparking_tower/models/staff_models.dart';

abstract class StaffRepository {
  Future<StaffOverviewModel> getOverview();

  Future<GateScanResult> scanPass(String token, {String action = 'auto'});

  Future<List<StaffSessionModel>> listSessions({
    String? search,
    String status = 'parked',
    int? floor,
  });

  Future<StaffSessionModel?> lookupByPlate(String plate);

  Future<StaffSessionModel> registerWalkIn({
    required String numberPlate,
    String? driverName,
    String? contactPhone,
  });

  Future<StaffSessionModel> checkout(String historyId);

  Future<StaffSessionModel> collectPayment(String historyId);
}
