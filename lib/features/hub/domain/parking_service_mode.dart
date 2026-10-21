/// Which product the user selected inside the single hub APK.
enum ParkingServiceMode {
  tower,
  openSpace,
}

extension ParkingServiceModeX on ParkingServiceMode {
  String get storageValue => switch (this) {
        ParkingServiceMode.tower => 'tower',
        ParkingServiceMode.openSpace => 'open_space',
      };

  String get title => switch (this) {
        ParkingServiceMode.tower => 'Multi-Level Tower Parking',
        ParkingServiceMode.openSpace => 'Open Space Parking',
      };

  String get subtitle => switch (this) {
        ParkingServiceMode.tower =>
          'Automated multi-level tower · slots, QR, subscriptions',
        ParkingServiceMode.openSpace =>
          'Nearby land lots · map booking · land owner portal',
      };

  static ParkingServiceMode? fromStorage(String? value) {
    switch (value) {
      case 'tower':
        return ParkingServiceMode.tower;
      case 'open_space':
        return ParkingServiceMode.openSpace;
      default:
        return null;
    }
  }
}
