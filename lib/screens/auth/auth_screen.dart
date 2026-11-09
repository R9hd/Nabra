import 'package:flutter/gestures.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../ui.dart';
import '../shared/legal_screen.dart';

/// Blueprint "Sign in": Log in / Sign up toggle, role choice on sign up.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginKey = GlobalKey<FormState>();
  final _signupKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int _tab = 0; // 0 = log in, 1 = sign up
  UserRole _role = UserRole.patient;
  bool _accepted = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- validation ----
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  String? _vEmail(String? v) => _emailRe.hasMatch((v ?? '').trim()) ? null : 'Enter a valid email';
  String? _vPassword(String? v) => (v ?? '').length >= 6 ? null : 'At least 6 characters';
  String? _vName(String? v) => (v ?? '').trim().length >= 2 ? null : 'Enter your full name';
  String? _vPhone(String? v) =>
      (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length >= 9 ? null : 'Enter a valid phone number';
  String? _vConfirm(String? v) => v == _password.text ? null : 'Passwords do not match';

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) showSnack(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _login() {
    if (!_loginKey.currentState!.validate()) return;
    _run(() => AuthService.instance.signIn(email: _email.text, password: _password.text));
  }

  void _signup() {
    if (!_signupKey.currentState!.validate()) return;
    if (!_accepted) {
      showSnack(context, 'Please accept the Terms of Use and Privacy Policy to continue.');
      return;
    }
    _run(() => AuthService.instance.signUp(
          name: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
          role: _role,
        ));
  }

  Future<void> _forgot() async {
    if (_vEmail(_email.text) != null) {
      showSnack(context, 'Type your email above first, then tap "Forgot password?".');
      return;
    }
    await _run(() async {
      await AuthService.instance.resetPassword(_email.text);
      if (mounted) showSnack(context, 'Password reset link sent to ${_email.text.trim()}.');
    });
  }

  void _startSignupAs(UserRole role) => setState(() {
        _tab = 1;
        _role = role;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NabraAppBar(title: AppConstants.appName),
      body: SafeArea(
        top: false,
        child: AutofillGroup(
          child: ResponsiveBody(
            maxWidth: AppSizes.narrowContentWidth,
            children: [
              const Gap(AppSpacing.sm),
              const SectionLabel(AppConstants.tagline, color: AppColors.cyan, textAlign: TextAlign.center),
              Segmented(options: const ['Log in', 'Sign up'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _tab == 0 ? _loginForm() : _signupForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Form(
      key: _loginKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: withGaps([
          NabraField(
            label: 'Email',
            controller: _email,
            hint: 'sara@email.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: _vEmail,
          ),
          NabraField(
            label: 'Password',
            controller: _password,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            validator: _vPassword,
            onSubmitted: (_) => _login(),
          ),
          NabraButton(label: 'Continue', loading: _busy, onPressed: _login),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _forgot,
              child: Text('Forgot password?', style: AppText.small),
            ),
          ),
          NabraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('On sign up you pick a role'),
                const Gap(AppSpacing.sm),
                Row(
                  children: withGaps([
                    for (final r in UserRole.values)
                      Expanded(
                        child: InkWell(
                          borderRadius: AppRadius.pillAll,
                          onTap: () => _startSignupAs(r),
                          child: Center(child: StatusChip(r.label, icon: Icons.person_outline)),
                        ),
                      ),
                  ], AppSpacing.md - 2),
                ),
              ],
            ),
          ),
        ], AppSpacing.md),
      ),
    );
  }

  Widget _signupForm() {
    return Form(
      key: _signupKey,
      child: Column(
        key: const ValueKey('signup'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: withGaps([
          const SectionLabel('I am a'),
          TileGrid(
            minTileWidth: AppSizes.choiceTileMinWidth,
            children: [
              ChoiceTile(
                icon: Icons.favorite_border,
                title: UserRole.patient.label,
                subtitle: 'I wear the NABRA collar',
                selected: _role == UserRole.patient,
                onTap: () => setState(() => _role = UserRole.patient),
              ),
              ChoiceTile(
                icon: Icons.volunteer_activism_outlined,
                title: UserRole.caregiver.label,
                subtitle: 'I look after someone',
                selected: _role == UserRole.caregiver,
                onTap: () => setState(() => _role = UserRole.caregiver),
              ),
            ],
          ),
          NabraField(
            label: 'Full name',
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            validator: _vName,
          ),
          NabraField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: _vEmail,
          ),
          NabraField(
            label: 'Phone number',
            controller: _phone,
            hint: '05XXXXXXXX',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: _vPhone,
          ),
          NabraField(
            label: 'Password',
            controller: _password,
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: _vPassword,
          ),
          NabraField(
            label: 'Confirm password',
            controller: _confirm,
            obscure: true,
            textInputAction: TextInputAction.done,
            validator: _vConfirm,
          ),
          _termsCheckbox(),
          NabraButton(label: 'Create account', loading: _busy, onPressed: _signup),
        ], AppSpacing.md),
      ),
    );
  }

  Widget _termsCheckbox() {
    TapGestureRecognizer link(LegalDoc doc) => TapGestureRecognizer()
      ..onTap = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(doc: doc)));
    final linkStyle = AppText.small.copyWith(color: AppColors.cyan, decoration: TextDecoration.underline);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text.rich(
              TextSpan(style: AppText.small, children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(text: 'Terms of Use', style: linkStyle, recognizer: link(LegalDoc.terms)),
                const TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: link(LegalDoc.privacy)),
                const TextSpan(text: ', and understand NABRA is not a certified medical device ('),
                TextSpan(text: 'disclaimer', style: linkStyle, recognizer: link(LegalDoc.disclaimer)),
                const TextSpan(text: ').'),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
