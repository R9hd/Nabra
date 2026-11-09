import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../services/alert_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import 'event_detail_screen.dart';
import 'send_report_sheet.dart';

/// Blueprint "History". For caregivers every row carries the patient's name,
/// and they can filter by person.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.user, this.patientUid});
  final AppUser user;

  /// Lock the list to one patient (caregiver drilling into a person).
  final String? patientUid;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Filter { all, seizures, vitals, falseAlarms }

class _HistoryScreenState extends State<HistoryScreen> {
  late final Stream<List<AlertEvent>> _alerts = AlertService.instance.forUser(widget.user);
  late final Stream<List<AppUser>>? _patients =
      widget.user.isPatient ? null : UserService.instance.linkedPatients(widget.user.uid);

  _Filter _filter = _Filter.all;
  String? _person;

  static const _filterLabels = ['All', 'Seizures', 'Vital alerts', 'False alarms'];

  @override
  void initState() {
    super.initState();
    _person = widget.patientUid;
  }

  bool _match(AlertEvent e) {
    if (_person != null && e.patientUid != _person) return false;
    return switch (_filter) {
      _Filter.all => true,
      _Filter.seizures => !e.isFalseAlarm && e.type != AlertType.vitals,
      _Filter.vitals => !e.isFalseAlarm && e.type == AlertType.vitals,
      _Filter.falseAlarms => e.isFalseAlarm,
    };
  }

  Color _iconColor(AlertEvent e) => e.isFalseAlarm
      ? AppColors.warn
      : e.type == AlertType.vitals
          ? AppColors.cyan
          : AppColors.alert;

  Future<void> _sendLog(List<AlertEvent> all, List<AppUser> patients) async {
    final AppUser? patient;
    if (widget.user.isPatient) {
      patient = widget.user;
    } else {
      final uid = _person ?? (patients.length == 1 ? patients.first.uid : null);
      if (uid == null) {
        showSnack(context, 'Pick a person first, then send their log.');
        return;
      }
      patient = patients.where((p) => p.uid == uid).firstOrNull ?? await UserService.instance.get(uid);
    }
    if (!mounted || patient == null) return;
    final events = all.where((e) => e.patientUid == patient!.uid).toList();
    await showSendReportSheet(
      context,
      viewer: widget.user,
      patient: patient,
      subject: 'NABRA seizure log · ${patient.name}',
      body: ReportService.history(events, patient),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCaregiver = !widget.user.isPatient;
    return Scaffold(
      appBar: NabraAppBar(title: 'History', initial: widget.user.initial),
      body: StreamBuilder<List<AppUser>>(
        stream: _patients,
        builder: (context, ps) {
          final patients = ps.data ?? const <AppUser>[];
          return StreamBuilder<List<AlertEvent>>(
            stream: _alerts,
            builder: (context, snap) {
              if (snap.hasError) {
                return ResponsiveBody(children: [
                  EmptyState(icon: Icons.error_outline, title: 'Could not load history', body: '${snap.error}'),
                ]);
              }
              if (!snap.hasData) return const LoadingView();
              final all = snap.data!;
              final items = all.where(_match).toList();
              return ResponsiveBody(children: [
                if (isCaregiver && widget.patientUid == null && patients.length > 1)
                  FilterBar(
                    options: ['All people', ...patients.map((p) => p.firstName)],
                    selected: _person == null ? 0 : patients.indexWhere((p) => p.uid == _person) + 1,
                    onSelected: (i) => setState(() => _person = i == 0 ? null : patients[i - 1].uid),
                  ),
                FilterBar(
                  options: _filterLabels,
                  selected: _filter.index,
                  onSelected: (i) => setState(() => _filter = _Filter.values[i]),
                ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nothing here yet',
                    body: 'Detected events and alerts will be logged here.',
                  )
                else
                  NabraCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card),
                    child: RowList(rows: [
                      for (final e in items)
                        ListRow(
                          top: isCaregiver
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: StatusChip(e.patientName, tone: Tone.cyan, icon: Icons.person_outline),
                                )
                              : null,
                          leading: IconBox(Icons.bolt, color: _iconColor(e)),
                          title: e.title,
                          subtitle: [
                            Fmt.dateTime(e.startedAt),
                            if (e.duration != null && !e.isFalseAlarm) Fmt.duration(e.duration!),
                            e.outcome,
                          ].join(' · '),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EventDetailScreen(viewer: widget.user, alertId: e.id),
                          )),
                        ),
                    ]),
                  ),
                if (all.isNotEmpty)
                  NabraButton.ghost(
                    label: 'Send seizure log to doctor',
                    icon: Icons.send_outlined,
                    small: true,
                    onPressed: () => _sendLog(all, patients),
                  ),
              ]);
            },
          );
        },
      ),
    );
  }
}
