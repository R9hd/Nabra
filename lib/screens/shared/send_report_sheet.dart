import '../../models/app_user.dart';
import '../../services/contact_launcher.dart';
import '../../ui.dart';
import 'care_team_screen.dart';

/// Sends a report to the patient's doctor / hospital by SMS, email, or copy.
/// Hospitals don't share a system, so we use the channels they all have.
Future<void> showSendReportSheet(
  BuildContext context, {
  required AppUser viewer,
  required AppUser? patient,
  required String subject,
  required String body,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
        child: _SendSheet(viewer: viewer, patient: patient, subject: subject, body: body),
      ),
    ),
  );
}

class _SendSheet extends StatelessWidget {
  const _SendSheet({required this.viewer, required this.patient, required this.subject, required this.body});
  final AppUser viewer;
  final AppUser? patient;
  final String subject;
  final String body;

  @override
  Widget build(BuildContext context) {
    final m = patient?.medical;
    final doctor = (m?.doctorName.isNotEmpty ?? false) ? m!.doctorName : 'doctor';
    final hospital = (m?.hospitalName.isNotEmpty ?? false) ? m!.hospitalName : 'hospital';
    Future<void> run(Future<bool> Function() f) async {
      final ok = await f();
      if (!ok && context.mounted) showSnack(context, 'No app available for this on this device.');
    }

    final rows = <ListRow>[
      if (m != null && m.doctorPhone.isNotEmpty)
        ListRow(
          leading: const IconBox(Icons.sms_outlined),
          title: 'Text $doctor',
          subtitle: m.doctorPhone,
          onTap: () => run(() => ContactLauncher.sms(m.doctorPhone, body)),
        ),
      if (m != null && m.doctorEmail.isNotEmpty)
        ListRow(
          leading: const IconBox(Icons.email_outlined),
          title: 'Email $doctor',
          subtitle: m.doctorEmail,
          onTap: () => run(() => ContactLauncher.email(m.doctorEmail, subject: subject, body: body)),
        ),
      if (m != null && m.hospitalPhone.isNotEmpty)
        ListRow(
          leading: const IconBox(Icons.local_hospital_outlined),
          title: 'Text $hospital',
          subtitle: m.hospitalPhone,
          onTap: () => run(() => ContactLauncher.sms(m.hospitalPhone, body)),
        ),
      ListRow(
        leading: const IconBox(Icons.copy),
        title: 'Copy report',
        subtitle: 'Paste into WhatsApp, a hospital portal, or anywhere',
        onTap: () async {
          await ContactLauncher.copy(body);
          if (context.mounted) {
            Navigator.of(context).pop();
            showSnack(context, 'Report copied');
          }
        },
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(context.rs.gutter, 0, context.rs.gutter, AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: withGaps([
              Text('Send to doctor', style: AppText.title),
              if (m == null || !m.hasCareTeam)
                NabraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('No doctor or hospital saved yet.', style: AppText.bodyStrong),
                      const Gap(AppSpacing.xs),
                      Text(
                        viewer.isPatient
                            ? 'Add their phone or email once to send reports in one tap.'
                            : 'Ask ${patient?.firstName ?? 'the patient'} to add their care team in Settings. You can still copy the report.',
                        style: AppText.small,
                      ),
                      if (viewer.isPatient) ...[
                        const Gap(AppSpacing.sm),
                        NabraButton.ghost(
                          label: 'Add care team',
                          small: true,
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => CareTeamScreen(uid: viewer.uid)));
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              NabraCard(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card), child: RowList(rows: rows)),
              const SectionLabel('Preview'),
              NabraCard(
                color: AppColors.bg,
                child: SelectableText(body, style: AppText.mono.copyWith(height: 1.5)),
              ),
            ], AppSpacing.md),
          ),
        ),
      ),
    );
  }
}
