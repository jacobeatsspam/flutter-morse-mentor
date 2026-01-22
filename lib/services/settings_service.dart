import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings
class SettingsService extends ChangeNotifier {
  static const String _wpmKey = 'words_per_minute';
  static const String _volumeKey = 'volume';
  static const String _hapticKey = 'haptic_feedback';
  static const String _toneFrequencyKey = 'tone_frequency';
  static const String _showHintsKey = 'show_hints';
  static const String _autoAdvanceKey = 'auto_advance';
  static const String _farnsworthKey = 'farnsworth_enabled';
  static const String _farnsworthWpmKey = 'farnsworth_wpm';

  SharedPreferences? _prefs;

  // Default values
  int _wordsPerMinute = 15;
  double _volume = 0.7;
  bool _hapticFeedback = true;
  int _toneFrequency = 700;
  bool _showHints = true;
  bool _autoAdvance = true;
  bool _farnsworthEnabled = false;
  int _farnsworthWpm = 5; // Character speed when Farnsworth is enabled

  // Getters
  int get wordsPerMinute => _wordsPerMinute;
  double get volume => _volume;
  bool get hapticFeedback => _hapticFeedback;
  int get toneFrequency => _toneFrequency;
  bool get showHints => _showHints;
  bool get autoAdvance => _autoAdvance;
  bool get farnsworthEnabled => _farnsworthEnabled;
  int get farnsworthWpm => _farnsworthWpm;

  /// Initialize settings from persistent storage
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    _wordsPerMinute = _prefs?.getInt(_wpmKey) ?? 15;
    _volume = _prefs?.getDouble(_volumeKey) ?? 0.7;
    _hapticFeedback = _prefs?.getBool(_hapticKey) ?? true;
    _toneFrequency = _prefs?.getInt(_toneFrequencyKey) ?? 700;
    _showHints = _prefs?.getBool(_showHintsKey) ?? true;
    _autoAdvance = _prefs?.getBool(_autoAdvanceKey) ?? true;
    _farnsworthEnabled = _prefs?.getBool(_farnsworthKey) ?? false;
    _farnsworthWpm = _prefs?.getInt(_farnsworthWpmKey) ?? 5;

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

  /// Enable/disable hint display
  Future<void> setShowHints(bool show) async {
    _showHints = show;
    await _prefs?.setBool(_showHintsKey, _showHints);
    notifyListeners();
  }

  /// Enable/disable auto-advance to next character
  Future<void> setAutoAdvance(bool enabled) async {
    _autoAdvance = enabled;
    await _prefs?.setBool(_autoAdvanceKey, _autoAdvance);
    notifyListeners();
  }

  /// Enable/disable Farnsworth timing
  /// Farnsworth method sends characters at a faster rate but with
  /// extra spacing between characters, helping learners recognize
  /// character patterns at higher speeds
  Future<void> setFarnsworthEnabled(bool enabled) async {
    _farnsworthEnabled = enabled;
    await _prefs?.setBool(_farnsworthKey, _farnsworthEnabled);
    notifyListeners();
  }

  /// Set Farnsworth character speed
  Future<void> setFarnsworthWpm(int wpm) async {
    _farnsworthWpm = wpm.clamp(5, 40);
    await _prefs?.setInt(_farnsworthWpmKey, _farnsworthWpm);
    notifyListeners();
  }

  /// Get the effective character WPM (for Farnsworth timing)
  int get effectiveCharacterWpm {
    if (_farnsworthEnabled && _farnsworthWpm > _wordsPerMinute) {
      return _farnsworthWpm;
    }
    return _wordsPerMinute;
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _wordsPerMinute = 15;
    _volume = 0.7;
    _hapticFeedback = true;
    _toneFrequency = 700;
    _showHints = true;
    _autoAdvance = true;
    _farnsworthEnabled = false;
    _farnsworthWpm = 5;

    await _prefs?.clear();
    notifyListeners();
  }
}
