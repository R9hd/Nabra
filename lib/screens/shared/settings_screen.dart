import '../../models/app_user.dart';
import '../../services/alarm_service.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/emergency_caller.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import 'alert_prefs_card.dart';
import 'care_team_screen.dart';
import 'legal_screen.dart';
import 'linked_people_screen.dart';
import 'thresholds_screen.dart';

/// Blueprint "Settings".
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _sensitivity;

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _editProfile() async {
    final u = widget.user;
    final name = TextEditingController(text: u.name);
    final phone = TextEditingController(text: u.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: withGaps([
            NabraField(label: 'Full name', controller: name, textCapitalization: TextCapitalization.words),
            NabraField(label: 'Phone number', controller: phone, keyboardType: TextInputType.phone),
          ], AppSpacing.md),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await UserService.instance.update(u.uid, {'name': name.text.trim(), 'phone': phone.text.trim()});
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _signOut() async {
    DeviceService.instance.stop();
    await AlarmService.instance.stopAll();
    await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    const chevron = Icon(Icons.chevron_right, color: AppColors.muted);
    return Scaffold(
      appBar: NabraAppBar(title: 'Settings', initial: u.initial),
      body: ResponsiveBody(children: [
        NabraCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card),
          child: RowList(rows: [
            ListRow(
              leading: const IconBox(Icons.person_outline),
              title: u.name,
              subtitle: '${u.role.label} · edit profile',
              trailing: chevron,
              onTap: _editProfile,
            ),
            if (u.isPatient)
              ListRow(
                leading: const IconBox(Icons.local_hospital_outlined),
                title: 'Medical profile & care team',
                subtitle: u.medical.hasCareTeam
                    ? (u.medical.doctorName.isEmpty ? u.medical.hospitalName : u.medical.doctorName)
                    : 'Add your doctor or hospital',
                trailing: chevron,
                onTap: () => _push(CareTeamScreen(uid: u.uid)),
              ),
            ListRow(
              leading: const IconBox(Icons.link),
              title: u.isPatient
                  ? 'Linked caregivers (${u.linkedCaregiverIds.length})'
                  : 'My patients (${u.linkedPatientIds.length})',
              subtitle: u.isPatient ? 'Pairing code, manage links' : 'Link or remove people',
              trailing: chevron,
              onTap: () => _push(LinkedPeopleScreen(uid: u.uid)),
            ),
            if (u.isPatient)
              ListRow(
                leading: const IconBox(Icons.tune),
                title: 'Alert thresholds',
                subtitle: 'Dangerous HR, SpO2, HRV and breathing limits',
                trailing: chevron,
                onTap: () => _push(ThresholdsScreen(uid: u.uid)),
              ),
          ]),
        ),
        if (u.isPatient) _deviceCard(u),
        AlertPrefsCard(user: u),
        if (u.isPatient) _autoCallCard(u),
        NabraCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card),
          child: RowList(rows: [
            for (final d in LegalDoc.values)
              ListRow(
                leading: IconBox(d.icon, color: AppColors.muted),
                title: d.title,
                trailing: chevron,
                onTap: () => _push(LegalScreen(doc: d)),
              ),
          ]),
        ),
        NabraButton.ghost(label: 'Sign out', icon: Icons.logout, small: true, onPressed: _signOut),
        Text('${AppConstants.appName} · terms v${AppConstants.termsVersion}',
            style: AppText.caption, textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _deviceCard(AppUser u) {
    final device = DeviceService.instance;
    final value = _sensitivity ?? u.sensitivity;
    return ListenableBuilder(
      listenable: device,
      builder: (context, _) => NabraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Device · ${AppConstants.deviceName}'),
            const Gap(AppSpacing.sm),
            if (!u.devicePaired)
              NabraButton(
                label: 'Pair collar',
                small: true,
                icon: Icons.bluetooth_searching,
                onPressed: () => UserService.instance.update(u.uid, {'devicePaired': true, 'cushionArmed': true}),
              )
            else ...[
              Row(children: [
                Expanded(child: _kv('Battery', '${device.battery.round()}%')),
                Expanded(child: _kv('Cushion', device.cushionArmed ? 'Ready' : 'Repack')),
                Expanded(child: _kv('Status', device.running ? 'Connected' : 'Off')),
              ]),
              const Gap(AppSpacing.md),
              Row(
                children: [
                  const Expanded(child: SectionLabel('Sensitivity')),
                  Text(value < 0.34 ? 'Fewer alarms' : value < 0.67 ? 'Balanced' : 'Most sensitive',
                      style: AppText.caption.copyWith(color: AppColors.cyan)),
                ],
              ),
              Slider(
                value: value,
                onChanged: (v) => setState(() => _sensitivity = v),
                onChangeEnd: (v) => UserService.instance.update(u.uid, {'sensitivity': v}),
              ),
              Text(
                'Higher catches events sooner but may raise more false alarms. '
                'Every cancelled alert is logged and counted in Statistics.',
                style: AppText.caption,
              ),
              const Gap(AppSpacing.md),
              if (!device.cushionArmed) ...[
                NabraButton.ghost(
                  label: 'Mark cushion repacked',
                  small: true,
                  onPressed: () {
                    device.configure(cushionArmed: true);
                    UserService.instance.update(u.uid, {'cushionArmed': true});
                  },
                ),
                const Gap(AppSpacing.sm),
              ],
              NabraButton.ghost(
                label: 'Unpair collar',
                small: true,
                icon: Icons.link_off,
                onPressed: () => UserService.instance.update(u.uid, {'devicePaired': false}),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editAutoCallNumber(AppUser u) async {
    final c = TextEditingController(text: u.autoCallNumber);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Number to call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: withGaps([
            NabraField(label: 'Phone number', controller: c, keyboardType: TextInputType.phone),
            Text(
              "For testing, use a teammate's number. Never test with ${AppConstants.emergencyNumber}.",
              style: AppText.caption.copyWith(color: AppColors.warn),
            ),
          ], AppSpacing.md),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final n = c.text.trim();
      await UserService.instance.update(u.uid, {'autoCallNumber': n.isEmpty ? AppConstants.emergencyNumber : n});
    }
    c.dispose();
  }

  Widget _autoCallCard(AppUser u) {
    final emergency = EmergencyCaller.isEmergencyNumber(u.autoCallNumber);
    return NabraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(child: SectionLabel('Emergency auto-call')),
            Switch(
              value: u.autoCallEnabled,
              activeColor: AppColors.cyan,
              onChanged: (v) => UserService.instance.update(u.uid, {'autoCallEnabled': v}),
            ),
          ]),
          Text(
            'If nobody responds within ${AppConstants.autoCallAfter.inMinutes} minutes of a detected seizure, '
            'this phone calls for help automatically.',
            style: AppText.small,
          ),
          const Gap(AppSpacing.sm),
          ListRow(
            divider: false,
            leading: const IconBox(Icons.call_outlined),
            title: u.autoCallNumber,
            subtitle: emergency
                ? 'Emergency line: the dialer opens with the number ready, one tap to call'
                : 'Called directly on Android, no tap needed',
            trailing: const Icon(Icons.edit_outlined, color: AppColors.muted),
            onTap: () => _editAutoCallNumber(u),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(k, style: AppText.caption), Text(v, style: AppText.bodyStrong)],
      );
}
