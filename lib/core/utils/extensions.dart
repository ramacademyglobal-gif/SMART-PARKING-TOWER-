import 'package:flutter/material.dart';

import 'package:multiparking_tower/core/constants/app_constants.dart';

/// Convenience accessors for theme, colour scheme, text theme and media query.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);
  double get bottomInset => MediaQuery.viewInsetsOf(this).bottom;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  bool get isKeyboardOpen => MediaQuery.viewInsetsOf(this).bottom > 0;

  bool get isCompact => MediaQuery.sizeOf(this).width < 360;
  bool get isTablet => MediaQuery.sizeOf(this).width >= 600;

  /// Dismisses the on-screen keyboard.
  void unfocus() => FocusScope.of(this).unfocus();

  /// Shows a themed snackbar with [message].
  void showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: AppConstants.snackBarDuration,
          backgroundColor: isError ? colors.error : null,
        ),
      );
  }
}

/// String helpers used across UI and formatting layers.
extension StringX on String {
  /// Capitalises the first letter, leaving the rest untouched.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Title-cases each whitespace-separated word.
  String get titleCase {
    if (isEmpty) return this;
    return split(' ')
        .map((w) => w.isEmpty ? w : w.capitalize)
        .join(' ');
  }

  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => trim().isNotEmpty;

  /// Returns null if blank, otherwise the trimmed string.
  String? get nullIfBlank => isBlank ? null : trim();

  /// Returns the first letters of up to two words as initials, e.g. `Rohit Ram`
  /// -> `RR`.
  String get initials {
    final parts = trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Nullable-string helpers.
extension NullableStringX on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
  bool get isNotNullOrBlank => !isNullOrBlank;
}

/// Spacing helpers for building gaps between widgets.
extension NumSpacingX on num {
  SizedBox get verticalSpace => SizedBox(height: toDouble());
  SizedBox get horizontalSpace => SizedBox(width: toDouble());
}
