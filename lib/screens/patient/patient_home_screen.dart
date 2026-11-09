import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../services/alert_service.dart';
import '../../services/device_service.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../shared/care_team_screen.dart';
import '../shared/event_detail_screen.dart';

/// Blueprint "Patient home": one glance tells them they are protected.
class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key, required this.user, required this.onOpenMonitor, required this.onOpenHistory});
  final AppUser user;
  final VoidCallback onOpenMonitor;
  final VoidCallback onOpenHistory;
  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  late final Stream<List<AlertEvent>> _alerts = AlertService.instance.forPatient(widget.user.uid);
  final _device = DeviceService.instance;

  Future<void> _markRepacked() async {
    _device.configure(cushionArmed: true);
    await UserService.instance.update(widget.user.uid, {'cushionArmed': true});
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: NabraAppBar(title: 'Home', initial: u.initial),
      body: ListenableBuilder(
        listenable: _device,
        builder: (context, _) {
          final v = _device.latest;
          return ResponsiveBody(children: [
            _statusCard(u),
            if (u.devicePaired && v != null) ...[
              TileGrid(children: [
                VitalTile(
                  label: 'Heart rate',
                  value: Fmt.num0(v.hr),
                  unit: 'bpm',
                  chip: StatusChip(labelFor(v.hrState(u.thresholds)), tone: toneFor(v.hrState(u.thresholds))),
                ),
                VitalTile(
                  label: 'SpO2',
                  value: Fmt.num0(v.spo2),
                  unit: '%',
                  chip: StatusChip(labelFor(v.spo2State(u.thresholds)), tone: toneFor(v.spo2State(u.thresholds))),
                ),
                VitalTile(
                  label: 'HRV',
                  value: Fmt.num0(v.hrv),
                  unit: 'ms',
                  chip: StatusChip(labelFor(v.hrvState(u.thresholds)), tone: toneFor(v.hrvState(u.thresholds))),
                ),
                VitalTile(
                  label: 'Battery',
                  value: Fmt.num0(_device.battery),
                  unit: '%',
                  chip: StatusChip('~${_device.batteryHoursLeft.round()}h',
                      tone: Tone.cyan, icon: Icons.battery_std_outlined),
                ),
              ]),
              _cushionCard(),
              Row(
                children: withGaps([
                  Expanded(
                    child: NabraButton.ghost(
                      label: 'Test alert',
                      small: true,
                      onPressed: _device.alertActive ? null : _device.triggerManual,
                    ),
                  ),
                  Expanded(child: NabraButton.ghost(label: 'Live view', small: true, onPressed: widget.onOpenMonitor)),
                ], AppSpacing.md - 2),
              ),
            ],
            _recentCard(u),
            if (!u.medical.hasCareTeam) _careTeamNudge(u),
          ]);
        },
      ),
    );
  }

  Widget _statusCard(AppUser u) {
    final (Color border, Tone tone, String chip, IconData icon, String title, String sub) = !u.devicePaired
        ? (AppColors.warn, Tone.warn, 'Not paired', Icons.link_off, 'Collar not paired', 'Pair your collar to start monitoring')
        : _device.alertActive
            ? (AppColors.alert, Tone.alert, 'Alert', Icons.notifications_active_outlined, 'Alert in progress',
                'Caregivers are being notified')
            : !_device.cushionArmed
                ? (AppColors.warn, Tone.warn, 'Repack', Icons.shield_outlined, 'Partially protected',
                    'Monitoring active · cushion needs repacking')
                : (AppColors.ok, Tone.ok, 'Protected', Icons.shield_outlined, "You're covered",
                    'Collar connected · monitoring active');
    return NabraCard(
      borderColor: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Status')),
              StatusChip(chip, tone: tone, icon: icon),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(title, style: AppText.display),
          const Gap(AppSpacing.xs),
          Text(sub, style: AppText.small),
          if (!u.devicePaired) ...[
            const Gap(AppSpacing.md),
            NabraButton(
              label: 'Pair collar',
              small: true,
              icon: Icons.bluetooth_searching,
              onPressed: () => UserService.instance.update(u.uid, {'devicePaired': true, 'cushionArmed': true}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cushionCard() {
    final armed = _device.cushionArmed;
    return NabraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Cushion'),
                    const Gap(AppSpacing.xxs),
                    Text(armed ? 'Ready to deploy' : 'Repack needed', style: AppText.bodyStrong),
                  ],
                ),
              ),
              armed
                  ? const StatusChip('Armed', tone: Tone.ok, icon: Icons.check)
                  : const StatusChip('Deployed', tone: Tone.warn, icon: Icons.warning_amber_rounded),
            ],
          ),
          if (!armed) ...[
            const Gap(AppSpacing.md - 2),
            NabraButton.ghost(label: 'Mark cushion repacked', small: true, onPressed: _markRepacked),
          ],
        ],
      ),
    );
  }

  Widget _recentCard(AppUser u) {
    return StreamBuilder<List<AlertEvent>>(
      stream: _alerts,
      builder: (context, snap) {
        final last = (snap.data ?? const []).firstOrNull;
        return NabraCard(
          onTap: widget.onOpenHistory,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Recent'),
              if (last == null)
                const ListRow(
                  divider: false,
                  leading: IconBox(Icons.check, color: AppColors.ok),
                  title: 'No events yet',
                  subtitle: 'Events will appear here',
                )
              else
                ListRow(
                  divider: false,
                  leading: IconBox(Icons.bolt, color: last.isFalseAlarm ? AppColors.warn : AppColors.alert),
                  title: last.title,
                  subtitle: '${Fmt.dateTime(last.startedAt)} · ${last.outcome}',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EventDetailScreen(viewer: u, alertId: last.id),
                  )),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _careTeamNudge(AppUser u) => NabraCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CareTeamScreen(uid: u.uid))),
        child: const ListRow(
          divider: false,
          leading: IconBox(Icons.local_hospital_outlined),
          title: 'Add your doctor',
          subtitle: 'Send seizure timelines to your doctor or hospital in one tap',
          trailing: Icon(Icons.chevron_right, color: AppColors.muted),
        ),
      );
}
