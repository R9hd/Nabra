import 'package:flutter/widgets.dart';

/// Spacing scale. Use these instead of raw numbers in padding / SizedBox.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double card = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 14;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

abstract final class AppSizes {
  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double icon = 20;
  static const double iconLg = 28;
  static const double iconBox = 34;
  static const double avatar = 30;
  static const double dot = 9;
  static const double border = 1;
  static const double borderThick = 5;

  static const double buttonHeight = 48;
  static const double buttonHeightSm = 40;
  static const double ring = 120;
  static const double sparkHeight = 54;
  static const double sparkStroke = 2;
  static const double barsHeight = 90;
  static const double mapHeight = 140;
  static const double sliderTrack = 6;

  /// Max width of the main content column on tablets / web.
  static const double maxContentWidth = 640;

  /// Narrow column for focused flows (auth, alert takeover).
  static const double narrowContentWidth = 460;
  static const double inlineButtonWidth = 96;
  static const double choiceTileMinWidth = 120;
  static const double actionTileMinWidth = 160;

  /// Width at which the bottom bar becomes a navigation rail.
  static const double navRailBreakpoint = 840;
  static const double compactBreakpoint = 600;

  /// Below this width, side-by-side tiles stack vertically.
  static const double minTileWidth = 140;
}
