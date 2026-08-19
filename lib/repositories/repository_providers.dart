import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multiparking_tower/core/providers/core_providers.dart';
import 'package:multiparking_tower/repositories/api/firebase_auth_repository.dart';
import 'package:multiparking_tower/repositories/api/api_notification_repository.dart';
import 'package:multiparking_tower/repositories/api/api_parking_repository.dart';
import 'package:multiparking_tower/repositories/api/api_payment_repository.dart';
import 'package:multiparking_tower/repositories/api/api_qr_repository.dart';
import 'package:multiparking_tower/repositories/api/api_subscription_repository.dart';
import 'package:multiparking_tower/repositories/api/api_vehicle_repository.dart';
import 'package:multiparking_tower/repositories/auth_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_auth_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_notification_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_parking_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_payment_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_qr_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_subscription_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_vehicle_repository.dart';
import 'package:multiparking_tower/repositories/notification_repository.dart';
import 'package:multiparking_tower/repositories/parking_repository.dart';
import 'package:multiparking_tower/repositories/payment_repository.dart';
import 'package:multiparking_tower/repositories/qr_repository.dart';
import 'package:multiparking_tower/repositories/staff_repository.dart';
import 'package:multiparking_tower/repositories/subscription_repository.dart';
import 'package:multiparking_tower/repositories/vehicle_repository.dart';
import 'package:multiparking_tower/repositories/api/api_staff_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_staff_repository.dart';

export 'package:multiparking_tower/core/providers/core_providers.dart'
    show appConfigProvider, dioClientProvider;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoAuthRepository();
  }
  // Production member OTP: Firebase Phone Auth → POST /auth/firebase.
  // Staff username/password still uses the parking API via this repository.
  return FirebaseAuthRepository(ref.watch(dioClientProvider));
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoVehicleRepository();
  }
  return ApiVehicleRepository(ref.watch(dioClientProvider));
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoSubscriptionRepository();
  }
  return ApiSubscriptionRepository(ref.watch(dioClientProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoPaymentRepository();
  }
  return ApiPaymentRepository(ref.watch(dioClientProvider));
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoParkingRepository();
  }
  return ApiParkingRepository(ref.watch(dioClientProvider));
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoStaffRepository();
  }
  return ApiStaffRepository(ref.watch(dioClientProvider));
});

final qrRepositoryProvider = Provider<QrRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoQrRepository();
  }
  return ApiQrRepository(ref.watch(dioClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isDemo) {
    return DemoNotificationRepository();
  }
  return ApiNotificationRepository(ref.watch(dioClientProvider));
});
