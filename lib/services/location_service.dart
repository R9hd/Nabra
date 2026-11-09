import 'package:geolocator/geolocator.dart';

import '../models/alert_event.dart';

abstract final class LocationService {
  /// Current position, or null if unavailable / permission denied. Never throws.
  static Future<GeoPoint2?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        // No fresh GPS fix in time (e.g. indoors): use the phone's last known position.
        pos = await Geolocator.getLastKnownPosition();
      }
      return pos == null ? null : GeoPoint2(pos.latitude, pos.longitude, pos.accuracy);
    } catch (_) {
      return null;
    }
  }
}
