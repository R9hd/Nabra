import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType {
  seizure,
  vitals,
  manual;

  static AlertType parse(Object? v) =>
      AlertType.values.firstWhere((e) => e.name == v, orElse: () => AlertType.seizure);
}

enum AlertStatus {
  /// Detected, patient cancel window running. Caregivers don't see it yet.
  pending,

  /// Caregivers alerted, nobody responding yet.
  active,
  responding,
  resolved,
  cancelled;

  bool get isLive => this == active || this == responding;

  static AlertStatus parse(Object? v) =>
      AlertStatus.values.firstWhere((e) => e.name == v, orElse: () => AlertStatus.pending);
}

enum TimelineKind { detected, deployed, alerted, responded, ended, cancelled, note }

class TimelineEntry {
  const TimelineEntry({required this.label, required this.kind, required this.at});

  final String label;
  final TimelineKind kind;
  final DateTime at;

  Map<String, dynamic> toMap() => {'label': label, 'kind': kind.name, 'at': Timestamp.fromDate(at)};

  factory TimelineEntry.fromMap(Map<String, dynamic> m) => TimelineEntry(
        label: (m['label'] as String?) ?? '',
        kind: TimelineKind.values.firstWhere((e) => e.name == m['kind'], orElse: () => TimelineKind.note),
        at: (m['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

class GeoPoint2 {
  const GeoPoint2(this.lat, this.lng, this.accuracy);
  final double lat;
  final double lng;
  final double accuracy;
}

/// Vital-sign extremes recorded during an event.
class VitalsSnapshot {
  const VitalsSnapshot({this.peakHr, this.minSpo2, this.minHrv, this.peakResp, this.peakMotion});

  final double? peakHr;
  final double? minSpo2;
  final double? minHrv;
  final double? peakResp;
  final double? peakMotion;

  factory VitalsSnapshot.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const VitalsSnapshot();
    double? v(String k) => (m[k] as num?)?.toDouble();
    return VitalsSnapshot(
      peakHr: v('peakHr'),
      minSpo2: v('minSpo2'),
      minHrv: v('minHrv'),
      peakResp: v('peakResp'),
      peakMotion: v('peakMotion'),
    );
  }

  Map<String, dynamic> toMap() => {
        if (peakHr != null) 'peakHr': peakHr,
        if (minSpo2 != null) 'minSpo2': minSpo2,
        if (minHrv != null) 'minHrv': minHrv,
        if (peakResp != null) 'peakResp': peakResp,
        if (peakMotion != null) 'peakMotion': peakMotion,
      };
}

class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.patientUid,
    required this.patientName,
    required this.caregiverIds,
    required this.type,
    required this.status,
    required this.confidence,
    required this.startedAt,
    required this.triggers,
    required this.timeline,
    required this.vitals,
    this.endedAt,
    this.location,
    this.responderUid,
    this.responderName,
    this.autoCalledAt,
  });

  final String id;
  final String patientUid;
  final String patientName;
  final List<String> caregiverIds;
  final AlertType type;
  final AlertStatus status;
  final double confidence;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> triggers;
  final List<TimelineEntry> timeline;
  final VitalsSnapshot vitals;
  final GeoPoint2? location;
  final String? responderUid;
  final String? responderName;

  /// When the patient phone auto-called for help (nobody responded in time).
  final DateTime? autoCalledAt;

  bool get isFalseAlarm => status == AlertStatus.cancelled;
  Duration? get duration => endedAt?.difference(startedAt);
  Duration get elapsed => (endedAt ?? DateTime.now()).difference(startedAt);
  bool get cushionDeployed => timeline.any((e) => e.kind == TimelineKind.deployed);

  String get title {
    if (isFalseAlarm) return 'Auto-detected · cancelled';
    return switch (type) {
      AlertType.seizure => cushionDeployed ? 'Seizure · cushion deployed' : 'Seizure detected',
      AlertType.vitals => 'Dangerous vitals · ${triggers.isEmpty ? 'alert' : triggers.first}',
      AlertType.manual => 'Manual alert',
    };
  }

  String get outcome => switch (status) {
        AlertStatus.pending => 'awaiting confirmation',
        AlertStatus.active => 'caregivers alerted',
        AlertStatus.responding => '${responderName ?? 'caregiver'} responding',
        AlertStatus.resolved => responderName != null ? 'caregiver responded' : 'resolved',
        AlertStatus.cancelled => 'false alarm',
      };

  factory AlertEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final loc = d['location'] as Map<String, dynamic>?;
    final timeline = ((d['timeline'] as List?) ?? const [])
        .map((e) => TimelineEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return AlertEvent(
      id: doc.id,
      patientUid: (d['patientUid'] as String?) ?? '',
      patientName: (d['patientName'] as String?) ?? '',
      caregiverIds: List<String>.from((d['caregiverIds'] as List?) ?? const []),
      type: AlertType.parse(d['type']),
      status: AlertStatus.parse(d['status']),
      confidence: ((d['confidence'] as num?) ?? 0).toDouble(),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (d['endedAt'] as Timestamp?)?.toDate(),
      triggers: List<String>.from((d['triggers'] as List?) ?? const []),
      timeline: timeline,
      vitals: VitalsSnapshot.fromMap(d['vitals'] as Map<String, dynamic>?),
      location: loc == null
          ? null
          : GeoPoint2(
              (loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble(),
              ((loc['accuracy'] as num?) ?? 0).toDouble(),
            ),
      responderUid: d['responderUid'] as String?,
      responderName: d['responderName'] as String?,
      autoCalledAt: (d['autoCalledAt'] as Timestamp?)?.toDate(),
    );
  }
}
