import 'package:flutter/widgets.dart';

import 'app_dimens.dart';

/// Breakpoint helper. Read with `context.rs`.
class Responsive {
  const Responsive._(this.width);

  factory Responsive.of(BuildContext context) => Responsive._(MediaQuery.sizeOf(context).width);

  final double width;

  bool get isCompact => width < AppSizes.compactBreakpoint;
  bool get isExpanded => width >= AppSizes.navRailBreakpoint;

  /// Horizontal page padding: 16 on phones, 24 on tablets and up.
  double get gutter => isCompact ? AppSpacing.lg : AppSpacing.xxl;
}

extension ResponsiveContext on BuildContext {
  Responsive get rs => Responsive.of(this);
}
