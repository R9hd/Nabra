// Automatic two-phone demo tour of NABRA: the patient and the caregiver side by side.
//
// Two emulators run this same file at the same time. tool/demo_tour.ps1 tells each phone its
// role (patient or caregiver), a shared run number and the mode, by writing files/tour.txt into
// the app. The phones then follow each other through the real app and real Firebase: the patient
// signs up and pairs, the caregiver signs up and links, the patient has a false alarm and then a
// seizure, the caregiver's phone rings, they respond and end it, and both see the history.
// Nobody needs to touch either phone.
//
// Modes:
//  * video (default): smooth pacing for a screen recording, no screenshots.
//  * shots: also saves a screenshot of every page to demo/screenshots/
//    (p = patient phone, c = caregiver phone). Screenshots slow the phone down, so
//    don't record a video in this mode.
//
// Run it with:  tool/demo_tour.ps1   (see README "Demo tour")
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nabra/main.dart' as app;
import 'package:nabra/services/auth_service.dart';
import 'package:nabra/services/user_service.dart';

/// How long the viewer sees each page. Raise these for a slower video.
const _look = Duration(milliseconds: 2500);

/// Pause after a tap (lets the page transition finish).
const _beat = Duration(milliseconds: 900);

/// Delay between typed letters.
const _keystroke = Duration(milliseconds: 45);

/// Longest time one phone waits for the other.
const _otherPhone = Duration(minutes: 6);

const _password = 'nabra123';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NABRA demo tour', (tester) async {
    // ---------- role ----------
    final roleFile = File('/data/user/0/com.example.nabra/files/tour.txt');
    if (!roleFile.existsSync()) {
      throw TestFailure('No role file. Start the tour with tool/demo_tour.ps1, not flutter drive.');
    }
    final parts = roleFile.readAsStringSync().trim().split(RegExp(r'\s+'));
    final isPatient = parts[0] == 'patient';
    final run = parts[1];
    final shots = parts.length > 2 && parts[2] == 'shots';
    // Each phone signs up its own account and never signs in to the other one.
    final patientEmail = 'sara.demo.$run@example.com';
    final caregiverEmail = 'omar.demo.$run@example.com';
    var shot = 0;

    // ---------- helpers ----------
    Future<void> wait(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        await tester.pump();
      }
    }

    Future<void> waitFor(Finder f, {Duration timeout = const Duration(seconds: 30)}) async {
      final end = DateTime.now().add(timeout);
      while (f.evaluate().isEmpty) {
        if (DateTime.now().isAfter(end)) throw TestFailure('Timed out waiting for $f');
        await wait(const Duration(milliseconds: 200));
      }
    }

    Future<void> waitGone(Finder f, {Duration timeout = const Duration(seconds: 30)}) async {
      final end = DateTime.now().add(timeout);
      while (f.evaluate().isNotEmpty) {
        if (DateTime.now().isAfter(end)) throw TestFailure('Timed out waiting for $f to go away');
        await wait(const Duration(milliseconds: 200));
      }
    }

    /// Let the viewer look at the page (and save a screenshot in shots mode).
    Future<void> look(String name) async {
      if (shots) {
        await wait(const Duration(milliseconds: 700)); // let animations finish
        shot++;
        await binding.takeScreenshot('${isPatient ? 'p' : 'c'}${shot.toString().padLeft(2, '0')}_$name');
      }
      await wait(_look);
    }

    /// A message bar ("Saved", "Linked to…") can cover buttons at the bottom.
    void hideSnack(Finder f) => ScaffoldMessenger.maybeOf(tester.element(f.first))?.removeCurrentSnackBar();

    Future<void> tap(Finder f) async {
      await waitFor(f);
      hideSnack(f);
      await tester.ensureVisible(f.first);
      await wait(const Duration(milliseconds: 250));
      await tester.tap(f.first, warnIfMissed: false);
      await wait(_beat);
    }

    Future<void> tapText(String text) => tap(find.text(text));

    /// Bottom navigation (the nav label is the last matching text on screen).
    Future<void> nav(String label) async {
      await waitFor(find.text(label));
      hideSnack(find.text(label));
      await tester.tap(find.text(label).last, warnIfMissed: false);
      await wait(_beat);
    }

    /// Types into a field letter by letter, like a person (instant in shots mode).
    Future<void> typeInto(Finder f, String value) async {
      await waitFor(f);
      await tester.ensureVisible(f.first);
      if (shots) {
        await tester.enterText(f.first, value);
      } else {
        for (var i = 1; i <= value.length; i++) {
          await tester.enterText(f.first, value.substring(0, i));
          await wait(_keystroke);
        }
      }
      await wait(const Duration(milliseconds: 300));
    }

    Future<void> type(String label, String value) => typeInto(find.widgetWithText(TextFormField, label), value);

    void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

    Future<void> back() async {
      await tester.pageBack();
      await wait(_beat);
    }

    void backToShell() =>
        tester.state<NavigatorState>(find.byType(Navigator).first).popUntil((r) => r.isFirst);

    /// Scroll the current page down smoothly (to show the rest of it).
    Future<void> scrollDown() async {
      final s = find.byType(Scrollable);
      if (s.evaluate().isEmpty) return;
      await tester.timedDrag(s.first, const Offset(0, -900), const Duration(milliseconds: 1200), warnIfMissed: false);
      await wait(_beat);
    }

    Future<void> signOut() async {
      await nav('Settings');
      await tap(find.text('Sign out'));
      await waitFor(find.text('Continue'));
    }

    Future<void> signUp({required String name, required String email, required String phone}) async {
      await tapText('Sign up');
      await tapText(isPatient ? 'Patient' : 'Caregiver');
      await type('Full name', name);
      await type('Email', email);
      await type('Phone number', phone);
      await type('Password', _password);
      await type('Confirm password', _password);
      hideKeyboard();
      await tap(find.byType(Checkbox));
      await look('signup');
      await tapText('Create account');
    }

    /// The caregiver needs the patient's pairing code (in real life the patient reads it out).
    /// The patient phone saves it to files/code.txt and tool/demo_tour.ps1 copies that file
    /// to the caregiver phone.
    final codeFile = File('${roleFile.parent.path}/code.txt');

    Future<String> patientPairingCode() async {
      final end = DateTime.now().add(_otherPhone);
      while (DateTime.now().isBefore(end)) {
        if (codeFile.existsSync()) {
          final code = codeFile.readAsStringSync().trim();
          if (code.isNotEmpty) return code;
        }
        await wait(const Duration(seconds: 1));
      }
      throw TestFailure('The patient phone never paired.');
    }

    // ---------- start ----------
    // Typing goes straight into the fields, so the on-screen keyboard never pops up.
    tester.testTextInput.register();
    await app.main();
    await wait(const Duration(seconds: 3));
    if (AuthService.instance.currentUser != null) {
      await AuthService.instance.signOut();
      await wait(const Duration(seconds: 2));
    }
    if (shots) {
      await binding.convertFlutterSurfaceToImage(); // needed for screenshots on Android
      await wait(const Duration(seconds: 1));
    }
    await waitFor(find.text('Continue'));
    await look('login');

    if (isPatient) {
      // ========== Patient phone ==========
      // 1. Sign up, pair the collar, alert preferences, care team.
      await signUp(name: 'Sara Ahmed', email: patientEmail, phone: '0551234567');
      await waitFor(find.text('Welcome, Sara'));
      await look('setup');
      await tapText('Pair');
      await waitFor(find.text('Paired'));
      // Hand the pairing code to the caregiver phone (see patientPairingCode).
      final uid = AuthService.instance.currentUser!.uid;
      String? code;
      for (var i = 0; i < 50 && code == null; i++) {
        code = (await UserService.instance.get(uid))?.pairingCode;
        if (code == null) await wait(const Duration(milliseconds: 300));
      }
      codeFile.writeAsStringSync(code ?? '');
      await look('setup_paired');
      await scrollDown();
      await look('setup_alert_preferences');
      await tapText('Add care team');
      await waitFor(find.text('Care team'));
      await type('Name', 'Dr. Ahmed Al-Harbi');
      await type('Phone (for SMS reports)', '0559876543');
      await type('Seizure types', 'Tonic-clonic');
      await type('Medications', 'Levetiracetam 500mg x2');
      hideKeyboard();
      await look('care_team');
      await tapText('Save');
      await tapText('Done');

      // 2. Pages, while the caregiver links on the other phone.
      await waitFor(find.text('Live view'));
      await look('home');
      await nav('Monitor');
      await look('live_monitor');
      if (shots) {
        await nav('History');
        await look('history_empty');
        await nav('Statistics');
        await look('statistics_empty');
      }
      await nav('Settings');
      await look('settings');
      await tap(find.textContaining('Linked caregivers'));
      await waitFor(find.text('Omar Ahmed'), timeout: _otherPhone); // caregiver has linked
      await look('linked_caregivers');
      await back();
      await tapText('Alert thresholds');
      await look('thresholds');
      await scrollDown();
      await wait(_look);
      await back();
      if (shots) {
        await scrollDown();
        await look('settings_bottom');
        for (final doc in ['Terms of Use', 'Privacy Policy', 'Medical disclaimer']) {
          await tapText(doc);
          await look('legal_${doc.split(' ').first.toLowerCase()}');
          await back();
        }
      }

      // 3. A false alarm: cancelled in time, the caregiver is never bothered.
      await nav('Monitor');
      await tapText('Simulate low SpO2 (demo)');
      await waitFor(find.text('Alerting your caregivers'), timeout: const Duration(seconds: 60));
      await look('alert_low_spo2');
      await tapText("I'm OK · Cancel");
      await wait(_look);

      // 4. A real seizure: the countdown runs out and the caregivers are alerted.
      await tapText('Simulate seizure (demo)');
      await waitFor(find.text('Alerting your caregivers'), timeout: const Duration(seconds: 60));
      if (shots) {
        await wait(const Duration(seconds: 2));
        await look('seizure_alert');
        await tapText('Send now');
      }
      await waitFor(find.text('Seizure in progress'), timeout: const Duration(seconds: 40));
      await look('seizure_timer');
      await waitFor(find.textContaining('is responding'), timeout: _otherPhone);
      await look('caregiver_responding');
      await waitGone(find.text('Seizure in progress'), timeout: _otherPhone); // caregiver ended it
      await wait(_beat);

      // 5. Afterwards: history, event detail, report, statistics.
      await nav('Home');
      await look('home_after');
      await nav('History');
      await look('history');
      await tap(find.textContaining('caregiver responded'));
      await waitFor(find.text('Event detail'));
      await look('event_detail');
      await scrollDown();
      await look('event_detail_bottom');
      await tapText('Send summary to doctor');
      await look('send_report');
      await tester.tapAt(const Offset(20, 60)); // close the sheet
      await wait(_beat);
      await back();
      await nav('Statistics');
      await look('statistics');
      await scrollDown();
      await look('statistics_middle');
      await scrollDown();
      await look('statistics_bottom');
      await signOut();
    } else {
      // ========== Caregiver phone ==========
      // 1. Sign up and link to the patient with her pairing code.
      await signUp(name: 'Omar Ahmed', email: caregiverEmail, phone: '0557654321');
      await waitFor(find.text('Welcome, Omar'));
      await look('setup');
      final code = await patientPairingCode();
      await typeInto(find.byType(TextField).last, code);
      hideKeyboard();
      await wait(_beat);
      await tap(find.text('Link').last);
      await waitFor(find.text('My people'));
      await look('home');
      if (shots) {
        await nav('Settings');
        await look('settings');
        await nav('People');
      }

      // 2. Watches Sara's live vitals until her seizure alert opens by itself.
      await tapText('Sara Ahmed');
      await look('patient_detail');
      await waitFor(find.text('Emergency'), timeout: _otherPhone);
      await wait(const Duration(seconds: 2));
      await look('incoming_alert');
      await scrollDown();
      await look('incoming_alert_bottom');
      await tapText("I'm responding");
      await waitFor(find.text("You're responding"));
      await look('responding'); // Sara's phone now shows "Omar is responding"
      await tapText('Seizure ended');
      await wait(const Duration(seconds: 3));
      await look('alert_ended');
      backToShell();
      await wait(_beat);

      // 3. Afterwards: history and statistics.
      await nav('History');
      await look('history');
      await nav('Statistics');
      await look('statistics');
      await scrollDown();
      await look('statistics_bottom');
      await nav('People');
      await signOut();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
