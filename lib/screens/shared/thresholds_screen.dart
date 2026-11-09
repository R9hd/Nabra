import '../../models/thresholds.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../auth/auth_gate.dart';

/// The patient's normal range per vital. Leaving it for a few seconds triggers the alarm.
class ThresholdsScreen extends StatelessWidget {
  const ThresholdsScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) =>
      UserBuilder(uid: uid, builder: (context, u) => _ThresholdsForm(uid: uid, initial: u.thresholds));
}

class _ThresholdsForm extends StatefulWidget {
  const _ThresholdsForm({required this.uid, required this.initial});
  final String uid;
  final VitalThresholds initial;
  @override
  State<_ThresholdsForm> createState() => _ThresholdsFormState();
}

class _Spec {
  const _Spec(this.label, this.unit, this.min, this.max, this.help, this.get, this.set);
  final String label;
  final String unit;
  final double min;
  final double max;
  final String help;
  final double Function(VitalThresholds) get;
  final VitalThresholds Function(VitalThresholds, double) set;
}

class _ThresholdsFormState extends State<_ThresholdsForm> {
  late VitalThresholds _t = widget.initial;
  bool _saving = false;

  static final _specs = [
    _Spec('Heart rate · upper limit', 'bpm', 80, 180, 'Usual adult range 60-100 bpm. Alarm when it stays above this.',
        (t) => t.hrHigh, (t, v) => t.copyWith(hrHigh: v)),
    _Spec('Heart rate · lower limit', 'bpm', 30, 80, 'Alarm when heart rate stays below this.', (t) => t.hrLow,
        (t, v) => t.copyWith(hrLow: v)),
    _Spec('SpO2 · lower limit', '%', 80, 98, 'Usual range 95-100%. Alarm when blood oxygen stays below this.',
        (t) => t.spo2Low, (t, v) => t.copyWith(spo2Low: v)),
    _Spec('HRV · lower limit', 'ms', 5, 60, 'Usual range 20-100+ ms. A sharp HRV drop often accompanies seizures.',
        (t) => t.hrvLow, (t, v) => t.copyWith(hrvLow: v)),
    _Spec('Breathing · upper limit', '/min', 20, 40, 'Fast breathing limit.', (t) => t.respHigh,
        (t, v) => t.copyWith(respHigh: v)),
    _Spec('Breathing · lower limit', '/min', 4, 12, 'Slow breathing / apnea limit, important after a seizure.',
        (t) => t.respLow, (t, v) => t.copyWith(respLow: v)),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserService.instance.update(widget.uid, {'thresholds': _t.toMap()});
      if (mounted) {
        showSnack(context, 'Thresholds saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NabraAppBar(title: 'Alert thresholds'),
      body: ResponsiveBody(children: [
        Text(
          'These are your normal ranges. If a reading stays outside them for 5 seconds, NABRA raises an alarm '
          'and, unless you cancel, alerts your caregivers just like a detected seizure. Normal differs with age, '
          'fitness and medication, so agree your limits with your doctor.',
          style: AppText.small,
        ),
        for (final s in _specs)
          NabraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: SectionLabel(s.label)),
                  Text('${s.get(_t).round()} ${s.unit}', style: AppText.bodyStrong.copyWith(color: AppColors.cyan)),
                ]),
                Slider(
                  value: s.get(_t).clamp(s.min, s.max),
                  min: s.min,
                  max: s.max,
                  divisions: (s.max - s.min).round(),
                  label: '${s.get(_t).round()}',
                  onChanged: (v) => setState(() => _t = s.set(_t, v.roundToDouble())),
                ),
                Text(s.help, style: AppText.caption),
              ],
            ),
          ),
        NabraButton(label: 'Save thresholds', loading: _saving, onPressed: _save),
        NabraButton.ghost(
          label: 'Reset to usual adult ranges',
          small: true,
          onPressed: () => setState(() => _t = const VitalThresholds()),
        ),
      ]),
    );
  }
}
