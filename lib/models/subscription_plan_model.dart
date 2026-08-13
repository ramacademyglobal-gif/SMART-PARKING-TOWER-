import 'package:equatable/equatable.dart';

enum SubscriptionPlanType {
  monthly,
  annual,
  hourly;

  String get apiValue => name;

  static SubscriptionPlanType fromString(String value) {
    return SubscriptionPlanType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SubscriptionPlanType.hourly,
    );
  }
}

class SubscriptionPlanModel extends Equatable {
  const SubscriptionPlanModel({
    required this.id,
    required this.type,
    required this.name,
    required this.priceInPaise,
    required this.durationDays,
    required this.features,
    required this.isPremium,
  });

  final String id;
  final SubscriptionPlanType type;
  final String name;
  final int priceInPaise;
  final int durationDays;
  final List<String> features;
  final bool isPremium;

  double get priceInRupees => priceInPaise / 100.0;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'];
    return SubscriptionPlanModel(
      id: json['id'] as String,
      type: SubscriptionPlanType.fromString(
        json['type'] as String? ?? 'monthly',
      ),
      name: json['name'] as String? ?? '',
      priceInPaise: json['priceInPaise'] as int? ??
          json['price_in_paise'] as int? ??
          0,
      durationDays: json['durationDays'] as int? ??
          json['duration_days'] as int? ??
          30,
      features: featuresRaw is List
          ? featuresRaw.map((e) => e.toString()).toList()
          : const <String>[],
      isPremium: json['isPremium'] as bool? ??
          json['is_premium'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.apiValue,
      'name': name,
      'priceInPaise': priceInPaise,
      'durationDays': durationDays,
      'features': features,
      'isPremium': isPremium,
    };
  }

  SubscriptionPlanModel copyWith({
    String? id,
    SubscriptionPlanType? type,
    String? name,
    int? priceInPaise,
    int? durationDays,
    List<String>? features,
    bool? isPremium,
  }) {
    return SubscriptionPlanModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      priceInPaise: priceInPaise ?? this.priceInPaise,
      durationDays: durationDays ?? this.durationDays,
      features: features ?? this.features,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, name, priceInPaise, durationDays, features, isPremium];
}
