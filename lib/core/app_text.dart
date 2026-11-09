import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography. IBM Plex Sans for UI, IBM Plex Mono for labels (as in the blueprint).
abstract final class AppText {
  static TextStyle _sans(double size, FontWeight w, {Color color = AppColors.fg, double? height, double? spacing}) =>
      GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: spacing);

  static TextStyle _mono(double size, FontWeight w, {Color color = AppColors.muted, double? spacing}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: w, color: color, letterSpacing: spacing);

  /// Big numbers / hero text (blueprint `.big`).
  static TextStyle get display => _sans(27, FontWeight.w700, height: 1.05, spacing: -0.2);
  static TextStyle get timer => _sans(56, FontWeight.w700, height: 1, spacing: -1);
  static TextStyle get ring => _sans(35, FontWeight.w700, height: 1);
  static TextStyle get headline => _sans(20, FontWeight.w700, height: 1.25);
  static TextStyle get title => _sans(17, FontWeight.w600);
  static TextStyle get bodyStrong => _sans(14.5, FontWeight.w600);
  static TextStyle get body => _sans(14, FontWeight.w400, height: 1.45);
  static TextStyle get small => _sans(13, FontWeight.w400, color: AppColors.muted, height: 1.4);
  static TextStyle get caption => _sans(12, FontWeight.w400, color: AppColors.muted);
  static TextStyle get button => _sans(14.5, FontWeight.w600, color: AppColors.onAccent);
  static TextStyle get chip => _sans(12, FontWeight.w600);

  /// Uppercase mono labels (blueprint `.lbl`).
  static TextStyle get label => _mono(11, FontWeight.w500, spacing: 0.9);
  static TextStyle get fieldLabel => _mono(11, FontWeight.w400);
  static TextStyle get nav => _mono(10, FontWeight.w500);
  static TextStyle get mono => _mono(12, FontWeight.w400, color: AppColors.fg);
  static TextStyle get code => _sans(27, FontWeight.w700, color: AppColors.cyan, spacing: 8);
}
