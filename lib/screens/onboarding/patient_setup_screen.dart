import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../shared/alert_prefs_card.dart';
import '../shared/care_team_screen.dart';
import 'pairing_code_card.dart';

/// Blueprint "Pair & link": pair the collar, then link caregivers.
class PatientSetupScreen extends StatefulWidget {
  const PatientSetupScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<PatientSetupScreen> createState() => _PatientSetupScreenState();
}

class _PatientSetupScreenState extends State<PatientSetupScreen> {
  bool _finishing = false;

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      await UserService.instance.update(widget.user.uid, {'setupComplete': true});
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      appBar: NabraAppBar(title: 'Set up', initial: u.initial),
      body: ResponsiveBody(children: [
        Text('Welcome, ${u.firstName}', style: AppText.headline),
        Text('Three quick steps and you are protected.', style: AppText.small),
        PairCollarCard(user: u),
        PairingCodeCard(user: u, title: 'Step 2 · Link a caregiver'),
        AlertPrefsCard(user: u, title: 'Step 3 · Alert preferences'),
        NabraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('Optional · Your doctor'),
              const Gap(AppSpacing.xs),
              Text(
                u.medical.hasCareTeam
                    ? 'Care team saved: ${u.medical.doctorName.isEmpty ? u.medical.hospitalName : u.medical.doctorName}'
                    : 'Add your doctor or hospital so seizure timelines can be sent to them in one tap.',
                style: AppText.small,
              ),
              const Gap(AppSpacing.sm),
              NabraButton.ghost(
                small: true,
                icon: Icons.local_hospital_outlined,
                label: u.medical.hasCareTeam ? 'Edit care team' : 'Add care team',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => CareTeamScreen(uid: u.uid))),
              ),
            ],
          ),
        ),
        NabraButton(label: 'Done', loading: _finishing, onPressed: _finish),
      ]),
    );
  }
}

/// Step 1: pair the collar. Hardware BLE comes with the ESP32 build; until
/// then this pairs the simulated collar so the whole app can be demoed.
class PairCollarCard extends StatefulWidget {
  const PairCollarCard({super.key, required this.user});
  final AppUser user;
  @override
  State<PairCollarCard> createState() => _PairCollarCardState();
}

class _PairCollarCardState extends State<PairCollarCard> {
  bool _scanning = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _pair() async {
    setState(() => _busy = true);
    try {
      await UserService.instance.update(widget.user.uid, {'devicePaired': true, 'cushionArmed': true});
    } catch (e) {
      if (mounted) showSnack(context, 'Pairing failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paired = widget.user.devicePaired;
    return NabraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Step 1 · Pair the collar'),
          const Gap(AppSpacing.md - 2),
          Row(
            children: [
              const IconBox(Icons.shield_outlined),
              const Gap(AppSpacing.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_scanning && !paired ? 'Searching…' : AppConstants.deviceName, style: AppText.bodyStrong),
                    Text(
                      paired
                          ? 'Paired · monitoring ready'
                          : _scanning
                              ? 'Looking for your collar'
                              : 'Found (simulated collar, demo mode)',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              if (paired)
                const StatusChip('Paired', tone: Tone.ok, icon: Icons.check)
              else if (_scanning)
                const SizedBox(
                  width: AppSizes.icon,
                  height: AppSizes.icon,
                  child: CircularProgressIndicator(strokeWidth: AppSizes.sparkStroke),
                )
              else
                SizedBox(
                  width: AppSizes.inlineButtonWidth,
                  child: NabraButton(label: 'Pair', small: true, loading: _busy, onPressed: _pair),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
