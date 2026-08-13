import 'package:flutter/material.dart';

/// Centralised palette for the MultiParking Tower app.
///
/// The brand identity is built around a deep teal/slate base, warm peach
/// accents, and a soft cream background for light mode. Dark mode swaps the
/// cream surfaces for charcoal while keeping the peach accent for continuity.
class AppColors {
  const AppColors._();

  // --- Brand core (teal / slate) ---
  static const Color tealDeep = Color(0xFF2C4A56);
  static const Color slate = Color(0xFF3A505D);
  static const Color tealDark = Color(0xFF1E343D);

  // --- Accent (peach) ---
  static const Color peach = Color(0xFFF2C299);
  static const Color peachDeep = Color(0xFFF1A27B);
  static const Color peachSoft = Color(0xFFF9D9BD);

  // --- Cream backgrounds (light) ---
  static const Color cream = Color(0xFFF5E9D6);
  static const Color creamWarm = Color(0xFFF9E4C8);
  static const Color creamSurface = Color(0xFFFDF6EC);

  // --- Charcoal / dark-mode surfaces ---
  static const Color charcoal = Color(0xFF16232A);
  static const Color charcoalSurface = Color(0xFF1F313A);
  static const Color charcoalElevated = Color(0xFF27404B);

  // --- Neutrals ---
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color textDark = Color(0xFF20343C);
  static const Color textMuted = Color(0xFF6B7C84);
  static const Color textOnDark = Color(0xFFF3ECE1);
  static const Color textMutedDark = Color(0xFFA7B4BB);
  static const Color divider = Color(0x1F2C4A56);
  static const Color dividerDark = Color(0x1FF3ECE1);

  // --- Semantic ---
  static const Color success = Color(0xFF3FAE7C);
  static const Color warning = Color(0xFFE8A33D);
  static const Color error = Color(0xFFD9534F);
  static const Color info = Color(0xFF4A90A4);

  // --- Parking slot states ---
  static const Color slotAvailable = Color(0xFF3FAE7C);
  static const Color slotOccupied = Color(0xFFD9534F);
  static const Color slotReserved = Color(0xFFE8A33D);
  static const Color slotSelected = peachDeep;
  static const Color slotDisabled = Color(0xFF9AA7AD);

  // --- Gradients ---
  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealDeep, slate],
  );

  static const LinearGradient tealDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealDark, charcoal],
  );

  static const LinearGradient peachGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [peach, peachDeep],
  );

  static const LinearGradient creamGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [creamWarm, cream],
  );

  // --- Soft shadows ---
  static const Color shadowLight = Color(0x1A2C4A56);
  static const Color shadowDark = Color(0x40000000);
}
