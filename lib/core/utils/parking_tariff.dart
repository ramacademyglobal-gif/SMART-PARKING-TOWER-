import 'dart:math';

/// Shared hourly parking tariff helpers (₹50 / hour, rounded up).
class ParkingTariff {
  const ParkingTariff._();

  static const int hourlyRatePaise = 5000; // ₹50
  static const double hourlyRateRupees = 50;

  static int billableHours(Duration duration) {
    if (duration.inSeconds <= 0) return 1;
    return max(1, (duration.inSeconds / 3600).ceil());
  }

  static int chargePaise(Duration duration) =>
      billableHours(duration) * hourlyRatePaise;

  static double chargeRupees(Duration duration) => chargePaise(duration) / 100.0;
}
