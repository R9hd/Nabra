import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/vitals.dart';

class LinkException implements Exception {
  const LinkException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _codes => _db.collection('pairingCodes');

  Stream<AppUser?> watch(String uid) =>
      _users.doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> get(String uid) async {
    final d = await _users.doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Future<void> update(String uid, Map<String, dynamic> data) =>
      _users.doc(uid).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  /// Patients who added this caregiver (via pairing code).
  Stream<List<AppUser>> linkedPatients(String caregiverUid) => _users
      .where('linkedCaregiverIds', arrayContains: caregiverUid)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));

  /// Caregivers linked to this patient.
  Stream<List<AppUser>> linkedCaregivers(String patientUid) => _users
      .where('linkedPatientIds', arrayContains: patientUid)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));

  Stream<DeviceSnapshot?> watchDevice(String patientUid) => _db
      .collection('devices')
      .doc(patientUid)
      .snapshots()
      .map((d) => d.exists ? DeviceSnapshot.fromDoc(d) : null);

  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Creates (or replaces) the patient's pairing code.
  Future<String> generatePairingCode(AppUser patient) async {
    final rand = Random.secure();
    final code = List.generate(
      AppConstants.pairingCodeLength,
      (_) => _alphabet[rand.nextInt(_alphabet.length)],
    ).join();
    final batch = _db.batch();
    if (patient.pairingCode != null) batch.delete(_codes.doc(patient.pairingCode));
    batch.set(_codes.doc(code), {
      'patientUid': patient.uid,
      'patientName': patient.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_users.doc(patient.uid), {'pairingCode': code, 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
    return code;
  }

  /// Caregiver enters a patient's code. Returns the patient's name.
  Future<String> linkWithCode(AppUser caregiver, String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length != AppConstants.pairingCodeLength) {
      throw const LinkException('Codes are ${AppConstants.pairingCodeLength} characters long.');
    }
    final snap = await _codes.doc(code).get();
    if (!snap.exists) throw const LinkException('That code was not found. Ask the patient to check it.');
    final patientUid = snap.data()!['patientUid'] as String;
    final patientName = (snap.data()!['patientName'] as String?) ?? 'Patient';
    if (patientUid == caregiver.uid) throw const LinkException('You cannot link to yourself.');

    final batch = _db.batch();
    // Only touch linkedCaregiverIds on the patient doc (allowed by security rules).
    batch.update(_users.doc(patientUid), {
      'linkedCaregiverIds': FieldValue.arrayUnion([caregiver.uid]),
    });
    batch.update(_users.doc(caregiver.uid), {
      'linkedPatientIds': FieldValue.arrayUnion([patientUid]),
      'setupComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return patientName;
  }

  Future<void> unlink({required String patientUid, required String caregiverUid}) async {
    final batch = _db.batch();
    batch.update(_users.doc(patientUid), {
      'linkedCaregiverIds': FieldValue.arrayRemove([caregiverUid]),
    });
    batch.update(_users.doc(caregiverUid), {
      'linkedPatientIds': FieldValue.arrayRemove([patientUid]),
    });
    await batch.commit();
  }
}
