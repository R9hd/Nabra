import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../auth/auth_gate.dart';

/// Patient's doctor / hospital contacts + optional medical profile.
/// Used to send seizure timelines and shown to linked caregivers.
class CareTeamScreen extends StatelessWidget {
  const CareTeamScreen({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context) =>
      UserBuilder(uid: uid, builder: (context, u) => _CareTeamForm(uid: uid, initial: u.medical));
}

class _CareTeamForm extends StatefulWidget {
  const _CareTeamForm({required this.uid, required this.initial});
  final String uid;
  final MedicalProfile initial;
  @override
  State<_CareTeamForm> createState() => _CareTeamFormState();
}

class _CareTeamFormState extends State<_CareTeamForm> {
  late final _c = {
    for (final e in widget.initial.toMap().entries) e.key: TextEditingController(text: e.value as String),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserService.instance.update(widget.uid, {
        'medicalProfile': {for (final e in _c.entries) e.key: e.value.text.trim()},
      });
      if (mounted) {
        showSnack(context, 'Saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _f(String key, String label, {TextInputType? type, String? hint}) => NabraField(
        label: label,
        controller: _c[key],
        keyboardType: type,
        hint: hint,
        textCapitalization: type == null ? TextCapitalization.sentences : TextCapitalization.none,
      );

  Widget _section(String title, List<Widget> fields) => NabraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: withGaps([SectionLabel(title), ...fields], AppSpacing.md),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NabraAppBar(title: 'Care team'),
      body: ResponsiveBody(children: [
        Text(
          'All optional. Shared only with your linked caregivers and in reports you choose to send.',
          style: AppText.small,
        ),
        _section('Doctor', [
          _f('doctorName', 'Name', hint: 'Dr. Ahmed Al-Harbi'),
          _f('doctorPhone', 'Phone (for SMS reports)', type: TextInputType.phone),
          _f('doctorEmail', 'Email', type: TextInputType.emailAddress),
        ]),
        _section('Hospital / clinic', [
          _f('hospitalName', 'Name', hint: 'King Fahad Hospital · Neurology'),
          _f('hospitalPhone', 'Phone', type: TextInputType.phone),
        ]),
        _section('Medical profile', [
          _f('seizureTypes', 'Seizure types', hint: 'e.g. tonic-clonic'),
          _f('medications', 'Medications', hint: 'e.g. levetiracetam 500mg x2'),
          _f('allergies', 'Allergies'),
          _f('bloodType', 'Blood type', hint: 'e.g. O+'),
        ]),
        NabraButton(label: 'Save', loading: _saving, onPressed: _save),
      ]),
    );
  }
}
