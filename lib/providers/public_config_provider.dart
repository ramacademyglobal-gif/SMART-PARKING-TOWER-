import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/constants/api_endpoints.dart';
import 'package:multiparking_tower/repositories/repository_providers.dart';

/// Public bootstrap values from `GET /v1/config` (no secrets).
class PublicApiConfig extends Equatable {
  const PublicApiConfig({
    required this.otpDevMode,
    this.razorpayKeyId = '',
    this.razorpayEnabled = false,
    this.msg91Enabled = false,
    this.towerId = 'A',
    this.towerName = 'MultiParking Tower A',
    this.totalSlots = 1100,
    this.availableSlots = 1100,
    this.occupiedSlots = 0,
    this.premiumSlots = 220,
    this.standardSlots = 880,
    this.hourlyRateRupees = 50,
    this.bookingFeeRupees = 50,
    this.bookingFeePaise = 5000,
  });

  final bool otpDevMode;
  final String razorpayKeyId;
  final bool razorpayEnabled;
  final bool msg91Enabled;
  final String towerId;
  final String towerName;
  final int totalSlots;
  final int availableSlots;
  final int occupiedSlots;
  final int premiumSlots;
  final int standardSlots;
  final double hourlyRateRupees;
  final double bookingFeeRupees;
  final int bookingFeePaise;

  /// Offline / demo fallback: always show the local OTP hint.
  static const PublicApiConfig demo = PublicApiConfig(
    otpDevMode: true,
    razorpayEnabled: false,
    msg91Enabled: false,
    totalSlots: 1100,
    availableSlots: 1100,
    premiumSlots: 220,
    standardSlots: 880,
    bookingFeeRupees: 50,
    bookingFeePaise: 5000,
  );

  factory PublicApiConfig.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    double asDouble(dynamic v, double fallback) {
      if (v is num) return v.toDouble();
      return fallback;
    }

    return PublicApiConfig(
      otpDevMode: json['otpDevMode'] as bool? ??
          json['otp_dev_mode'] as bool? ??
          true,
      razorpayKeyId: (json['razorpayKeyId'] ??
              json['razorpay_key_id'] ??
              '')
          .toString(),
      razorpayEnabled: json['razorpayEnabled'] as bool? ??
          json['razorpay_enabled'] as bool? ??
          false,
      msg91Enabled: json['msg91Enabled'] as bool? ??
          json['msg91_enabled'] as bool? ??
          false,
      towerId: (json['towerId'] ?? json['tower_id'] ?? 'A').toString(),
      towerName: (json['towerName'] ??
              json['tower_name'] ??
              'MultiParking Tower A')
          .toString(),
      totalSlots: asInt(json['totalSlots'] ?? json['total_slots'], 1100),
      availableSlots:
          asInt(json['availableSlots'] ?? json['available_slots'], 1100),
      occupiedSlots:
          asInt(json['occupiedSlots'] ?? json['occupied_slots'], 0),
      premiumSlots:
          asInt(json['premiumSlots'] ?? json['premium_slots'], 220),
      standardSlots:
          asInt(json['standardSlots'] ?? json['standard_slots'], 880),
      hourlyRateRupees: asDouble(
        json['hourlyRateRupees'] ?? json['hourly_rate_rupees'],
        50,
      ),
      bookingFeeRupees: asDouble(
        json['bookingFeeRupees'] ?? json['booking_fee_rupees'],
        50,
      ),
      bookingFeePaise: asInt(
        json['bookingFeePaise'] ?? json['booking_fee_paise'],
        5000,
      ),
    );
  }

  @override
  List<Object?> get props => [
        otpDevMode,
        razorpayKeyId,
        razorpayEnabled,
        msg91Enabled,
        towerId,
        towerName,
        totalSlots,
        availableSlots,
        occupiedSlots,
        premiumSlots,
        standardSlots,
        hourlyRateRupees,
        bookingFeeRupees,
        bookingFeePaise,
      ];
}

/// Fetches public API config. In demo mode returns [PublicApiConfig.demo].
final publicApiConfigProvider = FutureProvider<PublicApiConfig>((ref) async {
  final appConfig = ref.watch(appConfigProvider);
  if (appConfig.isDemo) return PublicApiConfig.demo;

  try {
    final response =
        await ref.watch(dioClientProvider).get(ApiEndpoints.publicConfig);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return PublicApiConfig.fromJson(data);
    }
    if (data is Map) {
      return PublicApiConfig.fromJson(Map<String, dynamic>.from(data));
    }
  } catch (_) {
    // Fall through to a safe default when the API is unreachable.
  }
  return const PublicApiConfig(otpDevMode: true);
});
