import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static const _goalLevelKey = 'goal_level';
  static const _goalTypeKey = 'goal_type';
  static const _equipmentAccessKey = 'equipment_access';
  static const _audioModeKey = 'audio_mode';
  static const _voiceStyleKey = 'voice_style';
  static const _voiceGenderKey = 'voice_gender';
  static const _voiceVolumeKey = 'voice_volume';
  static const _beepStyleKey = 'beep_style';
  static const _beepToneKey = 'beep_tone';
  static const _beepVolumeKey = 'beep_volume';

  String goalLevel = 'beginner';
  String goalType = 'strength';
  String equipmentAccess = 'full_gym';

  String audioMode = 'both'; // off, voice, beep, both
  String voiceStyle = 'coach';
  String voiceGender = 'female';
  double voiceVolume = 0.9;

  String beepStyle = 'soft';
  String beepTone = 'mid';
  double beepVolume = 0.9;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    goalLevel = prefs.getString(_goalLevelKey) ?? goalLevel;
    goalType = prefs.getString(_goalTypeKey) ?? goalType;
    equipmentAccess = prefs.getString(_equipmentAccessKey) ?? equipmentAccess;
    audioMode = prefs.getString(_audioModeKey) ?? audioMode;
    voiceStyle = prefs.getString(_voiceStyleKey) ?? voiceStyle;
    voiceGender = prefs.getString(_voiceGenderKey) ?? voiceGender;
    voiceVolume = prefs.getDouble(_voiceVolumeKey) ?? voiceVolume;
    beepStyle = prefs.getString(_beepStyleKey) ?? beepStyle;
    beepTone = prefs.getString(_beepToneKey) ?? beepTone;
    beepVolume = prefs.getDouble(_beepVolumeKey) ?? beepVolume;
    notifyListeners();
  }

  Future<void> updateGoalLevel(String value) async {
    goalLevel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalLevelKey, value);
    notifyListeners();
  }

  Future<void> updateGoalType(String value) async {
    goalType = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goalTypeKey, value);
    notifyListeners();
  }

  Future<void> updateEquipmentAccess(String value) async {
    equipmentAccess = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_equipmentAccessKey, value);
    notifyListeners();
  }

  Future<void> updateAudioMode(String value) async {
    audioMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioModeKey, value);
    notifyListeners();
  }

  Future<void> updateVoiceStyle(String value) async {
    voiceStyle = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceStyleKey, value);
    notifyListeners();
  }

  Future<void> updateVoiceGender(String value) async {
    voiceGender = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceGenderKey, value);
    notifyListeners();
  }

  Future<void> updateVoiceVolume(double value) async {
    voiceVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_voiceVolumeKey, value);
    notifyListeners();
  }

  Future<void> updateBeepStyle(String value) async {
    beepStyle = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_beepStyleKey, value);
    notifyListeners();
  }

  Future<void> updateBeepTone(String value) async {
    beepTone = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_beepToneKey, value);
    notifyListeners();
  }

  Future<void> updateBeepVolume(double value) async {
    beepVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_beepVolumeKey, value);
    notifyListeners();
  }
}
