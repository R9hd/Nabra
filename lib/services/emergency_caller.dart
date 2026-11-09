import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import 'contact_launcher.dart';

/// Automatic escalation call when nobody responds to an alert.
///
/// Platform limits (no app can bypass these):
///  * Android lets an app place a call by itself to a normal number (CALL_PHONE permission).
///  * Android never lets a normal app auto-dial an emergency number (997/911/112...): the
///    system opens the dialer with the number typed, and a person presses Call.
///  * iOS always asks the user before any call.
abstract final class EmergencyCaller {
  static const _phone = MethodChannel('nabra/phone');

  static String _clean(String n) => n.replaceAll(RegExp(r'[^0-9+]'), '');

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool isEmergencyNumber(String n) => AppConstants.emergencyNumbers.contains(_clean(n));

  /// Ask for the phone-call permission ahead of time (so the 5-minute call isn't blocked).
  static Future<void> requestPermission() async {
    if (!_android) return;
    try {
      await _phone.invokeMethod('requestPermission');
    } catch (_) {}
  }

  /// Returns true if a call (or the dialer) was started.
  static Future<bool> autoCall(String number) async {
    final n = _clean(number);
    if (n.isEmpty) return false;
    if (_android && !isEmergencyNumber(n)) {
      try {
        final ok = await _phone.invokeMethod<bool>('call', {'number': n});
        if (ok == true) return true;
      } catch (_) {
        // fall back to the dialer
      }
    }
    return ContactLauncher.call(n);
  }
}
