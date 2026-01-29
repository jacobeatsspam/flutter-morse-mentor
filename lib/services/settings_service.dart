import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings
class SettingsService extends ChangeNotifier {
  static const String _wpmKey = 'words_per_minute';
  static const String _volumeKey = 'volume';
  static const String _hapticKey = 'haptic_feedback';
  static const String _toneFrequencyKey = 'tone_frequency';
  static const String _farnsworthCharWpmKey = 'farnsworth_character_wpm';

  SharedPreferences? _prefs;

  // Default values
  int _wordsPerMinute = 15;
  double _volume = 0.7;
  bool _hapticFeedback = true;
  int _toneFrequency = 700;
  int _farnsworthWpm = 25; // Character speed for Farnsworth playback

  // Getters
  int get wordsPerMinute => _wordsPerMinute;
  double get volume => _volume;
  bool get hapticFeedback => _hapticFeedback;
  int get toneFrequency => _toneFrequency;
  int get farnsworthWpm => _farnsworthWpm;

  /// Initialize settings from persistent storage
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    _wordsPerMinute = _prefs?.getInt(_wpmKey) ?? 15;
    _volume = _prefs?.getDouble(_volumeKey) ?? 0.7;
    _hapticFeedback = _prefs?.getBool(_hapticKey) ?? true;
    _toneFrequency = _prefs?.getInt(_toneFrequencyKey) ?? 700;
    _farnsworthWpm = _prefs?.getInt(_farnsworthCharWpmKey) ?? 25;

    notifyListeners();
  }

  /// Set words per minute (5-40 WPM range)
  Future<void> setWordsPerMinute(int wpm) async {
    _wordsPerMinute = wpm.clamp(5, 40);
    await _prefs?.setInt(_wpmKey, _wordsPerMinute);
    notifyListeners();
  }

  /// Set audio volume (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _prefs?.setDouble(_volumeKey, _volume);
    notifyListeners();
  }

  /// Enable/disable haptic feedback
  Future<void> setHapticFeedback(bool enabled) async {
    _hapticFeedback = enabled;
    await _prefs?.setBool(_hapticKey, _hapticFeedback);
    notifyListeners();
  }

  /// Set tone frequency (400-1000 Hz)
  Future<void> setToneFrequency(int frequency) async {
    _toneFrequency = frequency.clamp(400, 1000);
    await _prefs?.setInt(_toneFrequencyKey, _toneFrequency);
    notifyListeners();
  }

  /// Set Farnsworth character speed (15-40 WPM)
  /// This is the speed at which characters are played when using Farnsworth timing.
  /// The gaps between characters use the standard WPM setting.
  Future<void> setfarnsworthWpm(int wpm) async {
    _farnsworthWpm = wpm.clamp(15, 40);
    await _prefs?.setInt(_farnsworthCharWpmKey, _farnsworthWpm);
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _wordsPerMinute = 15;
    _volume = 0.7;
    _hapticFeedback = true;
    _toneFrequency = 700;
    _farnsworthWpm = 25;

    await _prefs?.clear();
    notifyListeners();
  }
}
