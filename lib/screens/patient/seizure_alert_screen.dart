import 'dart:async';

import 'package:flutter/services.dart';

import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../services/alarm_service.dart';
import '../../services/alert_notifications.dart';
import '../../services/alert_service.dart';
import '../../services/device_service.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import 'seizure_timer_screen.dart';

/// Blueprint "Seizure alert": short cancel window before caregivers are alerted.
/// Every cancel is a labeled false alarm.
///
/// Also wakes the phone and shows over the lock screen (Android), with a
/// notification that has "I'm OK" / "Send now" buttons.
class SeizureAlertScreen extends StatefulWidget {
  const SeizureAlertScreen({super.key, required this.patient, required this.detection});
  final AppUser patient;
  final Detection detection;
  @override
  State<SeizureAlertScreen> createState() => _SeizureAlertScreenState();
}

class _SeizureAlertScreenState extends State<SeizureAlertScreen> {
  static const _tick = Duration(milliseconds: 100);
  late final Future<String> _alertId;
  StreamSubscription<NotificationTap>? _taps;
  Timer? _timer;
  Duration _left = AppConstants.cancelWindow;
  bool _done = false;

  String get _kind => switch (widget.detection.type) {
        AlertType.seizure => 'Seizure detected',
        AlertType.vitals => 'Dangerous vitals',
        AlertType.manual => 'Manual alert',
      };

  @override
  void initState() {
    super.initState();
    final d = widget.detection;
    AlertNotifications.setLockScreenMode(true);
    _alertId = AlertService.instance.createPending(patient: widget.patient, d: d);
    _alertId.then((id) => AlertNotifications.patientDetected(alertId: id, kind: _kind)).catchError((_) {});
    if (d.cushionDeployed) {
      UserService.instance.update(widget.patient.uid, {'cushionArmed': false}).catchError((_) {});
    }
    // Location runs in parallel and is attached when ready.
    LocationService.current().then((loc) async {
      if (loc != null) await AlertService.instance.attachLocation(await _alertId, loc);
    }).catchError((_) {});
    _taps = AlertNotifications.taps.listen((t) {
      if (t.action == AlertNotifications.actCancel) _cancel();
      if (t.action == AlertNotifications.actSend) _send();
    });
    HapticFeedback.heavyImpact();
    AlarmService.instance.start(AlarmService.patientKey);
    _timer = Timer.periodic(_tick, (_) {
      final before = _left.inSeconds;
      setState(() => _left -= _tick);
      if (_left.inSeconds != before) HapticFeedback.mediumImpact();
      if (_left <= Duration.zero) _send();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taps?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    // Not awaited: the server confirmation can be slow; Firestore uploads it when it can.
    _alertId.then(AlertService.instance.cancel).catchError((_) {});
    DeviceService.instance.clearAlert();
    AlarmService.instance.stop(AlarmService.patientKey);
    AlertNotifications.cancel(AlertNotifications.patientNotificationId);
    AlertNotifications.setLockScreenMode(false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _send() async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    try {
      final id = await _alertId;
      // Not awaited: Firestore saves it on the phone at once and uploads it as soon as the
      // network allows. Waiting for the server could leave the patient stuck on this screen.
      AlertService.instance.send(id).catchError((Object e) => debugPrint('Alert send failed: $e'));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SeizureTimerScreen(patient: widget.patient, alertId: id, type: widget.detection.type),
      ));
    } catch (e) {
      _done = false;
      if (mounted) showSnack(context, 'Could not send the alert: $e. Call ${AppConstants.emergencyNumber} if needed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detection;
    final total = AppConstants.cancelWindow.inMilliseconds;
    return PopScope(
      canPop: false,
      child: Scaffold(
        bottomNavigationBar: StickyActions(children: [
          NabraButton.ghost(label: "I'm OK · Cancel", onPressed: _cancel),
          NabraButton.alert(label: 'Send now', onPressed: _send),
        ]),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.tint(AppColors.alert), AppColors.bg],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ResponsiveBody(
              gap: AppSpacing.lg,
              maxWidth: AppSizes.narrowContentWidth,
              children: [
                const Gap(AppSpacing.sm),
                Center(child: StatusChip(_kind, tone: Tone.alert, icon: Icons.notifications_active_outlined)),
                Center(
                  child: CountdownRing(
                    secondsLeft: _left.inSeconds + (_left.inMilliseconds % 1000 > 0 ? 1 : 0),
                    progress: (_left.inMilliseconds / total).clamp(0, 1),
                  ),
                ),
                Column(children: [
                  Text('Alerting your caregivers', style: AppText.headline, textAlign: TextAlign.center),
                  const Gap(AppSpacing.xs),
                  Text('Cancel now if this is a false alarm', style: AppText.small, textAlign: TextAlign.center),
                ]),
                NabraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Detected from'),
                      const Gap(AppSpacing.xs),
                      Text('${d.triggers.join(' + ')} · confidence ${d.confidence.toStringAsFixed(2)}',
                          style: AppText.body),
                      if (d.cushionDeployed) ...[
                        const Gap(AppSpacing.sm),
                        const StatusChip('Cushion deployed', tone: Tone.warn, icon: Icons.shield_outlined),
                      ],
                      if (widget.patient.linkedCaregiverIds.isEmpty) ...[
                        const Gap(AppSpacing.sm),
                        Text('No caregivers linked yet. Call ${AppConstants.emergencyNumber} if you need help.',
                            style: AppText.caption.copyWith(color: AppColors.warn)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
