import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/thresholds.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    await _db.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role.name,
      'consent': {
        'termsVersion': AppConstants.termsVersion,
        'acceptedAt': FieldValue.serverTimestamp(),
      },
      'setupComplete': false,
      'devicePaired': false,
      'cushionArmed': true,
      'linkedCaregiverIds': <String>[],
      'linkedPatientIds': <String>[],
      'sensitivity': 0.6,
      if (role == UserRole.patient) 'thresholds': const VitalThresholds().toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Human-readable message for auth errors.
  static String message(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'That email address looks wrong.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account with this email already exists. Log in instead.',
        'weak-password' => 'Choose a stronger password (at least 6 characters).',
        'network-request-failed' => 'No internet connection. Try again.',
        'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
        'user-disabled' => 'This account has been disabled.',
        _ => error.message ?? 'Something went wrong. Try again.',
      };
    }
    if (error is FirebaseException) return error.message ?? 'Something went wrong. Try again.';
    return error.toString();
  }
}
