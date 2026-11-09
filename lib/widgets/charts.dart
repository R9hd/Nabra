import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_dimens.dart';
import '../core/app_text.dart';
import 'basics.dart';

/// Heart-rate trace (blueprint `.spark`).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.color = AppColors.cyan, this.height = AppSizes.sparkHeight});

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(values, color)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce(min);
    var hi = values.reduce(max);
    if (hi - lo < 10) {
      final mid = (hi + lo) / 2;
      lo = mid - 5;
      hi = mid + 5;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - lo) / (hi - lo) * size.height * 0.9 - size.height * 0.05;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = AppSizes.sparkStroke
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}

/// Gradient bar chart (blueprint `.bars`). Values are 0..1.
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, this.labels, this.height = AppSizes.barsHeight});

  final List<double> values;
  final List<String>? labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: withGaps([
              for (final v in values)
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: v.clamp(0.04, 1.0),
                    alignment: Alignment.bottomCenter,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.cyan, AppColors.cyanDim],
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
            ], AppSpacing.xs + 3),
          ),
        ),
        if (labels != null) ...[
          const Gap(AppSpacing.xs),
          Row(
            children: withGaps([
              for (final l in labels!)
                Expanded(child: Text(l, textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 10.5))),
            ], AppSpacing.xs + 3),
          ),
        ],
      ],
    );
  }
}

/// Stylized location card (blueprint `.maprect`). Real map tiles would need a
/// Maps API key; "Open in Maps" hands off to the phone's map app instead.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, this.hasLocation = true});
  final bool hasLocation;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Container(
          height: AppSizes.mapHeight,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: AppRadius.lgAll,
          ),
          child: CustomPaint(painter: _MapPainter(hasLocation), child: const SizedBox.expand()),
        ),
      );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.pin);
  final bool pin;
  static const _cell = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapBase);
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.tint(AppColors.cyan, 0.08));
    final grid = Paint()..color = AppColors.mapGrid;
    for (var x = 0.0; x < size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (!pin) return;
    final c = Offset(size.width / 2, size.height * 0.52);
    canvas.drawCircle(c, 13, Paint()..color = AppColors.tint(AppColors.alert, 0.25));
    canvas.drawCircle(c, 7, Paint()..color = AppColors.alert);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.pin != pin;
}

/// Countdown ring for the cancel window (blueprint `.ring`).
class CountdownRing extends StatelessWidget {
  const CountdownRing({super.key, required this.secondsLeft, required this.progress});
  final int secondsLeft;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: AppSizes.ring,
        height: AppSizes.ring,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: AppSizes.borderThick,
                color: AppColors.alert,
                backgroundColor: AppColors.tint(AppColors.alert, 0.2),
              ),
            ),
            Text('$secondsLeft', style: AppText.ring),
          ],
        ),
      );
}
