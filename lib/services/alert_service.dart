import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/alert_event.dart';
import '../models/app_user.dart';
import 'device_service.dart';

class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _alerts => _db.collection('alerts');

  Map<String, dynamic> _entry(String label, TimelineKind kind, [DateTime? at]) =>
      TimelineEntry(label: label, kind: kind, at: at ?? DateTime.now()).toMap();

  /// Creates the alert while the patient's cancel window is running.
  ///
  /// Returns the id right away. Firestore saves the write on the phone at once and
  /// uploads it when the network allows, so a slow or missing connection never
  /// blocks the alert screens (the server confirmation can take long).
  Future<String> createPending({required AppUser patient, required Detection d}) async {
    final ref = _alerts.doc();
    final detectedLabel = switch (d.type) {
      AlertType.seizure => 'Onset detected',
      AlertType.vitals => 'Dangerous vitals detected',
      AlertType.manual => 'Manual alert started',
    };
    ref.set({
      'patientUid': patient.uid,
      'patientName': patient.name,
      'caregiverIds': patient.linkedCaregiverIds,
      'type': d.type.name,
      'status': AlertStatus.pending.name,
      'confidence': d.confidence,
      'startedAt': Timestamp.fromDate(d.at),
      'triggers': d.triggers,
      'timeline': [
        _entry(detectedLabel, TimelineKind.detected, d.at),
        if (d.cushionDeployed)
          _entry('Cushion deployed', TimelineKind.deployed, d.at.add(AppConstants.deployLatency)),
      ],
      'vitals': {
        'peakHr': d.vitals.hr,
        'minSpo2': d.vitals.spo2,
        'minHrv': d.vitals.hrv,
        'peakResp': d.vitals.resp,
        'peakMotion': d.vitals.motion,
      },
      'createdAt': FieldValue.serverTimestamp(),
    }).catchError((Object e) => debugPrint('Alert create failed: $e'));
    return ref.id;
  }

  Future<void> attachLocation(String id, GeoPoint2 p) => _alerts.doc(id).update({
        'location': {'lat': p.lat, 'lng': p.lng, 'accuracy': p.accuracy},
      });

  Future<void> cancel(String id) => _alerts.doc(id).update({
        'status': AlertStatus.cancelled.name,
        'endedAt': Timestamp.now(),
        'timeline': FieldValue.arrayUnion([_entry('Cancelled by patient (false alarm)', TimelineKind.cancelled)]),
      });

  Future<void> send(String id) => _alerts.doc(id).update({
        'status': AlertStatus.active.name,
        'alertedAt': Timestamp.now(),
        'timeline': FieldValue.arrayUnion([_entry('Caregivers alerted', TimelineKind.alerted)]),
      });

  Future<void> respond(String id, AppUser responder) => _alerts.doc(id).update({
        'status': AlertStatus.responding.name,
        'responderUid': responder.uid,
        'responderName': responder.name,
        'timeline': FieldValue.arrayUnion([_entry('${responder.firstName} responded', TimelineKind.responded)]),
      });

  /// Someone with the patient (using the patient's phone) says they are helping.
  /// Counts as a response, so the automatic emergency call is not placed.
  Future<void> respondBystander(String id) => _alerts.doc(id).update({
        'status': AlertStatus.responding.name,
        'responderName': 'Someone with the patient',
        'timeline': FieldValue.arrayUnion([_entry('Someone with the patient responded', TimelineKind.responded)]),
      });

  Future<void> logAutoCall(String id, String number) => _alerts.doc(id).update({
        'autoCalledAt': Timestamp.now(),
        'timeline': FieldValue.arrayUnion([
          _entry('No response in ${AppConstants.autoCallAfter.inMinutes} min · auto-calling $number', TimelineKind.alerted),
        ]),
      });

  Future<void> end(String id, {required String byName, VitalsSnapshot? vitals}) => _alerts.doc(id).update({
        'status': AlertStatus.resolved.name,
        'endedAt': Timestamp.now(),
        'timeline': FieldValue.arrayUnion([_entry('Ended · marked by $byName', TimelineKind.ended)]),
        if (vitals != null && vitals.toMap().isNotEmpty) 'vitals': vitals.toMap(),
      });

  Future<void> updateVitals(String id, VitalsSnapshot v) => _alerts.doc(id).update({'vitals': v.toMap()});

  Stream<AlertEvent?> watch(String id) =>
      _alerts.doc(id).snapshots().map((d) => d.exists ? AlertEvent.fromDoc(d) : null);

  /// Sorted client-side to avoid needing composite indexes.
  List<AlertEvent> _sorted(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(AlertEvent.fromDoc).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  Stream<List<AlertEvent>> forPatient(String uid) =>
      _alerts.where('patientUid', isEqualTo: uid).snapshots().map(_sorted);

  /// Alerts for every patient this caregiver looks after (pending ones are hidden).
  Stream<List<AlertEvent>> forCaregiver(String uid) => _alerts
      .where('caregiverIds', arrayContains: uid)
      .snapshots()
      .map((s) => _sorted(s).where((a) => a.status != AlertStatus.pending).toList());

  Stream<List<AlertEvent>> forUser(AppUser user) =>
      user.isPatient ? forPatient(user.uid) : forCaregiver(user.uid);
}
