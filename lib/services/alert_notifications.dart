import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants.dart';

/// A tap on the notification or one of its buttons.
class NotificationTap {
  const NotificationTap(this.action, this.alertId);

  /// null = the notification body itself was tapped (or shown full-screen).
  final String? action;
  final String? alertId;
}

/// Lock-screen alerts.
///
/// On Android an emergency notification:
///  * turns the screen on and opens NABRA over the lock screen (full-screen intent),
///  * shows a live seizure timer and first-aid steps on the lock screen,
///  * has buttons (I'm OK / Seizure ended / Call 997 / I'm responding).
/// iOS shows a normal notification (apps can't draw over the iOS lock screen).
/// Web: nothing (not supported).
abstract final class AlertNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _lockScreen = MethodChannel('nabra/lockscreen');
  static final _taps = StreamController<NotificationTap>.broadcast();
  static bool _ready = false;

  /// The user chose to hide health details on the lock screen: notifications
  /// say only "NABRA alert" and the app never opens over the lock screen.
  static bool privateMode = false;

  static const _privateTitle = 'NABRA alert';
  static const _privateBody = 'Unlock your phone and open NABRA to see what happened.';

  static const _channelId = 'nabra_emergency';
  static const _channelName = 'Emergency alerts';
  static const patientNotificationId = 1;
  static int caregiverNotificationId(String alertId) => alertId.hashCode & 0x7fffffff;

  // Action ids
  static const actCancel = 'cancel';
  static const actSend = 'send';
  static const actEnded = 'ended';
  static const actCall = 'call';
  static const actRespond = 'respond';

  static Stream<NotificationTap> get taps => _taps.stream;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static const firstAidText = '1. Stay with them and time the seizure.\n'
      '2. Move hard objects away, cushion the head.\n'
      '3. Do not hold them down, nothing in the mouth.\n'
      '4. When jerking stops, roll them onto their side.\n'
      '5. Over 5 minutes: call ${AppConstants.emergencyNumber}.';

  static Future<void> init() async {
    if (!supported || _ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _taps.add(NotificationTap(r.actionId, r.payload)),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  /// Ask once for notification + full-screen permissions (Android 13+/14+).
  static Future<void> requestPermissions() async {
    if (!_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestFullScreenIntentPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, sound: true, badge: false);
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Let the app show over the lock screen (only while an alert is active).
  static Future<void> setLockScreenMode(bool on) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (on && privateMode) return;
    try {
      await _lockScreen.invokeMethod(on ? 'enable' : 'disable');
    } catch (_) {}
  }

  static AndroidNotificationAction _action(String id, String label) =>
      AndroidNotificationAction(id, label, showsUserInterface: true, cancelNotification: false);

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String alertId,
    required List<AndroidNotificationAction> actions,
    DateTime? timerFrom,
    bool fullScreen = true,
  }) async {
    if (!_ready) return;
    if (privateMode) {
      title = _privateTitle;
      body = _privateBody;
      fullScreen = false;
    }
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Seizure and dangerous-vitals alerts',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            fullScreenIntent: fullScreen,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: !fullScreen,
            usesChronometer: timerFrom != null,
            when: timerFrom?.millisecondsSinceEpoch,
            showWhen: timerFrom != null,
            styleInformation: BigTextStyleInformation(body),
            actions: actions,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: alertId,
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }

  // ---------- patient phone ----------

  static Future<void> patientDetected({required String alertId, required String kind}) => _show(
        id: patientNotificationId,
        title: '$kind · NABRA',
        body: 'Alerting your caregivers in ${AppConstants.cancelWindow.inSeconds}s. '
            'Tap "I\'m OK" if this is a false alarm.\n\n$firstAidText',
        alertId: alertId,
        actions: [_action(actCancel, "I'm OK · Cancel"), _action(actSend, 'Send now')],
      );

  static Future<void> patientInProgress({
    required String alertId,
    required DateTime startedAt,
    required String status,
  }) =>
      _show(
        id: patientNotificationId,
        title: 'Seizure in progress · $status',
        body: firstAidText,
        alertId: alertId,
        timerFrom: startedAt,
        fullScreen: false,
        actions: [
          _action(actEnded, privateMode ? 'End alert' : 'Seizure ended'),
          _action(actCall, 'Call ${AppConstants.emergencyNumber}'),
        ],
      );

  // ---------- caregiver phone ----------

  static Future<void> caregiverAlert({
    required String alertId,
    required String patientName,
    required DateTime startedAt,
  }) =>
      _show(
        id: caregiverNotificationId(alertId),
        title: 'Emergency: $patientName may be having a seizure',
        body: 'Tap to see location, timer and actions.\n\n$firstAidText',
        alertId: alertId,
        timerFrom: startedAt,
        actions: [
          _action(actRespond, "I'm responding"),
          _action(actCall, 'Call ${AppConstants.emergencyNumber}'),
        ],
      );

  static Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
