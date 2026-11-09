import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_dimens.dart';
import '../core/app_text.dart';
import '../core/responsive.dart';
import 'basics.dart';

/// Scrollable page body: centered, width-capped on tablets / web,
/// responsive side gutter, consistent vertical rhythm.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.children, this.gap = AppSpacing.md, this.maxWidth});

  final List<Widget> children;
  final double gap;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final g = context.rs.gutter;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(g, AppSpacing.xs, g, AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? AppSizes.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: withGaps(children, gap),
          ),
        ),
      ),
    );
  }
}

/// Tiles side by side that wrap into a grid as space shrinks.
/// Tiles in the same row get equal height.
class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.children,
    this.minTileWidth = AppSizes.minTileWidth,
    this.maxColumns = 4,
    this.gap = AppSpacing.md - 2,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final fit = ((c.maxWidth + gap) / (minTileWidth + gap)).floor();
      final cols = fit.clamp(1, maxColumns.clamp(1, children.length));
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        final slice = children.sublist(i, (i + cols).clamp(0, children.length));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: withGaps([
              for (final w in slice) Expanded(child: w),
              for (var k = slice.length; k < cols; k++) const Expanded(child: SizedBox.shrink()),
            ], gap),
          ),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: withGaps(rows, gap));
    });
  }
}

/// Blueprint `.ab` app bar: title + round initial.
class NabraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NabraAppBar({super.key, required this.title, this.initial, this.actions = const []});

  final String title;
  final String? initial;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: AppText.title),
      titleSpacing: Navigator.of(context).canPop() ? 0 : context.rs.gutter,
      actions: [
        ...actions,
        if (initial != null) Avatar(initial!),
        Gap(context.rs.gutter),
      ],
    );
  }
}

/// Action buttons pinned to the bottom of the screen so the important ones
/// (respond, call 997, seizure ended) are always reachable without scrolling.
class StickyActions extends StatelessWidget {
  const StickyActions({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final g = context.rs.gutter;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(g, AppSpacing.md, g, AppSpacing.md),
          // heightFactor 1: shrink to the buttons' height. A plain Center expands to
          // the full screen height and hides the page behind the bar.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: withGaps(children, AppSpacing.sm),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
