import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_progress.dart';
import '../core/constants/morse_code.dart';

/// Service for tracking and persisting user progress
class ProgressService extends ChangeNotifier {
  static const String _progressBoxName = 'user_progress_json';
  static const String _characterProgressBoxName = 'character_progress_json';
  static const String _sessionsBoxName = 'practice_sessions_json';

  // Using dynamic boxes to store JSON maps instead of typed objects
  // This avoids the need for Hive TypeAdapters
  Box<dynamic>? _progressBox;
  Box<dynamic>? _characterBox;
  Box<dynamic>? _sessionsBox;

  UserProgress? _userProgress;
  final Map<String, CharacterProgress> _characterProgress = {};

  bool _isInitialized = false;

  UserProgress get progress => _userProgress ?? UserProgress();
  Map<String, CharacterProgress> get characterProgress => _characterProgress;
  bool get isInitialized => _isInitialized;

  /// Initialize the progress service and load saved data
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Open boxes for JSON storage (no TypeAdapters needed)
    _progressBox = await Hive.openBox<dynamic>(_progressBoxName);
    _characterBox = await Hive.openBox<dynamic>(_characterProgressBoxName);
    _sessionsBox = await Hive.openBox<dynamic>(_sessionsBoxName);

    // Load existing progress from JSON
    final progressJson = _progressBox?.get('current');
    if (progressJson != null && progressJson is Map) {
      _userProgress = UserProgress.fromJson(Map<String, dynamic>.from(progressJson));
    } else {
      _userProgress = UserProgress();
    }

    // Load character progress from JSON
    _characterBox?.keys.forEach((key) {
      final cpJson = _characterBox?.get(key);
      if (cpJson != null && cpJson is Map) {
        final cp = CharacterProgress.fromJson(Map<String, dynamic>.from(cpJson));
        _characterProgress[cp.character] = cp;
      }
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// Get progress for a specific character
  CharacterProgress getCharacterProgress(String character) {
    return _characterProgress[character.toUpperCase()] ??
        CharacterProgress(character: character.toUpperCase());
  }

  /// Record an attempt for a character
  Future<void> recordAttempt(String character, bool correct) async {
    final char = character.toUpperCase();
    
    if (!_characterProgress.containsKey(char)) {
      _characterProgress[char] = CharacterProgress(character: char);
    }

    _characterProgress[char]!.recordAttempt(correct);

    if (correct) {
      _userProgress?.totalCharactersSent++;
    }

    await _saveProgress();
    notifyListeners();
  }

  /// Start a new practice session
  PracticeSession startSession(String sessionType) {
    return PracticeSession(
      startTime: DateTime.now(),
      sessionType: sessionType,
    );
  }

  /// Complete a practice session
  Future<void> completeSession(PracticeSession session) async {
    session.endTime = DateTime.now();

    _userProgress?.totalSessionsCompleted++;
    _userProgress?.totalPracticeTime += session.durationSeconds;
    _userProgress?.updateDailyStreak();

    // Save session as JSON
    await _sessionsBox?.add(session.toJson());
    await _saveProgress();
    notifyListeners();
  }

  /// Get the characters the user should focus on
  List<String> getWeakCharacters({int limit = 5}) {
    final entries = _characterProgress.entries.toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));

    return entries
        .where((e) => e.value.totalAttempts >= 3 && !e.value.mastered)
        .take(limit)
        .map((e) => e.key)
        .toList();
  }

  /// Get mastered characters
  List<String> getMasteredCharacters() {
    return _characterProgress.entries
        .where((e) => e.value.mastered)
        .map((e) => e.key)
        .toList();
  }

  /// Get characters available at current level
  List<String> getAvailableCharacters() {
    final level = _userProgress?.currentLevel ?? 1;
    return learningOrder
        .where((c) => c.difficulty <= level)
        .map((c) => c.character)
        .toList();
  }

  /// Check if user can advance to next level
  bool canAdvanceLevel() {
    final currentLevelChars = learningOrder
        .where((c) => c.difficulty == (_userProgress?.currentLevel ?? 1))
        .map((c) => c.character)
        .toList();

    // Need 80%+ mastery of current level characters
    int masteredCount = 0;
    for (final char in currentLevelChars) {
      if (_characterProgress[char]?.mastered ?? false) {
        masteredCount++;
      }
    }

    return masteredCount >= (currentLevelChars.length * 0.8);
  }

  /// Advance to the next level
  Future<void> advanceLevel() async {
    if (canAdvanceLevel() && (_userProgress?.currentLevel ?? 1) < 5) {
      _userProgress?.currentLevel++;
      await _saveProgress();
      notifyListeners();
    }
  }

  /// Update WPM setting
  Future<void> setWordsPerMinute(int wpm) async {
    _userProgress?.wordsPerMinute = wpm.clamp(5, 40);
    await _saveProgress();
    notifyListeners();
  }

  /// Get overall accuracy
  double getOverallAccuracy() {
    if (_characterProgress.isEmpty) return 0.0;

    int totalCorrect = 0;
    int totalAttempts = 0;

    for (final cp in _characterProgress.values) {
      totalCorrect += cp.correctCount;
      totalAttempts += cp.correctCount + cp.incorrectCount;
    }

    if (totalAttempts == 0) return 0.0;
    return totalCorrect / totalAttempts;
  }

  /// Get practice statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalPracticeTime': _userProgress?.totalPracticeTime ?? 0,
      'sessionsCompleted': _userProgress?.totalSessionsCompleted ?? 0,
      'currentStreak': _userProgress?.currentStreak ?? 0,
      'bestStreak': _userProgress?.bestStreak ?? 0,
      'currentLevel': _userProgress?.currentLevel ?? 1,
      'wordsPerMinute': _userProgress?.wordsPerMinute ?? 5,
      'charactersMastered': getMasteredCharacters().length,
      'totalCharacters': learningOrder.length,
      'overallAccuracy': getOverallAccuracy(),
    };
  }

  /// Reset all progress
  Future<void> resetProgress() async {
    _userProgress = UserProgress();
    _characterProgress.clear();

    await _progressBox?.clear();
    await _characterBox?.clear();
    await _sessionsBox?.clear();

    await _saveProgress();
    notifyListeners();
  }

  Future<void> _saveProgress() async {
    // Save as JSON maps instead of typed objects
    await _progressBox?.put('current', _userProgress!.toJson());
    
    for (final entry in _characterProgress.entries) {
      await _characterBox?.put(entry.key, entry.value.toJson());
    }
  }

  int get totalAttempts {
    int total = 0;
    for (final cp in _characterProgress.values) {
      total += cp.correctCount + cp.incorrectCount;
    }
    return total;
  }
}
