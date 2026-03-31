import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'settings_controller.dart';

class TimerCues {
  TimerCues(this.settings);

  final SettingsController settings;
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRateForStyle(settings.voiceStyle));
    await _tts.setPitch(_pitchForGender(settings.voiceGender));
    await _tts.setVolume(settings.voiceVolume);
    _configured = true;
  }

  Future<void> playWarning(int secondsLeft) async {
    if (settings.audioMode == 'off') return;
    if (settings.audioMode == 'voice' || settings.audioMode == 'both') {
      await _ensureConfigured();
      await _tts.speak('$secondsLeft seconds');
    }
    if (settings.audioMode == 'beep' || settings.audioMode == 'both') {
      _playBeep();
    }
  }

  Future<void> playStart() async {
    if (settings.audioMode == 'off') return;
    if (settings.audioMode == 'voice' || settings.audioMode == 'both') {
      await _ensureConfigured();
      await _tts.speak('Go');
    }
    if (settings.audioMode == 'beep' || settings.audioMode == 'both') {
      _playBeep(strong: true);
    }
  }

  Future<void> playRestComplete() async {
    if (settings.audioMode == 'off') return;
    if (settings.audioMode == 'voice' || settings.audioMode == 'both') {
      await _ensureConfigured();
      await _tts.speak('Rest complete');
    }
    if (settings.audioMode == 'beep' || settings.audioMode == 'both') {
      _playBeep(strong: true);
    }
  }

  void _playBeep({bool strong = false}) {
    final tone = settings.beepTone;
    final style = settings.beepStyle;
    final useAlert = strong || style == 'sharp' || tone == 'high';
    SystemSound.play(useAlert ? SystemSoundType.alert : SystemSoundType.click);
  }

  double _speechRateForStyle(String style) {
    switch (style) {
      case 'calm':
        return 0.42;
      case 'energetic':
        return 0.6;
      default:
        return 0.5;
    }
  }

  double _pitchForGender(String gender) {
    switch (gender) {
      case 'male':
        return 0.9;
      case 'female':
        return 1.1;
      default:
        return 1.0;
    }
  }
}
