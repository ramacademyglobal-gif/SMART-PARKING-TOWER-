import 'package:flutter_test/flutter_test.dart';
import 'package:multiparking_tower/core/utils/validators.dart';

void main() {
  group('Validators.indianPhone', () {
    test('accepts 10-digit Indian mobiles', () {
      expect(Validators.indianPhone('9876543210'), isNull);
      expect(Validators.indianPhone('+91 9876543210'), isNull);
      expect(Validators.indianPhone('09876543210'), isNull);
    });

    test('rejects invalid phones', () {
      expect(Validators.indianPhone(''), isNotNull);
      expect(Validators.indianPhone('12345'), isNotNull);
      expect(Validators.indianPhone('5123456789'), isNotNull);
    });
  });

  group('Validators.otp', () {
    test('accepts 6-digit OTP', () {
      expect(Validators.otp('123456'), isNull);
    });

    test('rejects bad OTP', () {
      expect(Validators.otp('12'), isNotNull);
      expect(Validators.otp('abcdef'), isNotNull);
    });
  });

  group('Validators.vehicleRegistration', () {
    test('accepts Indian plates and normalizes', () {
      expect(Validators.vehicleRegistration('MH12AB1234'), isNull);
      expect(Validators.vehicleRegistration('mh 12 ab 1234'), isNull);
      expect(
        Validators.normalizeVehicleRegistration('mh-12-ab-1234'),
        'MH12AB1234',
      );
    });

    test('rejects invalid plates', () {
      expect(Validators.vehicleRegistration(''), isNotNull);
      expect(Validators.vehicleRegistration('ABC'), isNotNull);
    });
  });

  group('Validators.normalizePhone', () {
    test('strips country code', () {
      expect(Validators.normalizePhone('+919876543210'), '9876543210');
      expect(Validators.normalizePhone('919876543210'), '9876543210');
    });
  });
}
