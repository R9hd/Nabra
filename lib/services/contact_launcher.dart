import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phone calls, SMS, email and maps. Hospitals aren't on a shared system,
/// so reports go out the way they can actually receive them: phone/SMS/email.
abstract final class ContactLauncher {
  static String _clean(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

  static Future<bool> call(String phone) => _open(Uri(scheme: 'tel', path: _clean(phone)));

  static Future<bool> sms(String phone, String body) =>
      _open(Uri.parse('sms:${_clean(phone)}?body=${Uri.encodeComponent(body)}'));

  static Future<bool> email(String to, {required String subject, required String body}) => _open(
        Uri.parse('mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}'),
      );

  static Future<bool> openMap(double lat, double lng) =>
      _open(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'));

  static Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
