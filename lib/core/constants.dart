/// App-wide, non-visual constants.
abstract final class AppConstants {
  static const String appName = 'NABRA';
  static const String tagline = 'Protection that begins at seizure onset';
  static const String emergencyNumber = '997';

  /// Numbers Android/iOS treat as emergency lines (never auto-dialled by apps).
  static const Set<String> emergencyNumbers = {'997', '998', '999', '911', '112'};
  static const String termsVersion = '1.0';
  static const String deviceName = 'NABRA-C1';

  /// Patient cancel window before caregivers are alerted.
  static const Duration cancelWindow = Duration(seconds: 10);

  /// A seizure lasting longer than this is a medical emergency (status epilepticus).
  static const Duration longSeizure = Duration(minutes: 5);

  /// If nobody responds within this time after detection, the patient phone calls for help.
  static const Duration autoCallAfter = longSeizure;

  static const Duration sampleInterval = Duration(seconds: 1);
  static const Duration telemetryInterval = Duration(seconds: 5);
  static const Duration offlineAfter = Duration(seconds: 30);
  static const Duration staleAlertAge = Duration(minutes: 30);

  /// Live samples kept in memory (1 per second = last 60 s).
  static const int historySamples = 60;
  static const int trendSamples = 12;
  static const int pairingCodeLength = 5;

  /// Simulated airbag deploy latency after onset.
  static const Duration deployLatency = Duration(milliseconds: 70);
}
