import '../../ui.dart';

enum LegalDoc {
  terms('Terms of Use', Icons.gavel_outlined),
  privacy('Privacy Policy', Icons.privacy_tip_outlined),
  disclaimer('Medical disclaimer', Icons.health_and_safety_outlined);

  const LegalDoc(this.title, this.icon);
  final String title;
  final IconData icon;
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final LegalDoc doc;

  static const _updated = 'November 2026';

  static const Map<LegalDoc, List<(String, String)>> _content = {
    LegalDoc.terms: [
      (
        'About NABRA',
        'NABRA is a student prototype developed for the MEDATHON hackathon (Saudi Youth Healthcare Forum). '
            'It pairs a wearable collar with this app to detect signs of seizure onset, alert linked caregivers and '
            'keep an event history. By creating an account you agree to these terms.'
      ),
      (
        'Not a medical device',
        'NABRA is not a certified medical device and has not been cleared by the SFDA or any regulator. It does '
            'not diagnose, treat, predict or prevent seizures or SUDEP. Never rely on it as your only safety measure. '
            'In an emergency call ${AppConstants.emergencyNumber}.'
      ),
      (
        'Your account',
        'You are responsible for keeping your login details safe and for the accuracy of the information you add, '
            'including emergency and doctor contacts. You must be 18 or older, or use NABRA with a parent or guardian.'
      ),
      (
        'Caregivers',
        'Patients choose who receives their alerts by sharing a pairing code, and can remove a caregiver at any '
            'time. Caregivers agree to use patient information only to help that patient.'
      ),
      (
        'Alerts and availability',
        'Alerts depend on the collar, the phone, battery, internet connection and third-party services such as '
            'Firebase. Alerts may be delayed or fail. Detection can miss events or raise false alarms.'
      ),
      (
        'Liability',
        'To the extent allowed by law, the NABRA team is not liable for harm arising from missed, delayed or false '
            'alerts, or from decisions made using the app\'s insights.'
      ),
      ('Changes', 'We may update these terms. Material changes will be shown in the app before they apply.'),
    ],
    LegalDoc.privacy: [
      (
        'What we collect',
        'Account: name, email, phone and role. Health: biosignals from the collar (heart rate, HRV, SpO2, breathing, '
            'motion), seizure and alert events, and location at the moment of an alert. Optional: medical profile '
            'and doctor / hospital contacts. Passwords are handled by Firebase Authentication and never stored by us.'
      ),
      (
        'Why',
        'To detect events, alert your caregivers with your location, keep your history, generate insights and let '
            'you send reports to your doctor. We collect only what these features need, and medical fields are optional.'
      ),
      (
        'Who can see it',
        'Only you and the caregivers you link. Reports go to a doctor or hospital only when you (or your caregiver) '
            'choose to send them. We do not sell data or use it for advertising.'
      ),
      (
        'Where it is stored',
        'In Google Firebase (Authentication and Cloud Firestore), protected by security rules that limit access to '
            'the patient and linked caregivers. Statistics are calculated on your device.'
      ),
      (
        'Your rights',
        'You can view and edit your data in the app, remove caregivers at any time, and ask the NABRA team to '
            'export or delete your account and data. We aim to follow Saudi Arabia\'s Personal Data Protection Law (PDPL).'
      ),
      (
        'Demo data',
        'During the hackathon, use test accounts and fake medical data only. Do not enter a real person\'s medical details.'
      ),
    ],
    LegalDoc.disclaimer: [
      (
        'Educational use only',
        'Readings, risk scores and insights are estimates from a prototype and are not a diagnosis. Do not change '
            'medication or treatment based on the app. Talk to your doctor.'
      ),
      (
        'In an emergency',
        'Call ${AppConstants.emergencyNumber}. A seizure lasting more than 5 '
            'minutes, repeated seizures without recovery, breathing difficulty, injury, or a seizure in water are '
            'medical emergencies.'
      ),
      (
        'Scope of the device',
        'NABRA aims to protect the head and neck faster by triggering on seizure physiology. It does not predict '
            'seizures before they start and does not prevent SUDEP.'
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NabraAppBar(title: doc.title),
      body: ResponsiveBody(children: [
        Text('Version ${AppConstants.termsVersion} · updated $_updated', style: AppText.caption),
        for (final (title, body) in _content[doc]!)
          NabraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                const Gap(AppSpacing.xs),
                Text(body, style: AppText.body.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
      ]),
    );
  }
}
