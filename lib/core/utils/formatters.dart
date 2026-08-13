import 'package:intl/intl.dart';

import 'package:multiparking_tower/core/constants/app_constants.dart';

/// Locale-aware formatting helpers for dates, times, durations and currency.
///
/// Defaults to the Indian locale (`en_IN`) and INR currency.
class Formatters {
  const Formatters._();

  static const String _locale = 'en_IN';

  // ---------------------------------------------------------------------------
  // Currency
  // ---------------------------------------------------------------------------

  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: _locale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  static final NumberFormat _inrWholeFormat = NumberFormat.currency(
    locale: _locale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 0,
  );

  /// Formats an amount as INR, e.g. `₹1,499.00`.
  static String currency(num amount, {bool decimals = true}) {
    return (decimals ? _inrFormat : _inrWholeFormat).format(amount);
  }

  /// Formats a compact currency value, e.g. `₹1.5K`, `₹1.2L`.
  static String compactCurrency(num amount) {
    final formatter = NumberFormat.compactCurrency(
      locale: _locale,
      symbol: AppConstants.currencySymbol,
      decimalDigits: 1,
    );
    return formatter.format(amount);
  }

  // ---------------------------------------------------------------------------
  // Dates & times
  // ---------------------------------------------------------------------------

  // Pattern-only formats avoid requiring `initializeDateFormatting`.
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _dateShortFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _dayMonthFormat = DateFormat('dd MMM');
  static final DateFormat _weekdayFormat = DateFormat('EEE, dd MMM');

  /// e.g. `25 Jul 2026`.
  static String date(DateTime dt) => _dateFormat.format(dt.toLocal());

  /// e.g. `25/07/2026`.
  static String dateShort(DateTime dt) => _dateShortFormat.format(dt.toLocal());

  /// e.g. `09:30 PM`.
  static String time(DateTime dt) => _timeFormat.format(dt.toLocal());

  /// e.g. `25 Jul 2026, 09:30 PM`.
  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt.toLocal());

  /// e.g. `25 Jul`.
  static String dayMonth(DateTime dt) => _dayMonthFormat.format(dt.toLocal());

  /// e.g. `Sat, 25 Jul`.
  static String weekday(DateTime dt) => _weekdayFormat.format(dt.toLocal());

  /// Relative "time ago" string, e.g. `just now`, `5 min ago`, `2 h ago`.
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return date(dt);
  }

  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  /// Human-friendly duration, e.g. `2h 15m`, `45m`, `30s`.
  static String duration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  /// Countdown style `mm:ss`, useful for OTP timers.
  static String countdown(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Long-form parking duration between two timestamps.
  static String durationBetween(DateTime start, DateTime end) {
    return duration(end.difference(start));
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  /// Masks a phone number for display, e.g. `+91 ******3210`.
  static String maskedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    final last4 = digits.substring(digits.length - 4);
    return '${AppConstants.defaultCountryCode} ******$last4';
  }

  /// Formats a slot code with a floor prefix, e.g. `F3-A12`.
  static String slotCode(int floor, String slot) => 'F$floor-$slot';
}
