import 'dart:math';

import 'package:multiparking_tower/models/auth_session_model.dart';
import 'package:multiparking_tower/models/notification_model.dart';
import 'package:multiparking_tower/models/parking_history_model.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';
import 'package:multiparking_tower/models/payment_model.dart';
import 'package:multiparking_tower/models/qr_code_model.dart';
import 'package:multiparking_tower/models/subscription_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/models/user_model.dart';
import 'package:multiparking_tower/models/vehicle_model.dart';
import 'package:uuid/uuid.dart';

/// Shared in-memory state for all demo repositories.
class DemoDataStore {
  DemoDataStore._() {
    _seed();
  }

  static final DemoDataStore instance = DemoDataStore._();

  static const demoOtp = '123456';
  static const demoPhone = '9876543210';
  static const demoVehiclePlate = 'MH12AB1234';

  final _uuid = const Uuid();
  final _random = Random();

  UserModel? currentUser;
  AuthSession? session;
  String? pendingOtpPhone;

  final List<VehicleModel> vehicles = [];
  SubscriptionModel? subscription;
  ParkingSlotModel? currentSlot;
  QrCodeModel? currentQr;
  final List<ParkingHistoryModel> history = [];
  final List<PaymentModel> payments = [];
  final List<AppNotificationModel> notifications = [];
  final Map<String, SubscriptionPlanType> pendingOrders = {};

  String? fcmToken;

  late final List<SubscriptionPlanModel> plans;

  void _seed() {
    plans = [
      const SubscriptionPlanModel(
        id: 'plan_monthly',
        type: SubscriptionPlanType.monthly,
        name: 'Monthly Flex',
        priceInPaise: 99900,
        durationDays: 30,
        features: [
          'Preferential premium bay (Zone A, floors 1–3)',
          'QR entry & exit',
          'SMS alerts',
          'Parking history',
        ],
        isPremium: false,
      ),
      const SubscriptionPlanModel(
        id: 'plan_annual',
        type: SubscriptionPlanType.annual,
        name: 'Annual Premium',
        priceInPaise: 999900,
        durationDays: 365,
        features: [
          'Preferential premium bay (Zone A, floors 1–3)',
          'Priority tower access',
          'QR entry & exit',
          'Push & SMS alerts',
          'Dedicated support',
        ],
        isPremium: true,
      ),
    ];

    final now = DateTime.now();
    currentUser = UserModel(
      id: 'user_demo_001',
      phone: demoPhone,
      displayName: 'Rohit Sharma',
      photoUrl: null,
      memberSince: now.subtract(const Duration(days: 120)),
      role: 'user',
    );

    vehicles.add(
      VehicleModel(
        id: 'veh_demo_001',
        userId: currentUser!.id,
        numberPlate: demoVehiclePlate,
        make: 'Hyundai',
        model: 'Creta',
        color: 'Pearl White',
        isDefault: true,
        createdAt: now.subtract(const Duration(days: 100)),
      ),
    );

    subscription = SubscriptionModel(
      id: 'sub_demo_001',
      userId: currentUser!.id,
      planType: SubscriptionPlanType.annual,
      status: SubscriptionStatus.active,
      startDate: now.subtract(const Duration(days: 45)),
      expiryDate: now.add(const Duration(days: 320)),
      razorpayPaymentId: 'pay_demo_annual_001',
    );

    currentSlot = const ParkingSlotModel(
      id: 'slot_a03a15',
      tower: 'A',
      floor: 3,
      zone: 'A',
      slotNumber: 'A-15',
      isPremium: true,
      isOccupied: false,
    );

    currentQr = QrCodeModel(
      token: _opaqueToken(),
      userName: currentUser!.displayName,
      vehicleNumber: demoVehiclePlate,
      slotLabel: currentSlot!.displayLabel,
      subscriptionType: SubscriptionPlanType.annual,
      expiresAt: now.add(const Duration(days: 365)),
      isPermanent: true,
    );

    history.addAll([
      ParkingHistoryModel(
        id: 'hist_001',
        vehicleNumber: demoVehiclePlate,
        entryAt: now.subtract(const Duration(days: 2, hours: 3)),
        exitAt: now.subtract(const Duration(days: 2, hours: 1)),
        duration: const Duration(hours: 2),
        tower: 'A',
        floor: 3,
        zone: 'A',
        slotNumber: 'A-15',
        subscriptionType: SubscriptionPlanType.annual,
        status: ParkingHistoryStatus.completed,
      ),
      ParkingHistoryModel(
        id: 'hist_002',
        vehicleNumber: demoVehiclePlate,
        entryAt: now.subtract(const Duration(days: 5, hours: 6)),
        exitAt: now.subtract(const Duration(days: 5, hours: 2)),
        duration: const Duration(hours: 4),
        tower: 'A',
        floor: 2,
        zone: 'A',
        slotNumber: 'A-08',
        subscriptionType: SubscriptionPlanType.annual,
        status: ParkingHistoryStatus.completed,
      ),
      ParkingHistoryModel(
        id: 'hist_003',
        vehicleNumber: 'MH14CD5678',
        entryAt: now.subtract(const Duration(days: 12)),
        exitAt: now.subtract(const Duration(days: 12)).add(const Duration(hours: 3)),
        duration: const Duration(hours: 3),
        tower: 'A',
        floor: 1,
        zone: 'C',
        slotNumber: 'C-12',
        subscriptionType: SubscriptionPlanType.monthly,
        status: ParkingHistoryStatus.completed,
      ),
    ]);

    payments.add(
      PaymentModel(
        id: 'pay_rec_001',
        amountInPaise: 999900,
        currency: 'INR',
        planType: SubscriptionPlanType.annual,
        status: PaymentStatus.success,
        createdAt: now.subtract(const Duration(days: 45)),
        razorpayOrderId: 'order_demo_annual_001',
        razorpayPaymentId: 'pay_demo_annual_001',
      ),
    );

    notifications.addAll([
      AppNotificationModel(
        id: 'notif_001',
        title: 'Welcome to MultiParking Tower',
        body: 'Your preferential premium bay A · 3 · A · A-15 is ready.',
        type: 'subscription',
        createdAt: now.subtract(const Duration(days: 45)),
        isRead: true,
        data: {'slotId': 'slot_a03a15'},
      ),
      AppNotificationModel(
        id: 'notif_002',
        title: 'Vehicle parked',
        body: 'MH12AB1234 entered Tower A, Floor 3.',
        type: 'parking',
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
        isRead: true,
        data: const {},
      ),
      AppNotificationModel(
        id: 'notif_003',
        title: 'Subscription reminder',
        body: 'Your annual plan renews in 320 days.',
        type: 'billing',
        createdAt: now.subtract(const Duration(hours: 6)),
        isRead: false,
        data: const {},
      ),
    ]);

    session = AuthSession(
      accessToken: 'demo_access_${currentUser!.id}',
      refreshToken: 'demo_refresh_${currentUser!.id}',
      user: currentUser!,
      isNewUser: false,
    );
  }

  String newId(String prefix) => '${prefix}_${_uuid.v4().split('-').first}';

  String _opaqueToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String opaqueToken() => _opaqueToken();

  VehicleModel? get defaultVehicle {
    if (vehicles.isEmpty) return null;
    return vehicles.firstWhere(
      (v) => v.isDefault,
      orElse: () => vehicles.first,
    );
  }

  SubscriptionPlanModel planFor(SubscriptionPlanType type) {
    return plans.firstWhere((p) => p.type == type);
  }

  ParkingSlotModel allocateForPlan(SubscriptionPlanType planType) {
    final isSubscriber = planType == SubscriptionPlanType.annual ||
        planType == SubscriptionPlanType.monthly;
    if (isSubscriber) {
      // Preferential premium Zone A on floors 1–3 (matches backend allocation).
      final floor = 1 + _random.nextInt(3);
      final num = 1 + _random.nextInt(20);
      currentSlot = ParkingSlotModel(
        id: 'slot_a${floor.toString().padLeft(2, '0')}a${num.toString().padLeft(2, '0')}',
        tower: 'A',
        floor: floor,
        zone: 'A',
        slotNumber: 'A-${num.toString().padLeft(2, '0')}',
        isPremium: true,
        isOccupied: false,
      );
    } else {
      // Hourly: never floors 1–2 (reserved for subscribers).
      final floor = 3 + _random.nextInt(9);
      final zones = ['B', 'C', 'D', 'E'];
      final zone = zones[_random.nextInt(zones.length)];
      final num = 1 + _random.nextInt(20);
      currentSlot = ParkingSlotModel(
        id:
            'slot_a${floor.toString().padLeft(2, '0')}${zone.toLowerCase()}${num.toString().padLeft(2, '0')}',
        tower: 'A',
        floor: floor,
        zone: zone,
        slotNumber: '$zone-${num.toString().padLeft(2, '0')}',
        isPremium: false,
        isOccupied: false,
      );
    }
    return currentSlot!;
  }

  QrCodeModel rebuildQr({required bool isPermanent, required Duration validity}) {
    final user = currentUser;
    final vehicle = defaultVehicle;
    final slot = currentSlot;
    final plan = subscription?.planType ?? SubscriptionPlanType.monthly;
    currentQr = QrCodeModel(
      token: _opaqueToken(),
      userName: user?.displayName ?? 'Guest',
      vehicleNumber: vehicle?.numberPlate ?? demoVehiclePlate,
      slotLabel: slot?.displayLabel ?? 'Unassigned',
      subscriptionType: plan,
      expiresAt: DateTime.now().add(validity),
      isPermanent: isPermanent,
    );
    return currentQr!;
  }

  void resetSession() {
    session = null;
    pendingOtpPhone = null;
  }

  /// Clears subscription/slot/QR/vehicle state when a brand-new demo account
  /// is created so onboarding starts from scratch.
  void prepareFreshUserWorkspace() {
    vehicles.clear();
    subscription = null;
    currentSlot = null;
    currentQr = null;
    history.clear();
    payments.clear();
    notifications.clear();
    pendingOrders.clear();
  }
}
