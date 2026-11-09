import 'package:flutter_test/flutter_test.dart';
import 'package:nabra/core/formatters.dart';
import 'package:nabra/models/alert_event.dart';
import 'package:nabra/models/thresholds.dart';
import 'package:nabra/models/vitals.dart';
import 'package:nabra/services/device_service.dart';
import 'package:nabra/services/insights_engine.dart';

AlertEvent _event({
  required DateTime start,
  Duration? dur,
  AlertStatus status = AlertStatus.resolved,
  AlertType type = AlertType.seizure,
  double? peakHr,
  double? minSpo2,
}) =>
    AlertEvent(
      id: '${start.millisecondsSinceEpoch}',
      patientUid: 'p1',
      patientName: 'Sara',
      caregiverIds: const ['c1'],
      type: type,
      status: status,
      confidence: 0.9,
      startedAt: start,
      endedAt: dur == null ? null : start.add(dur),
      triggers: const ['Motion pattern'],
      timeline: const [],
      vitals: VitalsSnapshot(peakHr: peakHr, minSpo2: minSpo2),
    );

void main() {
  group('Fmt', () {
    test('durations', () {
      expect(Fmt.duration(const Duration(seconds: 48)), '48s');
      expect(Fmt.duration(const Duration(seconds: 64)), '1m04s');
      expect(Fmt.clock(const Duration(minutes: 4, seconds: 59)), '04:59');
      expect(Fmt.offset(const Duration(milliseconds: 70)), '+0.07s');
    });
  });

  group('Threshold breaches', () {
    test('low SpO2 and high HR are reported, normal vitals are not', () {
      const t = VitalThresholds();
      final normal = Vitals(at: DateTime(2026), hr: 75, hrv: 45, spo2: 98, resp: 15, motion: 0.1);
      final bad = Vitals(at: DateTime(2026), hr: 140, hrv: 45, spo2: 86, resp: 15, motion: 0.1);
      expect(DeviceService.describeBreaches(normal, t), isEmpty);
      expect(DeviceService.describeBreaches(bad, t), hasLength(2));
    });
  });

  group('InsightsEngine', () {
    final now = DateTime(2026, 11, 6, 12);

    test('empty history', () {
      final r = InsightsEngine.analyze(const [], now: now);
      expect(r.isEmpty, isTrue);
      expect(r.summary(), contains('No events'));
    });

    test('weekly counts, seizure-free days, false alarms, long seizures', () {
      final events = [
        _event(start: DateTime(2026, 11, 5, 2), dur: const Duration(seconds: 48), peakHr: 142, minSpo2: 89),
        _event(start: DateTime(2026, 11, 3, 3), dur: const Duration(minutes: 6), peakHr: 150, minSpo2: 87),
        _event(start: DateTime(2026, 11, 2, 19), status: AlertStatus.cancelled),
        _event(start: DateTime(2026, 10, 28, 1), dur: const Duration(seconds: 64)),
        _event(start: DateTime(2026, 10, 27, 2), dur: const Duration(seconds: 50)),
        _event(start: DateTime(2026, 10, 26, 4), dur: const Duration(seconds: 40)),
      ];
      final r = InsightsEngine.analyze(events, now: now);
      expect(r.seizuresThisWeek, 2);
      expect(r.seizuresLastWeek, 3);
      expect(r.seizuresThisMonth, 5);
      expect(r.weekly, [0, 0, 0, 0, 0, 0, 3, 2]);
      expect(r.seizureFreeDays, 1);
      expect(r.falseAlarms, 1);
      expect(r.longSeizures, 1);
      expect(r.hourBins[0] + r.hourBins[1], 5);
      expect(r.summary(name: 'Sara'), startsWith('Sara had 2 seizures this week (3 last week)'));
      expect(r.summary(name: 'Sara'), contains('Last seizure: 1 day ago.'));
    });
  });
}
