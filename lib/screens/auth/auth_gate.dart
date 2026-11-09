import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../ui.dart';
import '../caregiver/caregiver_shell.dart';
import '../onboarding/link_patient_screen.dart';
import '../onboarding/patient_setup_screen.dart';
import '../patient/patient_shell.dart';
import 'auth_screen.dart';

/// Decides what to show: sign in, onboarding, or the role's home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView());
        }
        final user = snap.data;
        if (user == null) return const AuthScreen();
        return _Session(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _Session extends StatefulWidget {
  const _Session({super.key, required this.uid});
  final String uid;
  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  late final Stream<AppUser?> _user = UserService.instance.watch(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _user,
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (snap.hasError)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('Could not load your profile.\n${snap.error}',
                          textAlign: TextAlign.center, style: AppText.small),
                    )
                  else
                    const CircularProgressIndicator(),
                  const Gap(AppSpacing.lg),
                  TextButton(onPressed: AuthService.instance.signOut, child: const Text('Sign out')),
                ],
              ),
            ),
          );
        }
        if (user.isPatient) {
          return user.setupComplete ? PatientShell(user: user) : PatientSetupScreen(user: user);
        }
        return user.setupComplete ? CaregiverShell(user: user) : LinkPatientScreen(user: user, onboarding: true);
      },
    );
  }
}

/// Streams a user doc for pushed screens that need fresh data.
class UserBuilder extends StatefulWidget {
  const UserBuilder({super.key, required this.uid, required this.builder});
  final String uid;
  final Widget Function(BuildContext context, AppUser user) builder;
  @override
  State<UserBuilder> createState() => _UserBuilderState();
}

class _UserBuilderState extends State<UserBuilder> {
  late final Stream<AppUser?> _stream = UserService.instance.watch(widget.uid);
  @override
  Widget build(BuildContext context) => StreamBuilder<AppUser?>(
        stream: _stream,
        builder: (context, s) => s.data == null ? const Scaffold(body: LoadingView()) : widget.builder(context, s.data!),
      );
}
