import 'package:equatable/equatable.dart';

class ParkingSlotModel extends Equatable {
  const ParkingSlotModel({
    required this.id,
    required this.tower,
    required this.floor,
    required this.zone,
    required this.slotNumber,
    required this.isPremium,
    required this.isOccupied,
  });

  final String id;
  final String tower;
  final int floor;
  final String zone;
  final String slotNumber;
  final bool isPremium;
  final bool isOccupied;

  String get displayLabel =>
      'Tower $tower · Floor $floor · Zone $zone · Slot $slotNumber';

  factory ParkingSlotModel.fromJson(Map<String, dynamic> json) {
    return ParkingSlotModel(
      id: json['id'] as String,
      tower: json['tower'] as String? ?? '',
      floor: json['floor'] as int? ?? 0,
      zone: json['zone'] as String? ?? '',
      slotNumber: json['slotNumber'] as String? ??
          json['slot_number'] as String? ??
          '',
      isPremium: json['isPremium'] as bool? ??
          json['is_premium'] as bool? ??
          false,
      isOccupied: json['isOccupied'] as bool? ??
          json['is_occupied'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tower': tower,
      'floor': floor,
      'zone': zone,
      'slotNumber': slotNumber,
      'isPremium': isPremium,
      'isOccupied': isOccupied,
    };
  }

  ParkingSlotModel copyWith({
    String? id,
    String? tower,
    int? floor,
    String? zone,
    String? slotNumber,
    bool? isPremium,
    bool? isOccupied,
  }) {
    return ParkingSlotModel(
      id: id ?? this.id,
      tower: tower ?? this.tower,
      floor: floor ?? this.floor,
      zone: zone ?? this.zone,
      slotNumber: slotNumber ?? this.slotNumber,
      isPremium: isPremium ?? this.isPremium,
      isOccupied: isOccupied ?? this.isOccupied,
    );
  }

  @override
  List<Object?> get props =>
      [id, tower, floor, zone, slotNumber, isPremium, isOccupied];
}
