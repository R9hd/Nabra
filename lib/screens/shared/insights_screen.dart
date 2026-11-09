import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../services/alert_service.dart';
import '../../services/insights_engine.dart';
import '../../services/user_service.dart';
import '../../ui.dart';

/// Statistics: plain counts from the alert history, calculated on the phone (no AI).
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.user, this.patientUid});
  final AppUser user;
  final String? patientUid;
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late final Stream<List<AlertEvent>> _alerts = AlertService.instance.forUser(widget.user);
  late final Stream<List<AppUser>>? _patients =
      widget.user.isPatient ? null : UserService.instance.linkedPatients(widget.user.uid);
  String? _person;

  @override
  void initState() {
    super.initState();
    _person = widget.patientUid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NabraAppBar(title: 'Statistics', initial: widget.user.initial),
      body: StreamBuilder<List<AppUser>>(
        stream: _patients,
        builder: (context, ps) {
          final patients = ps.data ?? const <AppUser>[];
          // Caregivers see one person at a time.
          if (!widget.user.isPatient && _person == null && patients.isNotEmpty) {
            _person = patients.first.uid;
          }
          final person = patients.where((p) => p.uid == _person).firstOrNull;
          return StreamBuilder<List<AlertEvent>>(
            stream: _alerts,
            builder: (context, snap) {
              if (!snap.hasData) return const LoadingView();
              final events = snap.data!.where((e) => _person == null || e.patientUid == _person).toList();
              final r = InsightsEngine.analyze(events);
              final name = widget.user.isPatient
                  ? null
                  : person?.firstName ?? (events.isEmpty ? 'They' : events.first.patientName.split(' ').first);
              return ResponsiveBody(children: [
                if (widget.user.isPatient == false && widget.patientUid == null && patients.length > 1)
                  FilterBar(
                    options: patients.map((p) => p.firstName).toList(),
                    selected: patients.indexWhere((p) => p.uid == _person).clamp(0, patients.length - 1),
                    onSelected: (i) => setState(() => _person = patients[i].uid),
                  ),
                NabraCard(
                  borderColor: AppColors.cyanDim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('Summary', color: AppColors.cyan),
                      const Gap(AppSpacing.xs),
                      Text(r.summary(name: name), style: AppText.body),
                    ],
                  ),
                ),
                const SectionLabel('Seizures'),
                TileGrid(children: [
                  _stat('This week', '${r.seizuresThisWeek}', 'vs ${r.seizuresLastWeek} last week'),
                  _stat('Last 30 days', '${r.seizuresThisMonth}', 'seizures'),
                  _stat('All time', '${r.seizuresTotal}', 'seizures recorded'),
                  _stat('Seizure-free', r.seizureFreeDays == null ? '–' : '${r.seizureFreeDays}',
                      r.seizureFreeDays == null ? 'no seizures yet' : 'days in a row'),
                ]),
                _bars('Seizures per week (last 8 weeks)', r.weekly, InsightsReport.weekLabels),
                _bars('Seizures by time of day', r.hourBins, InsightsReport.binLabels),
                const SectionLabel('Duration'),
                TileGrid(children: [
                  _stat('Average', r.avgDuration == null ? '–' : Fmt.duration(r.avgDuration!), 'per seizure'),
                  _stat('Longest', r.longest == null ? '–' : Fmt.duration(r.longest!), 'single seizure'),
                  _stat('Over ${AppConstants.longSeizure.inMinutes} min', '${r.longSeizures}', 'seizures',
                      color: r.longSeizures > 0 ? AppColors.alert : AppColors.fg),
                ]),
                if (r.avgPeakHr != null || r.avgMinSpo2 != null || r.avgMinHrv != null) ...[
                  const SectionLabel('Vitals during seizures (average)'),
                  TileGrid(children: [
                    if (r.avgPeakHr != null) _stat('Peak heart rate', '${r.avgPeakHr!.round()}', 'bpm'),
                    if (r.avgMinSpo2 != null) _stat('Lowest SpO2', '${r.avgMinSpo2!.round()}%', 'oxygen'),
                    if (r.avgMinHrv != null) _stat('Lowest HRV', '${r.avgMinHrv!.round()}', 'ms'),
                  ]),
                ],
                const SectionLabel('Alerts'),
                TileGrid(children: [
                  _stat('False alarms', '${r.falseAlarms}', 'cancelled in time'),
                  _stat('Vital alerts', '${r.vitalAlerts}', 'outside normal range'),
                  _stat('Response time', r.avgResponse == null ? '–' : Fmt.duration(r.avgResponse!), 'caregiver average'),
                  _stat('Automatic calls', '${r.autoCalls}', 'nobody responded'),
                ]),
                Text(
                  'Counts from the event history, calculated on this device. '
                  'They are not a diagnosis: share them with your doctor.',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _bars(String title, List<int> counts, List<String> labels) {
    final max = counts.fold<int>(0, (m, b) => b > m ? b : m);
    return NabraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          const Gap(AppSpacing.sm),
          MiniBars(values: [for (final c in counts) max == 0 ? 0 : c / max], labels: labels),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String sub, {Color color = AppColors.fg}) => NabraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const Gap(AppSpacing.xs),
            Text(value, style: AppText.title.copyWith(color: color)),
            Text(sub, style: AppText.caption),
          ],
        ),
      );
}
