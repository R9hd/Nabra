import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import 'thresholds.dart';

enum UserRole {
  patient,
  caregiver;

  String get label => this == patient ? 'Patient' : 'Caregiver';
  static UserRole parse(Object? v) => v == 'caregiver' ? caregiver : patient;
}

/// Optional medical profile + care team (doctor / hospital) of a patient.
class MedicalProfile {
  const MedicalProfile({
    this.seizureTypes = '',
    this.medications = '',
    this.allergies = '',
    this.bloodType = '',
    this.doctorName = '',
    this.doctorPhone = '',
    this.doctorEmail = '',
    this.hospitalName = '',
    this.hospitalPhone = '',
  });

  final String seizureTypes;
  final String medications;
  final String allergies;
  final String bloodType;
  final String doctorName;
  final String doctorPhone;
  final String doctorEmail;
  final String hospitalName;
  final String hospitalPhone;

  bool get hasCareTeam =>
      doctorPhone.isNotEmpty || doctorEmail.isNotEmpty || hospitalPhone.isNotEmpty;

  factory MedicalProfile.fromMap(Map<String, dynamic>? m) {
    final d = m ?? const {};
    String s(String k) => (d[k] as String?) ?? '';
    return MedicalProfile(
      seizureTypes: s('seizureTypes'),
      medications: s('medications'),
      allergies: s('allergies'),
      bloodType: s('bloodType'),
      doctorName: s('doctorName'),
      doctorPhone: s('doctorPhone'),
      doctorEmail: s('doctorEmail'),
      hospitalName: s('hospitalName'),
      hospitalPhone: s('hospitalPhone'),
    );
  }

  Map<String, dynamic> toMap() => {
        'seizureTypes': seizureTypes,
        'medications': medications,
        'allergies': allergies,
        'bloodType': bloodType,
        'doctorName': doctorName,
        'doctorPhone': doctorPhone,
        'doctorEmail': doctorEmail,
        'hospitalName': hospitalName,
        'hospitalPhone': hospitalPhone,
      };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.linkedCaregiverIds = const [],
    this.linkedPatientIds = const [],
    this.pairingCode,
    this.setupComplete = false,
    this.devicePaired = false,
    this.cushionArmed = true,
    this.sensitivity = 0.6,
    this.thresholds = const VitalThresholds(),
    this.medical = const MedicalProfile(),
    this.autoCallEnabled = true,
    this.autoCallNumber = AppConstants.emergencyNumber,
    this.alarmSound = true,
    this.lockScreenDetails = true,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final List<String> linkedCaregiverIds;
  final List<String> linkedPatientIds;
  final String? pairingCode;
  final bool setupComplete;
  final bool devicePaired;
  final bool cushionArmed;

  /// 0 = fewer false alarms, 1 = most sensitive.
  final double sensitivity;
  final VitalThresholds thresholds;
  final MedicalProfile medical;

  /// Call for help automatically when nobody responds within 5 minutes.
  final bool autoCallEnabled;
  final String autoCallNumber;

  /// Loud looping alarm during an alert (off = vibration + notification only).
  final bool alarmSound;

  /// Show health details and first aid on the lock screen (off = a neutral
  /// "NABRA alert" with no health details, and no full-screen takeover).
  final bool lockScreenDetails;

  bool get isPatient => role == UserRole.patient;
  String get firstName => name.trim().split(' ').first;
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: (d['name'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      role: UserRole.parse(d['role']),
      linkedCaregiverIds: List<String>.from((d['linkedCaregiverIds'] as List?) ?? const []),
      linkedPatientIds: List<String>.from((d['linkedPatientIds'] as List?) ?? const []),
      pairingCode: d['pairingCode'] as String?,
      setupComplete: (d['setupComplete'] as bool?) ?? false,
      devicePaired: (d['devicePaired'] as bool?) ?? false,
      cushionArmed: (d['cushionArmed'] as bool?) ?? true,
      sensitivity: ((d['sensitivity'] as num?) ?? 0.6).toDouble(),
      thresholds: VitalThresholds.fromMap(d['thresholds'] as Map<String, dynamic>?),
      medical: MedicalProfile.fromMap(d['medicalProfile'] as Map<String, dynamic>?),
      autoCallEnabled: (d['autoCallEnabled'] as bool?) ?? true,
      autoCallNumber: ((d['autoCallNumber'] as String?) ?? '').isEmpty
          ? AppConstants.emergencyNumber
          : d['autoCallNumber'] as String,
      alarmSound: (d['alarmSound'] as bool?) ?? true,
      lockScreenDetails: (d['lockScreenDetails'] as bool?) ?? true,
    );
  }
}
