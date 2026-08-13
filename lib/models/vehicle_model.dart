import 'package:equatable/equatable.dart';

class VehicleModel extends Equatable {
  VehicleModel({
    required this.id,
    required this.userId,
    required String numberPlate,
    this.make,
    this.model,
    this.color,
    required this.isDefault,
    required this.createdAt,
  }) : numberPlate = numberPlate.toUpperCase();

  final String id;
  final String userId;
  final String numberPlate;
  final String? make;
  final String? model;
  final String? color;
  final bool isDefault;
  final DateTime createdAt;

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      numberPlate: (json['numberPlate'] as String? ??
              json['number_plate'] as String? ??
              '')
          .toUpperCase(),
      make: json['make'] as String?,
      model: json['model'] as String?,
      color: json['color'] as String?,
      isDefault: json['isDefault'] as bool? ??
          json['is_default'] as bool? ??
          false,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ??
            json['created_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'numberPlate': numberPlate,
      'make': make,
      'model': model,
      'color': color,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  VehicleModel copyWith({
    String? id,
    String? userId,
    String? numberPlate,
    String? make,
    String? model,
    String? color,
    bool? isDefault,
    DateTime? createdAt,
    bool clearMake = false,
    bool clearModel = false,
    bool clearColor = false,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      numberPlate: numberPlate ?? this.numberPlate,
      make: clearMake ? null : (make ?? this.make),
      model: clearModel ? null : (model ?? this.model),
      color: clearColor ? null : (color ?? this.color),
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, numberPlate, make, model, color, isDefault, createdAt];
}
