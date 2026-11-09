import '../../models/app_user.dart';
import '../../services/contact_launcher.dart';
import '../../services/user_service.dart';
import '../../ui.dart';

/// Shows the patient's caregiver pairing code (creates one if missing).
class PairingCodeCard extends StatefulWidget {
  const PairingCodeCard({super.key, required this.user, this.title = 'Link a caregiver'});
  final AppUser user;
  final String title;
  @override
  State<PairingCodeCard> createState() => _PairingCodeCardState();
}

class _PairingCodeCardState extends State<PairingCodeCard> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.user.pairingCode == null) _generate();
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      await UserService.instance.generatePairingCode(widget.user);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not create a code: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.user.pairingCode;
    return NabraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(widget.title),
          const Gap(AppSpacing.md),
          const SectionLabel('Your pairing code', textAlign: TextAlign.center),
          const Gap(AppSpacing.xs),
          Center(
            child: code == null || _busy
                ? const Padding(padding: EdgeInsets.all(AppSpacing.sm), child: CircularProgressIndicator())
                : SelectableText(code, style: AppText.code),
          ),
          const Gap(AppSpacing.sm),
          Text(
            'Your caregiver enters this code in their app to receive your alerts.',
            style: AppText.small,
            textAlign: TextAlign.center,
          ),
          const Gap(AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: code == null
                    ? null
                    : () {
                        ContactLauncher.copy(code);
                        showSnack(context, 'Code copied');
                      },
                icon: const Icon(Icons.copy, size: AppSizes.iconSm),
                label: const Text('Copy'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _generate,
                icon: const Icon(Icons.refresh, size: AppSizes.iconSm),
                label: const Text('New code'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
