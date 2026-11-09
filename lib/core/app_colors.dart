import 'package:flutter/material.dart';

/// The NABRA app palette (taken 1:1 from the blueprint's device palette).
/// Every color used in the app must come from here.
abstract final class AppColors {
  static const Color bg = Color(0xFF0D171C);
  static const Color surface = Color(0xFF15242B);
  static const Color raise = Color(0xFF1C2E36);
  static const Color fg = Color(0xFFEAF1F3);
  static const Color muted = Color(0xFF8CA2AB);
  static const Color line = Color(0xFF263A42);

  static const Color cyan = Color(0xFF24D3E6);
  static const Color cyanDim = Color(0xFF0E6A78);
  static const Color onAccent = Color(0xFF04171B);

  static const Color ok = Color(0xFF36D39A);
  static const Color warn = Color(0xFFFFC24B);
  static const Color alert = Color(0xFFFF5C3D);
  static const Color onAlert = Color(0xFFFFFFFF);

  static const Color mapBase = Color(0xFF0A1A20);
  static const Color mapGrid = Color(0xFF102830);
  static const Color transparent = Color(0x00000000);

  /// Soft translucent background used behind chips and badges.
  static Color tint(Color c, [double opacity = 0.14]) => c.withOpacity(opacity);
}
