import 'package:flutter_test/flutter_test.dart';
import 'package:multiparking_tower/models/parking_slot_model.dart';
import 'package:multiparking_tower/models/subscription_plan_model.dart';
import 'package:multiparking_tower/repositories/demo/demo_auth_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_data_store.dart';
import 'package:multiparking_tower/repositories/demo/demo_parking_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_payment_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_staff_repository.dart';
import 'package:multiparking_tower/repositories/demo/demo_vehicle_repository.dart';

void main() {
  late DemoDataStore store;

  setUp(() {
    store = DemoDataStore.instance;
    // Reset mutable session bits between tests without rebuilding singleton seed.
    store.session = null;
    store.pendingOtpPhone = null;
  });

  group('DemoAuthRepository', () {
    test('accepts demo OTP 123456 and returns session', () async {
      final repo = DemoAuthRepository(store: store);
      await repo.sendOtp('9876543210');
      final session = await repo.verifyOtp('9876543210', '123456');
      expect(session.accessToken, isNotEmpty);
      expect(session.user.phone, '9876543210');
    });

    test('rejects wrong OTP', () async {
      final repo = DemoAuthRepository(store: store);
      await repo.sendOtp('9876543210');
      expect(
        () => repo.verifyOtp('9876543210', '000000'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DemoPaymentRepository', () {
    test('verifyPayment creates active subscription', () async {
      final repo = DemoPaymentRepository(store: store);
      final order = await repo.createOrder(SubscriptionPlanType.monthly);
      expect(order['orderId'], isNotEmpty);
      final subscription = await repo.verifyPayment(
        orderId: order['orderId'] as String,
        paymentId: 'pay_demo',
        signature: 'sig_demo',
      );
      expect(subscription.isActive, isTrue);
      expect(subscription.planType, SubscriptionPlanType.monthly);
    });
  });

  group('DemoVehicleRepository', () {
    test('adds and lists vehicles with uppercase plate', () async {
      final repo = DemoVehicleRepository(store: store);
      final before = await repo.list();
      final added = await repo.add(
        numberPlate: 'ka01cd5678',
        make: 'Tata',
        model: 'Nexon',
        color: 'Blue',
      );
      expect(added.numberPlate, 'KA01CD5678');
      final after = await repo.list();
      expect(after.length, before.length + 1);
    });
  });

  group('DemoParkingRepository', () {
    test('allocateSlot returns a slot label', () async {
      final repo = DemoParkingRepository(store: store);
      final slot = await repo.allocateSlot();
      expect(slot, isA<ParkingSlotModel>());
      expect(slot.displayLabel, contains('Tower'));
      expect(slot.displayLabel, contains('Floor'));
    });
  });

  group('DemoStaffRepository floor filter', () {
    test('QR entry on floor 2 appears under F2 not F1', () async {
      store.currentSlot = const ParkingSlotModel(
        id: 'slot_a02a17',
        tower: 'A',
        floor: 2,
        zone: 'A',
        slotNumber: 'A-17',
        isPremium: true,
        isOccupied: false,
      );
      store.rebuildQr(
        isPermanent: true,
        validity: const Duration(days: 365),
      );
      final qr = store.currentQr!;
      expect(qr.slotLabel, contains('Floor 2'));

      final staff = DemoStaffRepository(store: store);
      final scan = await staff.scanPass(qr.token);
      expect(scan.valid, isTrue);
      expect(scan.floor, 2);
      expect(scan.slotLabel, contains('Floor 2'));
      expect(scan.slotNumber, 'A-17');

      final floor2 = await staff.listSessions(status: 'parked', floor: 2);
      expect(floor2, hasLength(1));
      expect(floor2.first.floor, 2);
      expect(floor2.first.slotLabel, contains('Floor 2'));
      expect(floor2.first.slotLabel, contains('A-17'));

      final floor1 = await staff.listSessions(status: 'parked', floor: 1);
      expect(floor1, isEmpty);
    });
  });
}
