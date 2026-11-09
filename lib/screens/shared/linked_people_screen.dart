import '../../models/app_user.dart';
import '../../services/contact_launcher.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../auth/auth_gate.dart';
import '../onboarding/link_patient_screen.dart';
import '../onboarding/pairing_code_card.dart';

/// Patient: pairing code + caregivers. Caregiver: their patients.
class LinkedPeopleScreen extends StatelessWidget {
  const LinkedPeopleScreen({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) => UserBuilder(uid: uid, builder: (context, u) => _LinkedPeople(user: u));
}

class _LinkedPeople extends StatefulWidget {
  const _LinkedPeople({required this.user});
  final AppUser user;
  @override
  State<_LinkedPeople> createState() => _LinkedPeopleState();
}

class _LinkedPeopleState extends State<_LinkedPeople> {
  late final Stream<List<AppUser>> _people = widget.user.isPatient
      ? UserService.instance.linkedCaregivers(widget.user.uid)
      : UserService.instance.linkedPatients(widget.user.uid);

  Future<void> _unlink(AppUser other) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${other.firstName}?'),
        content: Text(widget.user.isPatient
            ? '${other.firstName} will stop receiving your alerts.'
            : 'You will stop receiving ${other.firstName}\'s alerts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: AppText.bodyStrong.copyWith(color: AppColors.alert)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final u = widget.user;
    try {
      await UserService.instance.unlink(
        patientUid: u.isPatient ? u.uid : other.uid,
        caregiverUid: u.isPatient ? other.uid : u.uid,
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Could not remove: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: NabraAppBar(title: u.isPatient ? 'Linked caregivers' : 'My patients'),
      body: StreamBuilder<List<AppUser>>(
        stream: _people,
        builder: (context, snap) {
          final people = snap.data ?? const <AppUser>[];
          return ResponsiveBody(children: [
            if (u.isPatient) PairingCodeCard(user: u, title: 'Add a caregiver'),
            if (!snap.hasData)
              const LoadingView()
            else if (people.isEmpty)
              EmptyState(
                icon: Icons.group_outlined,
                title: u.isPatient ? 'No caregivers yet' : 'No patients yet',
                body: u.isPatient ? 'Share your code above.' : 'Link a person with their pairing code.',
              )
            else
              NabraCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card),
                child: RowList(rows: [
                  for (final p in people)
                    ListRow(
                      leading: Avatar(p.initial),
                      title: p.name,
                      subtitle: p.phone.isEmpty ? p.role.label : '${p.role.label} · ${p.phone}',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p.phone.isNotEmpty)
                            IconButton(
                              tooltip: 'Call',
                              icon: const Icon(Icons.phone_outlined, color: AppColors.cyan),
                              onPressed: () => ContactLauncher.call(p.phone),
                            ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.link_off, color: AppColors.muted),
                            onPressed: () => _unlink(p),
                          ),
                        ],
                      ),
                    ),
                ]),
              ),
            if (!u.isPatient)
              NabraButton.ghost(
                label: 'Link a person',
                icon: Icons.person_add_alt,
                small: true,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => LinkPatientScreen(user: u))),
              ),
          ]);
        },
      ),
    );
  }
}
