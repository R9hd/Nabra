import '../../models/app_user.dart';
import '../../models/vitals.dart';
import '../../services/contact_launcher.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../auth/auth_gate.dart';
import '../patient/live_monitor_screen.dart';
import '../shared/history_screen.dart';
import '../shared/insights_screen.dart';

/// Caregiver's live view of one patient.
class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.caregiver, required this.patientUid});
  final AppUser caregiver;
  final String patientUid;
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late final Stream<DeviceSnapshot?> _device = UserService.instance.watchDevice(widget.patientUid);

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return UserBuilder(
      uid: widget.patientUid,
      builder: (context, p) => Scaffold(
        appBar: NabraAppBar(title: p.name, initial: p.initial),
        body: StreamBuilder<DeviceSnapshot?>(
          stream: _device,
          builder: (context, snap) {
            final d = snap.data;
            final v = d?.vitals;
            final online = d?.isOnline ?? false;
            return ResponsiveBody(children: [
              NabraCard(
                borderColor: online ? AppColors.ok : AppColors.warn,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Collar'),
                          const Gap(AppSpacing.xxs),
                          Text(
                            d == null
                                ? 'Not paired'
                                : online
                                    ? 'Connected · battery ${d.battery.round()}%'
                                    : 'Offline · ${d.lastSeen == null ? 'never seen' : 'last seen ${Fmt.ago(d.lastSeen!)}'}',
                            style: AppText.bodyStrong,
                          ),
                          if (d != null)
                            Text(d.cushionArmed ? 'Cushion armed' : 'Cushion needs repacking', style: AppText.caption),
                        ],
                      ),
                    ),
                    StatusChip(online ? 'Protected' : 'Offline',
                        tone: online ? Tone.ok : Tone.warn, icon: Icons.shield_outlined),
                  ],
                ),
              ),
              if (v != null) ...[
                HeartRateCard(hr: v.hr, trend: d!.hrTrend, live: online),
                VitalsGrid(vitals: v, thresholds: p.thresholds, includeHr: false),
                RiskTile(risk: d.risk),
                Text('Updated ${Fmt.ago(v.at)} · readings refresh every ${AppConstants.telemetryInterval.inSeconds}s',
                    style: AppText.caption, textAlign: TextAlign.center),
              ],
              TileGrid(minTileWidth: AppSizes.actionTileMinWidth, children: [
                NabraButton.ghost(
                  label: 'History',
                  icon: Icons.history,
                  small: true,
                  onPressed: () => _push(HistoryScreen(user: widget.caregiver, patientUid: p.uid)),
                ),
                NabraButton.ghost(
                  label: 'Statistics',
                  icon: Icons.bar_chart_outlined,
                  small: true,
                  onPressed: () => _push(InsightsScreen(user: widget.caregiver, patientUid: p.uid)),
                ),
              ]),
              if (p.phone.isNotEmpty)
                NabraButton.ghost(
                  label: 'Call ${p.firstName} · ${p.phone}',
                  icon: Icons.phone_outlined,
                  onPressed: () => ContactLauncher.call(p.phone),
                ),
              if (p.medical.doctorPhone.isNotEmpty)
                NabraButton.ghost(
                  label: 'Call ${p.medical.doctorName.isEmpty ? 'doctor' : p.medical.doctorName}',
                  icon: Icons.local_hospital_outlined,
                  small: true,
                  onPressed: () => ContactLauncher.call(p.medical.doctorPhone),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
