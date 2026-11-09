import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../services/alert_service.dart';
import '../../services/contact_launcher.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import 'send_report_sheet.dart';

/// Blueprint "Event detail": the millisecond timeline, vitals, and doctor export.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.viewer, required this.alertId});
  final AppUser viewer;
  final String alertId;
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final Stream<AlertEvent?> _alert = AlertService.instance.watch(widget.alertId);
  Future<AppUser?>? _patient;

  static Color _kindColor(TimelineKind k) => switch (k) {
        TimelineKind.detected => AppColors.cyan,
        TimelineKind.deployed => AppColors.warn,
        TimelineKind.alerted => AppColors.alert,
        TimelineKind.responded || TimelineKind.ended => AppColors.ok,
        TimelineKind.cancelled => AppColors.warn,
        TimelineKind.note => AppColors.muted,
      };

  (String, Tone, IconData) _statusChip(AlertEvent a) => switch (a.status) {
        AlertStatus.resolved => ('Resolved', Tone.ok, Icons.check),
        AlertStatus.cancelled => ('False alarm', Tone.warn, Icons.close),
        AlertStatus.responding => ('Responding', Tone.cyan, Icons.directions_run),
        AlertStatus.active => ('In progress', Tone.alert, Icons.notifications_active_outlined),
        AlertStatus.pending => ('Pending', Tone.neutral, Icons.hourglass_top),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NabraAppBar(title: 'Event detail', initial: widget.viewer.initial),
      body: StreamBuilder<AlertEvent?>(
        stream: _alert,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
          final a = snap.data;
          if (a == null) {
            return const ResponsiveBody(children: [EmptyState(icon: Icons.search_off, title: 'Event not found')]);
          }
          _patient ??= a.patientUid == widget.viewer.uid
              ? Future.value(widget.viewer)
              : UserService.instance.get(a.patientUid);
          final (chip, tone, icon) = _statusChip(a);
          final v = a.vitals;
          return ResponsiveBody(children: [
            NabraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(Fmt.dateFull(a.startedAt)),
                  const Gap(AppSpacing.xs),
                  Text(a.title, style: AppText.headline),
                  if (!widget.viewer.isPatient) Text(a.patientName, style: AppText.small),
                  const Gap(AppSpacing.sm),
                  Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                    StatusChip(chip, tone: tone, icon: icon),
                    if (a.duration != null && !a.isFalseAlarm)
                      StatusChip('Lasted ${Fmt.duration(a.duration!)}',
                          tone: a.duration! >= AppConstants.longSeizure ? Tone.alert : Tone.neutral,
                          icon: Icons.timer_outlined),
                  ]),
                ],
              ),
            ),
            NabraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Timeline'),
                  RowList(rows: [
                    for (final t in a.timeline)
                      ListRow(
                        leading: Dot(_kindColor(t.kind)),
                        title: t.label,
                        subtitle: Fmt.timeSec(t.at),
                        trailing: Text(Fmt.offset(t.at.difference(a.startedAt)), style: AppText.caption),
                      ),
                  ]),
                ],
              ),
            ),
            TileGrid(minTileWidth: AppSizes.choiceTileMinWidth, maxColumns: 3, children: [
              if (v.peakHr != null) _stat('Peak HR', '${v.peakHr!.round()} bpm'),
              if (v.minSpo2 != null) _stat('Min SpO2', '${v.minSpo2!.round()}%'),
              if (v.minHrv != null) _stat('Min HRV', '${v.minHrv!.round()} ms'),
              if (v.peakResp != null) _stat('Breathing', '${v.peakResp!.round()}/min'),
              _stat('Confidence', a.confidence.toStringAsFixed(2)),
              if (a.responderName != null) _stat('Responder', a.responderName!),
            ]),
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
            if (a.location != null)
              NabraButton.ghost(
                label: 'View location on map',
                icon: Icons.map_outlined,
                small: true,
                onPressed: () => ContactLauncher.openMap(a.location!.lat, a.location!.lng),
              ),
            FutureBuilder<AppUser?>(
              future: _patient,
              builder: (context, ps) {
                final p = ps.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: withGaps([
                    NabraButton.ghost(
                      label: 'Send summary to doctor',
                      icon: Icons.description_outlined,
                      onPressed: () => showSendReportSheet(
                        context,
                        viewer: widget.viewer,
                        patient: p,
                        subject: 'NABRA event report · ${a.patientName} · ${Fmt.dateShort(a.startedAt)}',
                        body: ReportService.event(a, p),
                      ),
                    ),
                    if (p != null && p.medical.doctorPhone.isNotEmpty)
                      NabraButton.ghost(
                        label: 'Call ${p.medical.doctorName.isEmpty ? 'doctor' : p.medical.doctorName}',
                        icon: Icons.phone_outlined,
                        small: true,
                        onPressed: () => ContactLauncher.call(p.medical.doctorPhone),
                      ),
                  ], AppSpacing.md),
                );
              },
            ),
          ]);
        },
      ),
    );
  }

  Widget _stat(String label, String value) => NabraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const Gap(AppSpacing.xs),
            Text(value, style: AppText.bodyStrong),
          ],
        ),
      );
}
