import 'package:flutter_test/flutter_test.dart';
import 'package:multiparking_tower/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    test('formats INR currency', () {
      final value = Formatters.currency(999);
      expect(value, contains('999'));
      expect(value, contains('₹'));
    });

    test('formats duration', () {
      expect(
        Formatters.duration(const Duration(hours: 2, minutes: 15)),
        isNotEmpty,
      );
    });

    test('formats date and time', () {
      final dt = DateTime(2026, 7, 25, 21, 30);
      expect(Formatters.date(dt), contains('2026'));
      expect(Formatters.time(dt), isNotEmpty);
    });
  });
}
