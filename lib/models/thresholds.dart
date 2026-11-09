/// The patient's normal range for each vital. A reading that stays outside it
/// for a few seconds raises an alarm, the same way a detected seizure does.
///
/// Defaults are the usual adult resting ranges (HR 60-100 bpm, SpO2 95-100%,
/// HRV 20-100+ ms). Normal differs from person to person (age, fitness,
/// medication), so each patient can change them in Settings → Alert thresholds.
class VitalThresholds {
  const VitalThresholds({
    this.hrHigh = 100,
    this.hrLow = 60,
    this.spo2Low = 95,
    this.hrvLow = 20,
    this.respHigh = 30,
    this.respLow = 8,
  });

  final double hrHigh;
  final double hrLow;
  final double spo2Low;
  final double hrvLow;
  final double respHigh;
  final double respLow;

  factory VitalThresholds.fromMap(Map<String, dynamic>? m) {
    const def = VitalThresholds();
    if (m == null) return def;
    double v(String k, double fallback) => ((m[k] as num?) ?? fallback).toDouble();
    return VitalThresholds(
      hrHigh: v('hrHigh', def.hrHigh),
      hrLow: v('hrLow', def.hrLow),
      spo2Low: v('spo2Low', def.spo2Low),
      hrvLow: v('hrvLow', def.hrvLow),
      respHigh: v('respHigh', def.respHigh),
      respLow: v('respLow', def.respLow),
    );
  }

  Map<String, dynamic> toMap() => {
        'hrHigh': hrHigh,
        'hrLow': hrLow,
        'spo2Low': spo2Low,
        'hrvLow': hrvLow,
        'respHigh': respHigh,
        'respLow': respLow,
      };

  VitalThresholds copyWith({
    double? hrHigh,
    double? hrLow,
    double? spo2Low,
    double? hrvLow,
    double? respHigh,
    double? respLow,
  }) =>
      VitalThresholds(
        hrHigh: hrHigh ?? this.hrHigh,
        hrLow: hrLow ?? this.hrLow,
        spo2Low: spo2Low ?? this.spo2Low,
        hrvLow: hrvLow ?? this.hrvLow,
        respHigh: respHigh ?? this.respHigh,
        respLow: respLow ?? this.respLow,
      );
}
