import '../../models/app_user.dart';
import '../../services/alarm_service.dart';
import '../../services/alert_notifications.dart';
import '../../services/user_service.dart';
import '../../ui.dart';

/// Push the user's alert choices into the alarm + notification services.
void applyAlertPrefs(AppUser u) {
  AlarmService.instance.enabled = u.alarmSound;
  if (!u.alarmSound) AlarmService.instance.stopAll();
  AlertNotifications.privateMode = !u.lockScreenDetails;
}

/// Alarm sound + lock-screen details. Asked during setup and editable in Settings.
class AlertPrefsCard extends StatelessWidget {
  const AlertPrefsCard({super.key, required this.user, this.title = 'Alert preferences'});
  final AppUser user;
  final String title;

  static const muteDisclaimer =
      'With the alarm sound off, NABRA only vibrates and shows a notification. '
      'You, or the people around you, may not notice an alert in time. '
      'NABRA is not responsible for alerts missed because the sound was turned off.';

  Future<void> _setSound(BuildContext context, bool on) async {
    if (!on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Turn the alarm sound off?'),
          content: Text(muteDisclaimer, style: AppText.small),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep sound on')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('I understand, turn off', style: TextStyle(color: AppColors.alert)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await UserService.instance.update(user.uid, {'alarmSound': on});
  }

  Widget _switchRow({
    required String label,
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.bodyStrong),
                const Gap(AppSpacing.xxs),
                Text(text, style: AppText.caption),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          Switch(value: value, activeColor: AppColors.cyan, onChanged: onChanged),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final u = user;
    final who = u.isPatient ? 'people near you' : 'you';
    return NabraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          const Gap(AppSpacing.md),
          _switchRow(
            label: 'Alarm sound',
            text: 'A loud repeating alarm during an alert, even when the phone is on silent, '
                'so $who notice it.',
            value: u.alarmSound,
            onChanged: (v) => _setSound(context, v),
          ),
          if (!u.alarmSound) ...[
            const Gap(AppSpacing.sm),
            Text(muteDisclaimer, style: AppText.caption.copyWith(color: AppColors.warn)),
          ],
          const Gap(AppSpacing.md),
          _switchRow(
            label: 'Show details on the lock screen',
            text: u.lockScreenDetails
                ? 'On: the alert, timer and first-aid steps appear over the lock screen, '
                    'so anyone nearby can help. They also see that it is a seizure alert.'
                : 'Off: the lock screen shows only "NABRA alert" with no health details. '
                    'Nearby people will not see first-aid steps until the phone is unlocked.',
            value: u.lockScreenDetails,
            onChanged: (v) => UserService.instance.update(u.uid, {'lockScreenDetails': v}),
          ),
        ],
      ),
    );
  }
}
