import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_dimens.dart';
import '../core/app_text.dart';
import '../models/thresholds.dart';
import '../models/vitals.dart';
import 'basics.dart';
import 'layout.dart';

Tone toneFor(VitalState s) => switch (s) {
      VitalState.normal => Tone.ok,
      VitalState.caution => Tone.warn,
      VitalState.danger => Tone.alert,
    };

String labelFor(VitalState s, {String normal = 'Normal'}) => switch (s) {
      VitalState.normal => normal,
      VitalState.caution => 'Watch',
      VitalState.danger => 'Danger',
    };

/// Big number tile (blueprint Heart rate / Battery tiles).
class VitalTile extends StatelessWidget {
  const VitalTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.chip,
    this.sub,
    this.borderColor,
  });

  final String label;
  final String value;
  final String? unit;
  final Widget? chip;
  final String? sub;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return NabraCard(
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SectionLabel(label),
          const Gap(AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: value, style: AppText.display),
              if (unit != null) TextSpan(text: ' $unit', style: AppText.small),
            ])),
          ),
          if (sub != null) ...[const Gap(AppSpacing.xxs), Text(sub!, style: AppText.caption)],
          if (chip != null) ...[const Gap(AppSpacing.xs + 2), chip!],
        ],
      ),
    );
  }
}

/// Full vitals grid: HR, HRV, SpO2, breathing, motion, with threshold coloring.
class VitalsGrid extends StatelessWidget {
  const VitalsGrid({super.key, required this.vitals, required this.thresholds, this.includeHr = true});

  final Vitals vitals;
  final VitalThresholds thresholds;
  final bool includeHr;

  @override
  Widget build(BuildContext context) {
    final v = vitals;
    final t = thresholds;
    Widget chip(VitalState s, {String normal = 'Normal'}) => StatusChip(labelFor(s, normal: normal), tone: toneFor(s));
    return TileGrid(children: [
      if (includeHr) VitalTile(label: 'Heart rate', value: v.hr.round().toString(), unit: 'bpm', chip: chip(v.hrState(t)),
            sub: 'normal ${t.hrLow.round()}-${t.hrHigh.round()}'),
      VitalTile(label: 'SpO2', value: v.spo2.round().toString(), unit: '%', chip: chip(v.spo2State(t)),
          sub: 'normal ${t.spo2Low.round()}-100'),
      VitalTile(label: 'HRV', value: v.hrv.round().toString(), unit: 'ms', chip: chip(v.hrvState(t)),
          sub: 'normal ${t.hrvLow.round()}+'),
      VitalTile(label: 'Breathing', value: v.resp.round().toString(), unit: '/min', chip: chip(v.respState(t))),
      VitalTile(
        label: 'Motion',
        value: v.motionLabel,
        chip: chip(v.motionState, normal: 'Calm'),
        sub: 'IMU ${(v.motion * 100).round()}%',
      ),
    ]);
  }
}

/// Seizure risk indicator with model confidence.
class RiskTile extends StatelessWidget {
  const RiskTile({super.key, required this.risk});
  final double risk;

  @override
  Widget build(BuildContext context) {
    final (label, color) = risk >= 0.7
        ? ('High', AppColors.alert)
        : risk >= 0.3
            ? ('Elevated', AppColors.warn)
            : ('Low', AppColors.ok);
    return NabraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Seizure risk'),
          const Gap(AppSpacing.xs),
          Text(label, style: AppText.title.copyWith(color: color)),
          Text('model confidence ${risk.toStringAsFixed(2)}', style: AppText.caption),
          const Gap(AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: risk,
              minHeight: AppSizes.sliderTrack,
              color: color,
              backgroundColor: AppColors.raise,
            ),
          ),
        ],
      ),
    );
  }
}
