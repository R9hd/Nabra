# NABRA app

Flutter + Firebase app for the NABRA seizure-protection collar (hackathon prototype, not a certified medical device).

## Try it

- **Android:** download `NABRA.apk` from the latest [Release](../../releases/latest) and open it on your phone.
- **iPhone / laptop:** open the web version: `https://r9hd.github.io/Nabra/`
  (lock-screen alerts, background alarm sound and automatic calls work only in the Android app).
- Step-by-step test instructions are in [RELEASE_NOTES.md](RELEASE_NOTES.md). Screenshots of every page are in
  [demo/screenshots](demo/screenshots).

## Run

```bash
flutter pub get
flutter run
```

One-time Firebase setup (console → project `nabradb-e874e`):
1. **Authentication** → enable **Email/Password**.
2. **Firestore** → create the database, then deploy the rules: `firebase deploy --only firestore:rules`.

No composite indexes are needed (lists are sorted on the device).

## Demo script (two phones, or phone + web)

1. Sign up a **patient** → pair the (simulated) collar → note the 5-letter pairing code.
2. Sign up a **caregiver** on another device → enter the code.
3. Patient: **Monitor → Simulate seizure (demo)**. The collar detects a heart-rate surge + convulsive motion,
   the cushion "deploys", and the 10-second cancel window starts.
4. Let it run out (or tap *Send now*). The patient phone switches to the **seizure timer** (5-minute emergency mark,
   first aid). The caregiver phone opens the **incoming alert** with timer, location and *I'm responding / Call 997*.
5. Mark **Seizure ended** → the event appears in **History** (with the patient's name on the caregiver side),
   **Event detail** shows the timeline, and **Statistics** updates.
6. **Simulate low SpO2** shows the dangerous-vitals alarm (limits are set in *Settings → Alert thresholds*).
7. *Settings → Medical profile & care team*: add a doctor. Then *History → Send seizure log to doctor* (SMS / email / copy).

## Structure

```
lib/
  core/       design tokens (colors, spacing, radius, sizes, text), theme, responsive helper, constants
  models/     AppUser, Vitals, AlertEvent, VitalThresholds
  services/   auth, users & pairing, device (simulated collar + detection), alerts, location,
              insights engine, doctor reports, contact launcher
  widgets/    shared UI matching the blueprint (cards, chips, buttons, fields, charts, shell)
  screens/    auth, onboarding, patient, caregiver, shared
integration_test/  automatic demo tour (drives the app, takes screenshots)
test_driver/       saves the tour's screenshots to demo/screenshots/
tool/              demo_tour.ps1 (one-click tour runner)
```

All colors, spacing, radii and sizes come from `lib/core/`. Screens don't hardcode them.
Layouts cap content width on tablets/web, switch to a navigation rail on wide screens,
and tiles reflow into fewer columns on small phones.

## What's simulated / next

- **Collar**: `DeviceService` simulates HR, HRV, SpO2, breathing and motion. Swap `_generate()` for BLE samples
  from the ESP32 (`flutter_blue_plus`); detection, alarms and sync stay the same.
- **Caregiver alerts** arrive in real time while the caregiver app is open (Firestore listener).
  Background push needs FCM + a Cloud Function (Blaze plan).
- **Statistics** are plain counts calculated on the phone (seizures per week and month, seizure-free days, time of day, durations, vitals during
  events, false alarms, response time). No AI: KSA privacy rules don't allow sending patient data to a third party.
- **Alert thresholds** default to usual adult ranges (HR 60-100 bpm, SpO2 95-100%, HRV 20+ ms) and each patient
  can change them (Settings → Alert thresholds). A reading outside the range for 5 s raises the alarm.

## Demo tour (automatic, hands-off)

Drives the real app on an Android emulator or phone: signs up a patient and a caregiver, links them,
triggers a false alarm and a seizure, the caregiver responds and ends it, then visits every page.
It saves a screenshot of every page to `demo/screenshots/` (about 40 images, about 6 minutes).

```powershell
powershell -ExecutionPolicy Bypass -File tool/demo_tour.ps1
```

It needs two emulators open side by side (left = first one = patient, right = caregiver): in Android
Studio's Device Manager create a second device, untick *Settings → Tools → Emulator → Launch in the
Running Devices tool window* so each opens in its own window, and start both.

For a video, start a screen recording of the emulator window when it prints "Starting the tour"
(Windows: Snipping Tool, Win+Shift+R). Keep the emulator open and don't touch it until it prints "Done".
Each run creates two new demo accounts in Firebase (`*.demo.*@example.com`).

## Publishing (GitHub Actions)

- **Web demo:** every push to `main` builds the web app and publishes it on GitHub Pages
  (`.github/workflows/web.yml`). One-time setup: repo **Settings → Pages → Source: GitHub Actions**.
- **APK release:** push a tag (`git tag v1.0.0` then `git push origin v1.0.0`). The APK is built and attached to a
  GitHub Release with [RELEASE_NOTES.md](RELEASE_NOTES.md) (`.github/workflows/release.yml`).
