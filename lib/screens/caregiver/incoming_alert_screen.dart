import 'dart:async';

import 'package:flutter/services.dart';

import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../models/vitals.dart';
import '../../services/alarm_service.dart';
import '../../services/alert_notifications.dart';
import '../../services/alert_service.dart';
import '../../services/contact_launcher.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../shared/event_detail_screen.dart';
import '../shared/seizure_widgets.dart';

/// Blueprint "Incoming alert": fastest path to help.
/// The key actions are pinned at the bottom: respond, call 997, seizure ended.
class IncomingAlertScreen extends StatefulWidget {
  const IncomingAlertScreen({super.key, required this.caregiver, required this.alertId});
  final AppUser caregiver;
  final String alertId;

  /// Alerts currently on screen (so a notification tap doesn't open a duplicate).
  static final openIds = <String>{};

  @override
  State<IncomingAlertScreen> createState() => _IncomingAlertScreenState();
}

class _IncomingAlertScreenState extends State<IncomingAlertScreen> {
  late final Stream<AlertEvent?> _alert = AlertService.instance.watch(widget.alertId);
  Stream<DeviceSnapshot?>? _device;
  Future<AppUser?>? _patient;
  Timer? _clock;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    IncomingAlertScreen.openIds.add(widget.alertId);
    AlertNotifications.setLockScreenMode(true);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    HapticFeedback.heavyImpact();
    AlarmService.instance.start(widget.alertId);
  }

  void _silence() {
    AlarmService.instance.stop(widget.alertId);
    setState(() {});
  }

  /// The alarm would drown out the call, so it stops first.
  void _call() {
    _silence();
    ContactLauncher.call(AppConstants.emergencyNumber);
  }

  @override
  void dispose() {
    IncomingAlertScreen.openIds.remove(widget.alertId);
    if (IncomingAlertScreen.openIds.isEmpty) AlertNotifications.setLockScreenMode(false);
    _clock?.cancel();
    AlarmService.instance.stop(widget.alertId);
    super.dispose();
  }

  Future<void> _do(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What to say to the emergency operator, ready to read out or copy.
  String _script(AlertEvent a) {
    final loc = a.location == null
        ? 'location not shared'
        : 'location ${a.location!.lat.toStringAsFixed(5)}, ${a.location!.lng.toStringAsFixed(5)}';
    final hr = a.vitals.peakHr == null ? '' : ' Heart rate up to ${a.vitals.peakHr!.round()}.';
    return '${a.patientName} has epilepsy and may be having a seizure. '
        'It started at ${Fmt.time(a.startedAt)}, ${Fmt.duration(a.elapsed)} ago. '
        'Their $loc.$hr Detected by a NABRA seizure collar.';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AlertEvent?>(
      stream: _alert,
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) return const Scaffold(body: LoadingView());
        if (a.status != AlertStatus.active) AlarmService.instance.stop(widget.alertId);
        _device ??= UserService.instance.watchDevice(a.patientUid);
        _patient ??= UserService.instance.get(a.patientUid);
        final ended = !a.status.isLive;
        final mine = a.responderUid == widget.caregiver.uid;
        final first = a.patientName.split(' ').first;
        return Scaffold(
          appBar: const NabraAppBar(title: 'Emergency'),
          bottomNavigationBar: ended
              ? null
              : StickyActions(children: [
                  NabraButton(
                    label: mine ? "You're responding" : "I'm responding",
                    icon: Icons.check,
                    loading: _busy,
                    onPressed: mine ? null : () => _do(() => AlertService.instance.respond(a.id, widget.caregiver)),
                  ),
                  Row(
                    children: withGaps([
                      Expanded(
                        child: NabraButton.alert(
                          label: 'Call ${AppConstants.emergencyNumber}',
                          icon: Icons.call,
                          small: true,
                          onPressed: _call,
                        ),
                      ),
                      Expanded(
                        child: NabraButton.ghost(
                          label: 'Seizure ended',
                          icon: Icons.timer_off_outlined,
                          small: true,
                          onPressed: _busy
                              ? null
                              : () => _do(() => AlertService.instance.end(a.id, byName: widget.caregiver.firstName)),
                        ),
                      ),
                    ], AppSpacing.sm),
                  ),
                ]),
          body: ResponsiveBody(children: [
            Center(
              child: StatusChip(
                ended ? (a.isFalseAlarm ? 'Cancelled' : 'Resolved') : 'Emergency',
                tone: ended ? Tone.ok : Tone.alert,
                icon: ended ? Icons.check : Icons.notifications_active_outlined,
              ),
            ),
            Column(children: [
              Text(
                a.type == AlertType.vitals
                    ? "$first's vitals are in the danger range"
                    : '$first may be having a seizure',
                style: AppText.headline,
                textAlign: TextAlign.center,
              ),
              const Gap(AppSpacing.xs),
              Text(
                'Detected ${Fmt.clock(DateTime.now().difference(a.startedAt))} ago · confidence ${a.confidence.toStringAsFixed(2)}',
                style: AppText.small,
                textAlign: TextAlign.center,
              ),
            ]),
            if (!ended) ...[
              if (a.status == AlertStatus.responding && !mine)
                Center(
                  child: StatusChip('${a.responderName ?? 'Someone'} is responding',
                      tone: Tone.ok, icon: Icons.directions_run),
                ),
              SeizureClock(elapsed: a.elapsed),
              if (a.elapsed >= AppConstants.longSeizure) const LongSeizureBanner(),
              if (a.autoCalledAt != null)
                StatusChip("Patient's phone auto-called for help at ${Fmt.time(a.autoCalledAt!)}",
                    tone: Tone.warn, icon: Icons.call_made),
            ],
            // Phase 2: real map tiles. Today: stylized card + "Open in Maps".
            MapPreview(hasLocation: a.location != null),
            NabraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Location'),
                  const Gap(AppSpacing.xs),
                  if (a.location == null)
                    Text('Location not shared (permission off or unavailable).', style: AppText.small)
                  else ...[
                    Text.rich(TextSpan(children: [
                      TextSpan(
                        text: '${a.location!.lat.toStringAsFixed(5)}, ${a.location!.lng.toStringAsFixed(5)}',
                        style: AppText.body,
                      ),
                      TextSpan(text: ' · accurate to ${a.location!.accuracy.round()}m', style: AppText.small),
                    ])),
                    const Gap(AppSpacing.sm),
                    NabraButton.ghost(
                      label: 'Open in Maps',
                      icon: Icons.map_outlined,
                      small: true,
                      onPressed: () => ContactLauncher.openMap(a.location!.lat, a.location!.lng),
                    ),
                  ],
                ],
              ),
            ),
            if (!ended) _callPatientButton(first),
            if (!ended)
              NabraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel("Can't reach them? Tell ${AppConstants.emergencyNumber}:"),
                    const Gap(AppSpacing.xs),
                    Text(_script(a), style: AppText.body),
                    const Gap(AppSpacing.sm),
                    NabraButton.ghost(
                      label: 'Copy',
                      icon: Icons.copy,
                      small: true,
                      onPressed: () {
                        ContactLauncher.copy(_script(a));
                        showSnack(context, 'Copied');
                      },
                    ),
                  ],
                ),
              ),
            _liveVitals(),
            NabraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Detected from'),
                  const Gap(AppSpacing.xs),
                  Text(a.triggers.join(' + '), style: AppText.body),
                ],
              ),
            ),
            NabraButton.ghost(
              label: 'View details',
              icon: Icons.description_outlined,
              small: true,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EventDetailScreen(viewer: widget.caregiver, alertId: a.id),
              )),
            ),
          ]),
        );
      },
    );
  }

  Widget _callPatientButton(String first) => FutureBuilder<AppUser?>(
        future: _patient,
        builder: (context, s) {
          final phone = s.data?.phone ?? '';
          return NabraButton.ghost(
            label: phone.isEmpty ? 'Call $first' : 'Call $first · $phone',
            icon: Icons.phone_outlined,
            onPressed: phone.isEmpty ? null : () => ContactLauncher.call(phone),
          );
        },
      );

  Widget _liveVitals() => StreamBuilder<DeviceSnapshot?>(
        stream: _device,
        builder: (context, s) {
          final v = s.data?.vitals;
          if (v == null) return const SizedBox.shrink();
          return TileGrid(children: [
            VitalTile(label: 'Heart rate', value: Fmt.num0(v.hr), unit: 'bpm'),
            VitalTile(label: 'SpO2', value: Fmt.num0(v.spo2), unit: '%'),
            VitalTile(label: 'Breathing', value: Fmt.num0(v.resp), unit: '/min'),
          ]);
        },
      );
}
