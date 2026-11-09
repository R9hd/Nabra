import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../shared/alert_prefs_card.dart';

/// Caregiver enters a patient's pairing code.
class LinkPatientScreen extends StatefulWidget {
  const LinkPatientScreen({super.key, required this.user, this.onboarding = false});
  final AppUser user;
  final bool onboarding;
  @override
  State<LinkPatientScreen> createState() => _LinkPatientScreenState();
}

class _LinkPatientScreenState extends State<LinkPatientScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    setState(() => _busy = true);
    try {
      final name = await UserService.instance.linkWithCode(widget.user, _code.text);
      if (!mounted) return;
      showSnack(context, 'Linked to $name. You will receive their alerts.');
      if (!widget.onboarding) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, e is LinkException ? e.message : AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() => UserService.instance.update(widget.user.uid, {'setupComplete': true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NabraAppBar(title: widget.onboarding ? 'Set up' : 'Link a person', initial: widget.user.initial),
      body: ResponsiveBody(children: [
        if (widget.onboarding) ...[
          Text('Welcome, ${widget.user.firstName}', style: AppText.headline),
          Text('Link the person you care for to receive their alerts.', style: AppText.small),
          AlertPrefsCard(user: widget.user, title: 'Step 1 · Alert preferences'),
        ],
        NabraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: withGaps([
              SectionLabel(widget.onboarding ? 'Step 2 · Enter their pairing code' : 'Enter their pairing code'),
              TextField(
                controller: _code,
                textAlign: TextAlign.center,
                maxLength: AppConstants.pairingCodeLength,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
                ],
                style: AppText.code,
                decoration: const InputDecoration(hintText: '7K2P9', counterText: ''),
                onSubmitted: (_) => _link(),
              ),
              Text(
                'The patient finds this code in their NABRA app under Settings → Linked caregivers.',
                style: AppText.small,
                textAlign: TextAlign.center,
              ),
              NabraButton(label: 'Link', icon: Icons.link, loading: _busy, onPressed: _link),
            ], AppSpacing.md),
          ),
        ),
        if (widget.onboarding) ...[
          Center(child: TextButton(onPressed: _skip, child: const Text('Skip for now'))),
          Center(
            child: TextButton(
              onPressed: AuthService.instance.signOut,
              child: Text('Sign out', style: AppText.small),
            ),
          ),
        ],
      ]),
    );
  }
}
