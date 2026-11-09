import '../core/constants.dart';
import '../models/alert_event.dart';

/// Plain counts and averages from the alert history.
class InsightsReport {
  const InsightsReport({
    required this.seizuresThisWeek,
    required this.seizuresLastWeek,
    required this.seizuresThisMonth,
    required this.seizuresTotal,
    required this.weekly,
    required this.hourBins,
    required this.longSeizures,
    required this.falseAlarms,
    required this.vitalAlerts,
    required this.autoCalls,
    this.lastSeizure,
    this.seizureFreeDays,
    this.avgDuration,
    this.longest,
    this.avgPeakHr,
    this.avgMinSpo2,
    this.avgMinHrv,
    this.avgResponse,
  });

  final int seizuresThisWeek;
  final int seizuresLastWeek;

  /// Last 30 days.
  final int seizuresThisMonth;
  final int seizuresTotal;

  /// Seizures per week for the last 8 weeks, oldest first (last = this week).
  final List<int> weekly;

  /// 8 bins of 3 hours: 12a, 3a, 6a, 9a, 12p, 3p, 6p, 9p.
  final List<int> hourBins;
  final int longSeizures;
  final int falseAlarms;
  final int vitalAlerts;
  final int autoCalls;
  final DateTime? lastSeizure;

  /// Whole days since the last seizure (null if there was none).
  final int? seizureFreeDays;
  final Duration? avgDuration;
  final Duration? longest;
  final double? avgPeakHr;
  final double? avgMinSpo2;
  final double? avgMinHrv;
  final Duration? avgResponse;

  bool get isEmpty => seizuresTotal == 0 && falseAlarms == 0 && vitalAlerts == 0;

  static const binLabels = ['12a', '3a', '6a', '9a', '12p', '3p', '6p', '9p'];
  static const weekLabels = ['-7w', '-6w', '-5w', '-4w', '-3w', '-2w', '-1w', 'Now'];

  static String _n(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  /// Plain sentences. [name] is null for the patient's own view ("You had ...").
  String summary({String? name}) {
    if (isEmpty) return 'No events recorded yet. Statistics appear here after the first alert.';
    final who = name ?? 'You';
    final parts = [
      '$who had ${_n(seizuresThisWeek, 'seizure')} this week ($seizuresLastWeek last week) '
          'and ${_n(seizuresThisMonth, 'seizure')} in the last 30 days.',
      if (lastSeizure != null)
        seizureFreeDays == 0
            ? 'Last seizure: today.'
            : 'Last seizure: ${_n(seizureFreeDays!, 'day')} ago.',
      if (falseAlarms > 0) '${_n(falseAlarms, 'alert')} cancelled as false alarm${falseAlarms == 1 ? '' : 's'}.',
    ];
    return parts.join(' ');
  }
}

/// Counts, averages and charts from the alert history.
///
/// Plain arithmetic, no AI and no advice: runs on the phone, works offline, and no
/// patient data leaves the app for analysis (KSA privacy rules: no sharing with third parties).
abstract final class InsightsEngine {
  static double? _avg(Iterable<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

  static InsightsReport analyze(List<AlertEvent> all, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final falseAlarms = all.where((e) => e.isFalseAlarm).length;
    final real = all.where((e) => !e.isFalseAlarm && e.status != AlertStatus.pending).toList();
    final seizures = real.where((e) => e.type != AlertType.vitals).toList();
    final vitalAlerts = real.length - seizures.length;

    int age(AlertEvent e) => t.difference(e.startedAt).inDays;
    int count(int fromDays, int toDays) => seizures.where((e) => age(e) >= fromDays && age(e) < toDays).length;

    final weekly = [for (var w = 7; w >= 0; w--) count(w * 7, w * 7 + 7)];

    final bins = List<int>.filled(8, 0);
    for (final e in seizures) {
      bins[e.startedAt.hour ~/ 3]++;
    }

    DateTime? last;
    for (final e in seizures) {
      if (last == null || e.startedAt.isAfter(last)) last = e.startedAt;
    }

    final durations = seizures.map((e) => e.duration).whereType<Duration>().toList();
    final avgDurSec = _avg(durations.map((d) => d.inSeconds.toDouble()));
    final longest = durations.isEmpty ? null : durations.reduce((a, b) => a > b ? a : b);

    final responses = <double>[];
    for (final e in real) {
      final alerted = e.timeline.where((x) => x.kind == TimelineKind.alerted).firstOrNull;
      final responded = e.timeline.where((x) => x.kind == TimelineKind.responded).firstOrNull;
      if (alerted != null && responded != null) {
        responses.add(responded.at.difference(alerted.at).inSeconds.toDouble());
      }
    }
    final avgResp = _avg(responses);

    return InsightsReport(
      seizuresThisWeek: weekly.last,
      seizuresLastWeek: weekly[weekly.length - 2],
      seizuresThisMonth: count(0, 30),
      seizuresTotal: seizures.length,
      weekly: weekly,
      hourBins: bins,
      longSeizures: durations.where((d) => d >= AppConstants.longSeizure).length,
      falseAlarms: falseAlarms,
      vitalAlerts: vitalAlerts,
      autoCalls: real.where((e) => e.autoCalledAt != null).length,
      lastSeizure: last,
      seizureFreeDays: last == null ? null : t.difference(last).inDays,
      avgDuration: avgDurSec == null ? null : Duration(seconds: avgDurSec.round()),
      longest: longest,
      avgPeakHr: _avg(seizures.map((e) => e.vitals.peakHr).whereType<double>()),
      avgMinSpo2: _avg(seizures.map((e) => e.vitals.minSpo2).whereType<double>()),
      avgMinHrv: _avg(seizures.map((e) => e.vitals.minHrv).whereType<double>()),
      avgResponse: avgResp == null ? null : Duration(seconds: avgResp.round()),
    );
  }
}
