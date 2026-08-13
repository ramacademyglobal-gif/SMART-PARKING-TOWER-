import 'package:multiparking_tower/models/vehicle_model.dart';

abstract class VehicleRepository {
  Future<List<VehicleModel>> list();

  Future<VehicleModel> add({
    required String numberPlate,
    String? make,
    String? model,
    String? color,
    bool isDefault = false,
  });

  Future<VehicleModel> update(VehicleModel vehicle);

  Future<void> delete(String vehicleId);

  Future<VehicleModel> setDefault(String vehicleId);
}
