import 'package:multiparking_tower/core/errors/exceptions.dart';
import 'package:multiparking_tower/models/vehicle_model.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/vehicle_repository.dart';

class DemoVehicleRepository implements VehicleRepository {
  DemoVehicleRepository({DemoDataStore? store})
      : _store = store ?? DemoDataStore.instance;

  final DemoDataStore _store;

  String get _userId =>
      _store.currentUser?.id ?? (throw const ServerException(message: 'Not authenticated'));

  @override
  Future<List<VehicleModel>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List<VehicleModel>.unmodifiable(
      _store.vehicles.where((v) => v.userId == _userId),
    );
  }

  @override
  Future<VehicleModel> add({
    required String numberPlate,
    String? make,
    String? model,
    String? color,
    bool isDefault = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final plate = numberPlate.toUpperCase().replaceAll(' ', '');
    if (_store.vehicles.any((v) => v.numberPlate == plate)) {
      throw const ServerException(message: 'Vehicle with this number plate already exists');
    }

    final makeDefault = isDefault || _store.vehicles.isEmpty;
    if (makeDefault) {
      for (var i = 0; i < _store.vehicles.length; i++) {
        _store.vehicles[i] = _store.vehicles[i].copyWith(isDefault: false);
      }
    }

    final vehicle = VehicleModel(
      id: _store.newId('veh'),
      userId: _userId,
      numberPlate: plate,
      make: make,
      model: model,
      color: color,
      isDefault: makeDefault,
      createdAt: DateTime.now(),
    );
    _store.vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<VehicleModel> update(VehicleModel vehicle) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final index = _store.vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index < 0) {
      throw const ServerException(message: 'Vehicle not found');
    }
    final updated = vehicle.copyWith(
      numberPlate: vehicle.numberPlate.toUpperCase(),
      userId: _userId,
    );
    _store.vehicles[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String vehicleId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.vehicles.indexWhere((v) => v.id == vehicleId);
    if (index < 0) {
      throw const ServerException(message: 'Vehicle not found');
    }
    final wasDefault = _store.vehicles[index].isDefault;
    _store.vehicles.removeAt(index);
    if (wasDefault && _store.vehicles.isNotEmpty) {
      _store.vehicles[0] = _store.vehicles[0].copyWith(isDefault: true);
    }
  }

  @override
  Future<VehicleModel> setDefault(String vehicleId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.vehicles.indexWhere((v) => v.id == vehicleId);
    if (index < 0) {
      throw const ServerException(message: 'Vehicle not found');
    }
    for (var i = 0; i < _store.vehicles.length; i++) {
      _store.vehicles[i] = _store.vehicles[i].copyWith(isDefault: i == index);
    }
    return _store.vehicles[index];
  }
}
