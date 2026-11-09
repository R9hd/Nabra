import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../models/vitals.dart';
import '../../services/alert_service.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../onboarding/link_patient_screen.dart';
import 'incoming_alert_screen.dart';
import 'patient_detail_screen.dart';

/// Blueprint "Caregiver home" (My people): status chip per linked patient.
class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  late final Stream<List<AppUser>> _patients = UserService.instance.linkedPatients(widget.user.uid);
  late final Stream<List<AlertEvent>> _alerts = AlertService.instance.forCaregiver(widget.user.uid);

  void _link() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => LinkPatientScreen(user: widget.user)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NabraAppBar(title: 'My people', initial: widget.user.initial),
      body: StreamBuilder<List<AppUser>>(
        stream: _patients,
        builder: (context, ps) {
          if (!ps.hasData) return const LoadingView();
          final patients = ps.data!;
          return StreamBuilder<List<AlertEvent>>(
            stream: _alerts,
            builder: (context, as) {
              final live = {
                for (final a in (as.data ?? const <AlertEvent>[]).where((a) => a.status.isLive)) a.patientUid: a,
              };
              return ResponsiveBody(children: [
                if (patients.isEmpty)
                  const EmptyState(
                    icon: Icons.group_add_outlined,
                    title: 'No one linked yet',
                    body: 'Ask the person you care for to share their pairing code.',
                  ),
                for (final p in patients)
                  PersonCard(key: ValueKey(p.uid), caregiver: widget.user, patient: p, liveAlert: live[p.uid]),
                NabraButton.ghost(
                  label: patients.isEmpty ? 'Link a person' : 'Link another person',
                  icon: Icons.person_add_alt,
                  small: true,
                  onPressed: _link,
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class PersonCard extends StatefulWidget {
  const PersonCard({super.key, required this.caregiver, required this.patient, this.liveAlert});
  final AppUser caregiver;
  final AppUser patient;
  final AlertEvent? liveAlert;
  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard> {
  late final Stream<DeviceSnapshot?> _device = UserService.instance.watchDevice(widget.patient.uid);

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final alert = widget.liveAlert;
    return StreamBuilder<DeviceSnapshot?>(
      stream: _device,
      builder: (context, snap) {
        final d = snap.data;
        final (Tone tone, String chip, IconData icon, String sub) = alert != null
            ? (
                Tone.alert,
                alert.status == AlertStatus.responding ? 'Responding' : 'Alert now',
                Icons.notifications_active_outlined,
                alert.type == AlertType.vitals
                    ? 'Dangerous vitals · tap to respond'
                    : 'Seizure detected · ${Fmt.clock(alert.elapsed)} · tap to respond',
              )
            : d == null
                ? (Tone.neutral, 'No collar', Icons.link_off, 'Collar not paired yet')
                : d.isOnline
                    ? (
                        Tone.ok,
                        'Protected',
                        Icons.shield_outlined,
                        'Collar connected · battery ${d.battery.round()}%'
                            '${d.cushionArmed ? '' : ' · cushion needs repack'}',
                      )
                    : (
                        Tone.warn,
                        'Offline',
                        Icons.cloud_off_outlined,
                        d.lastSeen == null ? 'Not seen yet' : 'Last seen ${Fmt.ago(d.lastSeen!)}',
                      );
        final v = d?.vitals;
        return NabraCard(
          borderColor: alert != null ? AppColors.alert : null,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => alert != null
                ? IncomingAlertScreen(caregiver: widget.caregiver, alertId: alert.id)
                : PatientDetailScreen(caregiver: widget.caregiver, patientUid: p.uid),
          )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(p.name, style: AppText.bodyStrong, overflow: TextOverflow.ellipsis)),
                  StatusChip(chip, tone: tone, icon: icon),
                ],
              ),
              const Gap(AppSpacing.xs),
              Text(sub, style: AppText.small),
              if (v != null && d!.isOnline && alert == null) ...[
                const Gap(AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _mini(Icons.favorite_border, '${Fmt.num0(v.hr)} bpm', toneFor(v.hrState(p.thresholds))),
                    _mini(Icons.water_drop_outlined, 'SpO2 ${Fmt.num0(v.spo2)}%', toneFor(v.spo2State(p.thresholds))),
                    _mini(Icons.show_chart, 'HRV ${Fmt.num0(v.hrv)} ms', toneFor(v.hrvState(p.thresholds))),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _mini(IconData icon, String text, Tone tone) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconXs, color: tone.color),
          const Gap(AppSpacing.xs),
          Text(text, style: AppText.caption.copyWith(color: AppColors.fg)),
        ],
      );
}
