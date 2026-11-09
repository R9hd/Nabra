import 'dart:async';

import 'package:flutter/services.dart';

import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../services/alarm_service.dart';
import '../../services/alert_notifications.dart';
import '../../services/alert_service.dart';
import '../../services/contact_launcher.dart';
import '../../services/device_service.dart';
import '../../services/emergency_caller.dart';
import '../../ui.dart';
import '../shared/seizure_widgets.dart';

/// Seizure timer on the patient's phone (for whoever is with them).
/// Shows duration, the 5-minute emergency mark, live vitals and first aid,
/// and calls for help automatically if nobody responds within 5 minutes.
class SeizureTimerScreen extends StatefulWidget {
  const SeizureTimerScreen({super.key, required this.patient, required this.alertId, required this.type});
  final AppUser patient;
  final String alertId;
  final AlertType type;
  @override
  State<SeizureTimerScreen> createState() => _SeizureTimerScreenState();
}

class _SeizureTimerScreenState extends State<SeizureTimerScreen> {
  static const _vitalsPush = Duration(seconds: 10);
  late final Stream<AlertEvent?> _alert = AlertService.instance.watch(widget.alertId);
  final _device = DeviceService.instance;
  StreamSubscription<NotificationTap>? _taps;
  Timer? _clock;
  Timer? _vitalsTimer;
  AlertStatus? _notifiedStatus;
  bool _ending = false;
  bool _closed = false;
  bool _warned = false;
  bool _autoCalling = false;

  String get _number => widget.patient.autoCallNumber;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _vitalsTimer = Timer.periodic(_vitalsPush, (_) {
      AlertService.instance.updateVitals(widget.alertId, _device.eventSnapshot).catchError((_) {});
    });
    _taps = AlertNotifications.taps.listen((t) {
      if (t.action == AlertNotifications.actEnded) _end();
      if (t.action == AlertNotifications.actCall) _call();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _vitalsTimer?.cancel();
    _taps?.cancel();
    super.dispose();
  }

  final _alarm = AlarmService.instance;

  void _silence() {
    _alarm.stop(AlarmService.patientKey);
    setState(() {});
  }

  /// The alarm would drown out the call, so it stops first.
  void _call() {
    _silence();
    ContactLauncher.call(AppConstants.emergencyNumber);
  }

  Future<void> _end() async {
    if (_ending || _closed) return;
    setState(() => _ending = true);
    // Not awaited: Firestore saves it on the phone at once and uploads it when the network
    // allows, so a slow connection doesn't keep the patient on this screen.
    AlertService.instance
        .end(widget.alertId, byName: 'patient phone', vitals: _device.eventSnapshot)
        .catchError((Object e) => debugPrint('Alert end failed: $e'));
    _close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _device.clearAlert();
    _alarm.stop(AlarmService.patientKey);
    AlertNotifications.cancel(AlertNotifications.patientNotificationId);
    AlertNotifications.setLockScreenMode(false);
    if (mounted) Navigator.of(context).pop();
  }

  /// Keeps the lock-screen notification in sync with the alert.
  void _syncNotification(AlertEvent a) {
    if (_notifiedStatus == a.status) return;
    _notifiedStatus = a.status;
    if (a.status != AlertStatus.active) _alarm.stop(AlarmService.patientKey);
    AlertNotifications.patientInProgress(
      alertId: a.id,
      startedAt: a.startedAt,
      status: a.status == AlertStatus.responding ? '${a.responderName ?? 'help'} responding' : 'caregivers alerted',
    );
  }

  /// Nobody responded within 5 minutes → call for help automatically (once).
  void _checkAutoCall(AlertEvent a) {
    final due = widget.patient.autoCallEnabled &&
        a.status == AlertStatus.active &&
        a.autoCalledAt == null &&
        a.elapsed >= AppConstants.autoCallAfter;
    if (!due || _autoCalling) return;
    _autoCalling = true;
    HapticFeedback.heavyImpact();
    AlertService.instance.logAutoCall(a.id, _number).catchError((_) {});
    _alarm.stop(AlarmService.patientKey);
    EmergencyCaller.autoCall(_number);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: StreamBuilder<AlertEvent?>(
        stream: _alert,
        builder: (context, snap) {
          final a = snap.data;
          if (a == null) return const Scaffold(body: LoadingView());
          if (a.status == AlertStatus.resolved || a.status == AlertStatus.cancelled) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _close());
            return const Scaffold(body: LoadingView());
          }
          _syncNotification(a);
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoCall(a));
          final elapsed = a.elapsed;
          final long = elapsed >= AppConstants.longSeizure;
          if (long && !_warned) {
            _warned = true;
            HapticFeedback.heavyImpact();
          }
          final v = _device.latest;
          return Scaffold(
            bottomNavigationBar: StickyActions(children: [
              NabraButton(
                label: widget.type == AlertType.vitals ? 'I am OK now · End alert' : 'Seizure ended',
                icon: Icons.check,
                loading: _ending,
                onPressed: _end,
              ),
              NabraButton.alert(
                label: 'Call ${AppConstants.emergencyNumber} (ambulance)',
                icon: Icons.call,
                onPressed: _call,
              ),
            ]),
            body: SafeArea(
              bottom: false,
              child: ResponsiveBody(children: [
                const Gap(AppSpacing.sm),
                Center(
                  child: StatusChip(
                    widget.type == AlertType.vitals ? 'Dangerous vitals' : 'Seizure in progress',
                    tone: Tone.alert,
                    icon: Icons.timer_outlined,
                  ),
                ),
                SeizureClock(elapsed: elapsed),
                if (_alarm.playing)
                  Center(
                    child: TextButton.icon(
                      onPressed: _silence,
                      icon: const Icon(Icons.volume_off_outlined),
                      label: const Text('Silence alarm'),
                    ),
                  ),
                if (long) const LongSeizureBanner(),
                _responseCard(a),
                if (v != null)
                  TileGrid(children: [
                    VitalTile(label: 'Heart rate', value: Fmt.num0(v.hr), unit: 'bpm'),
                    VitalTile(label: 'SpO2', value: Fmt.num0(v.spo2), unit: '%'),
                    VitalTile(label: 'Breathing', value: Fmt.num0(v.resp), unit: '/min'),
                  ]),
                const FirstAidCard(),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _responseCard(AlertEvent a) {
    if (a.status == AlertStatus.responding) {
      return NabraCard(
        child: ListRow(
          divider: false,
          leading: const IconBox(Icons.directions_run, color: AppColors.ok),
          title: '${a.responderName ?? 'A caregiver'} is responding',
          subtitle: 'Help is on the way',
        ),
      );
    }
    final enabled = widget.patient.autoCallEnabled;
    final left = AppConstants.autoCallAfter - a.elapsed;
    final emergency = EmergencyCaller.isEmergencyNumber(_number);
    return NabraCard(
      borderColor: AppColors.warn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListRow(
            divider: false,
            leading: const IconBox(Icons.notifications_active_outlined, color: AppColors.warn),
            title: a.caregiverIds.isEmpty ? 'No caregivers linked' : 'No one has responded yet',
            subtitle: a.autoCalledAt != null
                ? 'Called $_number automatically at ${Fmt.time(a.autoCalledAt!)}'
                : enabled
                    ? 'Calling $_number automatically in ${Fmt.clock(left.isNegative ? Duration.zero : left)}'
                    : 'Automatic call is off (Settings)',
          ),
          if (enabled && a.autoCalledAt == null && emergency)
            Text(
              'Phones never let apps dial emergency numbers alone: the dialer will open with $_number ready. Press Call.',
              style: AppText.caption,
            ),
          if (a.autoCalledAt == null) ...[
            const Gap(AppSpacing.sm),
            NabraButton.ghost(
              label: "I'm with them · don't call",
              icon: Icons.front_hand_outlined,
              small: true,
              onPressed: () => AlertService.instance.respondBystander(a.id),
            ),
          ],
        ],
      ),
    );
  }
}
