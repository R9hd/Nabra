import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import 'thresholds.dart';

enum VitalState { normal, caution, danger }

/// One biosignal sample from the collar.
class Vitals {
  const Vitals({
    required this.at,
    required this.hr,
    required this.hrv,
    required this.spo2,
    required this.resp,
    required this.motion,
  });

  final DateTime at;

  /// Heart rate, bpm.
  final double hr;

  /// Heart-rate variability (RMSSD), ms. Derived from beat-to-beat intervals.
  final double hrv;

  /// Blood oxygen saturation, %.
  final double spo2;

  /// Respiratory rate, breaths/min.
  final double resp;

  /// Motion intensity 0..1 from the IMU.
  final double motion;

  Map<String, dynamic> toMap() => {
        'at': Timestamp.fromDate(at),
        'hr': hr,
        'hrv': hrv,
        'spo2': spo2,
        'resp': resp,
        'motion': motion,
      };

  static Vitals? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    double v(String k) => ((m[k] as num?) ?? 0).toDouble();
    return Vitals(
      at: (m['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hr: v('hr'),
      hrv: v('hrv'),
      spo2: v('spo2'),
      resp: v('resp'),
      motion: v('motion'),
    );
  }

  // Outside the normal range = danger. Inside but close to a limit = caution.
  VitalState hrState(VitalThresholds t) => hr > t.hrHigh || hr < t.hrLow
      ? VitalState.danger
      : (hr >= t.hrHigh - 10 || hr <= t.hrLow + 5 ? VitalState.caution : VitalState.normal);

  VitalState spo2State(VitalThresholds t) =>
      spo2 < t.spo2Low ? VitalState.danger : (spo2 < t.spo2Low + 1 ? VitalState.caution : VitalState.normal);

  VitalState hrvState(VitalThresholds t) =>
      hrv < t.hrvLow ? VitalState.danger : (hrv < t.hrvLow + 5 ? VitalState.caution : VitalState.normal);

  VitalState respState(VitalThresholds t) => resp > t.respHigh || resp < t.respLow
      ? VitalState.danger
      : (resp >= t.respHigh - 5 ? VitalState.caution : VitalState.normal);

  VitalState get motionState =>
      motion >= 0.6 ? VitalState.danger : (motion >= 0.35 ? VitalState.caution : VitalState.normal);

  String get motionLabel => switch (motionState) {
        VitalState.danger => 'Convulsive',
        VitalState.caution => 'Active',
        VitalState.normal => 'Normal',
      };
}

/// Live device state as published to Firestore (`devices/{patientUid}`).
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.patientUid,
    required this.status,
    required this.battery,
    required this.cushionArmed,
    required this.lastSeen,
    required this.vitals,
    required this.risk,
    required this.hrTrend,
  });

  final String patientUid;
  final String status; // armed | alert | offline
  final double battery;
  final bool cushionArmed;
  final DateTime? lastSeen;
  final Vitals? vitals;
  final double risk;
  final List<double> hrTrend;

  bool get isOnline =>
      lastSeen != null && DateTime.now().difference(lastSeen!) < AppConstants.offlineAfter;

  factory DeviceSnapshot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return DeviceSnapshot(
      patientUid: doc.id,
      status: (d['status'] as String?) ?? 'offline',
      battery: ((d['battery'] as num?) ?? 0).toDouble(),
      cushionArmed: (d['cushionArmed'] as bool?) ?? true,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      vitals: Vitals.fromMap(d['vitals'] as Map<String, dynamic>?),
      risk: ((d['risk'] as num?) ?? 0).toDouble(),
      hrTrend: ((d['hrTrend'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
    );
  }
}
