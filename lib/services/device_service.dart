import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/alert_event.dart';
import '../models/thresholds.dart';
import '../models/vitals.dart';

enum SimScenario { none, seizure, lowSpo2 }

/// Something the detection engine decided needs an alert.
class Detection {
  const Detection({
    required this.type,
    required this.confidence,
    required this.triggers,
    required this.at,
    required this.vitals,
    required this.cushionDeployed,
  });

  final AlertType type;
  final double confidence;
  final List<String> triggers;
  final DateTime at;
  final Vitals vitals;
  final bool cushionDeployed;
}

/// The collar connection.
///
/// Today this simulates the collar (no hardware yet): it produces realistic
/// HR / HRV / SpO2 / respiration / motion samples once per second and lets
/// you simulate a seizure or an oxygen drop for the demo. When the ESP32 + BLE
/// build is ready, replace [_generate] with samples read via flutter_blue_plus;
/// detection, alarms and Firestore sync stay the same.
class DeviceService extends ChangeNotifier {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  final _rand = Random();
  final _db = FirebaseFirestore.instance;
  final List<Vitals> _history = [];
  final _detections = StreamController<Detection>.broadcast();

  Timer? _sampleTimer;
  Timer? _syncTimer;
  String? _uid;
  VitalThresholds _thresholds = const VitalThresholds();
  double _sensitivity = 0.6;
  SimScenario _scenario = SimScenario.none;
  int _scenarioTick = 0;
  bool _alertActive = false;
  bool _cushionArmed = true;
  double _battery = 86;
  double _baselineHr = 72;
  double _risk = 0.03;
  int _seizureStreak = 0;
  int _vitalsStreak = 0;

  // Extremes recorded while an alert is active.
  double? _peakHr, _minSpo2, _minHrv, _peakResp, _peakMotion;

  bool get running => _sampleTimer != null;
  List<Vitals> get history => List.unmodifiable(_history);
  Vitals? get latest => _history.isEmpty ? null : _history.last;
  double get battery => _battery;
  double get batteryHoursLeft => _battery / 100 * 26;
  bool get cushionArmed => _cushionArmed;
  double get risk => _risk;
  bool get alertActive => _alertActive;
  VitalThresholds get thresholds => _thresholds;
  Stream<Detection> get detections => _detections.stream;

  VitalsSnapshot get eventSnapshot => VitalsSnapshot(
        peakHr: _peakHr,
        minSpo2: _minSpo2,
        minHrv: _minHrv,
        peakResp: _peakResp,
        peakMotion: _peakMotion,
      );

  void start({
    required String uid,
    required VitalThresholds thresholds,
    required double sensitivity,
    required bool cushionArmed,
  }) {
    configure(thresholds: thresholds, sensitivity: sensitivity, cushionArmed: cushionArmed);
    if (_uid == uid && running) return;
    stop();
    _uid = uid;
    _sampleTimer = Timer.periodic(AppConstants.sampleInterval, (_) => _tick());
    _syncTimer = Timer.periodic(AppConstants.telemetryInterval, (_) => _sync());
    _tick();
    _sync();
  }

  void configure({VitalThresholds? thresholds, double? sensitivity, bool? cushionArmed}) {
    _thresholds = thresholds ?? _thresholds;
    _sensitivity = sensitivity ?? _sensitivity;
    _cushionArmed = cushionArmed ?? _cushionArmed;
    notifyListeners();
  }

  void stop() {
    _sampleTimer?.cancel();
    _syncTimer?.cancel();
    _sampleTimer = null;
    _syncTimer = null;
    final uid = _uid;
    if (uid != null) {
      _db.collection('devices').doc(uid).set({'status': 'offline'}, SetOptions(merge: true)).catchError((_) {});
    }
    _uid = null;
    _history.clear();
    _scenario = SimScenario.none;
    _alertActive = false;
  }

  // ---- demo controls ----
  void simulateSeizure() => _setScenario(SimScenario.seizure);
  void simulateLowSpo2() => _setScenario(SimScenario.lowSpo2);

  void _setScenario(SimScenario s) {
    _scenario = s;
    _scenarioTick = 0;
    notifyListeners();
  }

  /// "Test alert" / manual SOS from the patient.
  void triggerManual() {
    final v = latest;
    if (v == null || _alertActive) return;
    _fire(Detection(
      type: AlertType.manual,
      confidence: 1,
      triggers: const ['Manual alert from patient'],
      at: DateTime.now(),
      vitals: v,
      cushionDeployed: false,
    ));
  }

  /// Called by the alert flow when the alert is cancelled or resolved.
  void clearAlert() {
    _alertActive = false;
    _seizureStreak = 0;
    _vitalsStreak = 0;
    _scenario = SimScenario.none;
    notifyListeners();
    _sync();
  }

  // ---- engine ----
  void _tick() {
    final v = _generate();
    _history.add(v);
    if (_history.length > AppConstants.historySamples) _history.removeAt(0);
    _battery = max(5, _battery - 0.002);
    _risk = _computeRisk(v);
    if (_scenario == SimScenario.none && _risk < 0.2) _baselineHr = _baselineHr * 0.95 + v.hr * 0.05;

    if (_alertActive) {
      _trackExtremes(v);
    } else {
      _detect(v);
    }
    notifyListeners();
  }

  double _noise(double amp) => (_rand.nextDouble() * 2 - 1) * amp;

  Vitals _generate() {
    final t = _scenarioTick++;
    final now = DateTime.now();
    switch (_scenario) {
      case SimScenario.seizure:
        final ramp = min(1.0, t / 4);
        final drop = min(1.0, t / 25);
        return Vitals(
          at: now,
          hr: 74 + 76 * ramp + _noise(5),
          hrv: max(6, 45 - 36 * ramp + _noise(2)),
          spo2: (98 - 10 * drop + _noise(0.6)).clamp(70, 100),
          resp: 15 + 13 * ramp + _noise(3),
          motion: (0.55 + 0.4 * ramp * (0.75 + 0.25 * sin(t * 2.1)) + _noise(0.05)).clamp(0, 1),
        );
      case SimScenario.lowSpo2:
        final drop = min(1.0, t / 8);
        return Vitals(
          at: now,
          hr: 76 + 22 * drop + _noise(3),
          hrv: 40 - 12 * drop + _noise(2),
          spo2: (97.5 - 12 * drop + _noise(0.5)).clamp(70, 100),
          resp: 15 + 7 * drop + _noise(1.5),
          motion: (0.08 + _noise(0.04)).clamp(0, 1),
        );
      case SimScenario.none:
        return Vitals(
          at: now,
          hr: 72 + 4 * sin(now.second / 9.5) + _noise(2.5),
          hrv: 44 + _noise(5),
          spo2: (97.8 + _noise(0.8)).clamp(70, 100),
          resp: 15 + _noise(1.2),
          motion: (0.1 + _noise(0.06)).clamp(0, 1),
        );
    }
  }

  /// bpm above the personal baseline that counts as a surge (lower = more sensitive).
  double get _hrSurge => 45 - 20 * _sensitivity;
  double get _motionGate => 0.75 - 0.25 * _sensitivity;
  static const _seizureConfirm = 3;
  static const _vitalsConfirm = 5;

  double _computeRisk(Vitals v) {
    final hrPart = ((v.hr - _baselineHr) / _hrSurge).clamp(0.0, 1.5);
    final motionPart = (v.motion / _motionGate).clamp(0.0, 1.5);
    final z = 4.5 * (hrPart * 0.5 + motionPart * 0.5) - 4;
    return 1 / (1 + exp(-z));
  }

  void _detect(Vitals v) {
    // 1) Seizure signature: heart-rate surge + convulsive motion, confirmed over a window.
    final seizureLike = v.hr - _baselineHr >= _hrSurge && v.motion >= _motionGate;
    _seizureStreak = seizureLike ? _seizureStreak + 1 : 0;
    if (_seizureStreak >= _seizureConfirm) {
      _fire(Detection(
        type: AlertType.seizure,
        confidence: _risk.clamp(0.5, 0.99),
        triggers: const ['Motion pattern', 'Heart-rate surge'],
        at: DateTime.now(),
        vitals: v,
        cushionDeployed: _cushionArmed,
      ));
      return;
    }

    // 2) Dangerous vitals: a reading outside the patient's normal range (their
    //    thresholds, editable in Settings) for a sustained period.
    final breaches = describeBreaches(v, _thresholds);
    _vitalsStreak = breaches.isNotEmpty ? _vitalsStreak + 1 : 0;
    if (_vitalsStreak >= _vitalsConfirm) {
      _fire(Detection(
        type: AlertType.vitals,
        confidence: 0.95,
        triggers: breaches,
        at: DateTime.now(),
        vitals: v,
        cushionDeployed: false,
      ));
    }
  }

  /// Readings outside the patient's normal range (their thresholds).
  static List<String> describeBreaches(Vitals v, VitalThresholds t) => [
        if (v.spo2 < t.spo2Low) 'SpO2 ${v.spo2.round()}% (normal ${t.spo2Low.round()}-100%)',
        if (v.hr > t.hrHigh) 'Heart rate ${v.hr.round()} bpm (normal ${t.hrLow.round()}-${t.hrHigh.round()})',
        if (v.hr < t.hrLow) 'Heart rate ${v.hr.round()} bpm (normal ${t.hrLow.round()}-${t.hrHigh.round()})',
        if (v.hrv < t.hrvLow) 'HRV ${v.hrv.round()} ms (normal ${t.hrvLow.round()}+ ms)',
        if (v.resp > t.respHigh) 'Breathing ${v.resp.round()}/min (limit ${t.respHigh.round()})',
        if (v.resp < t.respLow) 'Breathing ${v.resp.round()}/min (limit ${t.respLow.round()})',
      ];

  void _fire(Detection d) {
    _alertActive = true;
    _seizureStreak = 0;
    _vitalsStreak = 0;
    _peakHr = _minSpo2 = _minHrv = _peakResp = _peakMotion = null;
    _trackExtremes(d.vitals);
    if (d.cushionDeployed) _cushionArmed = false;
    _detections.add(d);
    notifyListeners();
    _sync();
  }

  void _trackExtremes(Vitals v) {
    _peakHr = max(_peakHr ?? v.hr, v.hr);
    _minSpo2 = min(_minSpo2 ?? v.spo2, v.spo2);
    _minHrv = min(_minHrv ?? v.hrv, v.hrv);
    _peakResp = max(_peakResp ?? v.resp, v.resp);
    _peakMotion = max(_peakMotion ?? v.motion, v.motion);
  }

  List<double> get _hrTrend {
    final step = max(1, _history.length ~/ AppConstants.trendSamples);
    return [for (var i = 0; i < _history.length; i += step) double.parse(_history[i].hr.toStringAsFixed(1))];
  }

  Future<void> _sync() async {
    final uid = _uid;
    final v = latest;
    if (uid == null || v == null) return;
    try {
      await _db.collection('devices').doc(uid).set({
        'ownerUid': uid,
        'name': AppConstants.deviceName,
        'status': _alertActive ? 'alert' : 'armed',
        'battery': double.parse(_battery.toStringAsFixed(1)),
        'cushionArmed': _cushionArmed,
        'lastSeen': FieldValue.serverTimestamp(),
        'vitals': v.toMap(),
        'risk': _risk,
        'hrTrend': _hrTrend,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Device sync failed: $e');
    }
  }
}
