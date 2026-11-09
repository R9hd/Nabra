import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Loud looping alarm sound during an alert, on the patient and caregiver phones.
///
/// * Android: plays on the ALARM volume, so it sounds even when the ringer is silent.
/// * iOS: plays even with the silent switch on, and keeps playing in the
///   background (UIBackgroundModes: audio in Info.plist).
/// * Works while the app is open or in the background. A fully closed caregiver
///   app can't ring (needs push from a server: Phase 2).
///
/// Several alerts can be live at once, so each caller starts/stops with its own
/// key (e.g. the alert id) and the sound plays while at least one key is active.
/// The sound is a steady two-tone beep. The screen never flashes with it.
class AlarmService {
  AlarmService._();
  static final instance = AlarmService._();

  static const _asset = 'sounds/alarm.wav';

  /// Key used by the patient's own phone.
  static const patientKey = 'patient';

  AudioPlayer? _player;
  final _active = <String>{};

  /// The user's choice (Settings / setup). Off = vibration + notification only.
  bool enabled = true;

  bool get playing => _active.isNotEmpty;

  AudioPlayer get _p => _player ??= AudioPlayer(playerId: 'nabra_alarm');

  Future<void> start(String key) async {
    if (!enabled || _active.contains(key)) return;
    final first = _active.isEmpty;
    _active.add(key);
    if (!first) return;
    try {
      await _p.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          // No audio focus: otherwise the alert notification's own sound takes focus and
          // the player pauses the alarm a split second after it starts.
          audioFocus: AndroidAudioFocus.none,
          stayAwake: true,
          isSpeakerphoneOn: false,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
      await _p.setReleaseMode(ReleaseMode.loop);
      await _p.setVolume(1);
      await _p.play(AssetSource(_asset));
    } catch (e) {
      debugPrint('Alarm sound failed: $e');
    }
  }

  Future<void> stop(String key) async {
    if (!_active.remove(key) || _active.isNotEmpty) return;
    await _silence();
  }

  /// Stop every alarm (e.g. before a phone call, or when the user mutes).
  Future<void> stopAll() async {
    _active.clear();
    await _silence();
  }

  Future<void> _silence() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
