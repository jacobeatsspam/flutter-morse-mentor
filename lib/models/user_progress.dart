/// Tracks learning progress for a single character
class CharacterProgress {
  final String character;
  int correctCount;  // All-time correct (for stats)
  int incorrectCount;  // All-time incorrect (for stats)
  int streak;
  int bestStreak;
  DateTime? lastPracticed;
  bool mastered;
  
  /// Recent attempts for calculating accuracy (sliding window)
  /// true = correct, false = incorrect
  /// Only the last [windowSize] attempts are kept
  List<bool> recentAttempts;
  
  /// Size of the sliding window for accuracy calculation
  static const int windowSize = 15;

  CharacterProgress({
    required this.character,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastPracticed,
    this.mastered = false,
    List<bool>? recentAttempts,
  }) : recentAttempts = recentAttempts ?? [];

  int get totalAttempts => correctCount + incorrectCount;

  /// Accuracy based on recent attempts only (sliding window)
  /// This allows users to recover from early mistakes
  double get accuracy {
    if (recentAttempts.isEmpty) return 0.0;
    final correct = recentAttempts.where((a) => a).length;
    return correct / recentAttempts.length;
  }
  
  /// Number of correct attempts in the recent window
  int get recentCorrect => recentAttempts.where((a) => a).length;

  /// A character is considered mastered after:
  /// - At least [windowSize] attempts in the window
  /// - 90%+ accuracy in recent attempts
  bool get shouldBeMastered => 
      recentAttempts.length >= windowSize && accuracy >= 0.9;

  void recordAttempt(bool correct) {
    // Update all-time counts
    if (correct) {
      correctCount++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      incorrectCount++;
      streak = 0;
    }
    
    // Update sliding window
    recentAttempts.add(correct);
    if (recentAttempts.length > windowSize) {
      recentAttempts.removeAt(0);  // Remove oldest
    }
    
    lastPracticed = DateTime.now();
    mastered = shouldBeMastered;
  }

  Map<String, dynamic> toJson() => {
        'character': character,
        'correctCount': correctCount,
        'incorrectCount': incorrectCount,
        'streak': streak,
        'bestStreak': bestStreak,
        'lastPracticed': lastPracticed?.toIso8601String(),
        'mastered': mastered,
        'recentAttempts': recentAttempts,
      };

  factory CharacterProgress.fromJson(Map<String, dynamic> json) {
    return CharacterProgress(
      character: json['character'] as String,
      correctCount: json['correctCount'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      lastPracticed: json['lastPracticed'] != null
          ? DateTime.parse(json['lastPracticed'] as String)
          : null,
      mastered: json['mastered'] as bool? ?? false,
      recentAttempts: (json['recentAttempts'] as List<dynamic>?)
          ?.cast<bool>() ?? [],
    );
  }
}

/// Overall user progress and statistics
class UserProgress {
  int currentLevel;
  int totalPracticeTime; // in seconds
  int totalSessionsCompleted;
  int currentStreak; // days in a row practiced
  int bestStreak; // best daily streak
  DateTime? lastPracticeDate;
  int wordsPerMinute; // current WPM goal
  int totalCharactersSent;
  int totalCharactersReceived;

  UserProgress({
    this.currentLevel = 1,
    this.totalPracticeTime = 0,
    this.totalSessionsCompleted = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastPracticeDate,
    this.wordsPerMinute = 5,
    this.totalCharactersSent = 0,
    this.totalCharactersReceived = 0,
  });

  void updateDailyStreak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastPracticeDate != null) {
      final lastDate = DateTime(
        lastPracticeDate!.year,
        lastPracticeDate!.month,
        lastPracticeDate!.day,
      );
      final difference = today.difference(lastDate).inDays;

      if (difference == 1) {
        // Practiced yesterday, continue streak
        currentStreak++;
      } else if (difference > 1) {
        // Missed a day, reset streak
        currentStreak = 1;
      }
      // If difference == 0, already practiced today, don't increment
    } else {
      currentStreak = 1;
    }

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    lastPracticeDate = now;
  }

  Map<String, dynamic> toJson() => {
        'currentLevel': currentLevel,
        'totalPracticeTime': totalPracticeTime,
        'totalSessionsCompleted': totalSessionsCompleted,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastPracticeDate': lastPracticeDate?.toIso8601String(),
        'wordsPerMinute': wordsPerMinute,
        'totalCharactersSent': totalCharactersSent,
        'totalCharactersReceived': totalCharactersReceived,
      };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      currentLevel: json['currentLevel'] as int? ?? 1,
      totalPracticeTime: json['totalPracticeTime'] as int? ?? 0,
      totalSessionsCompleted: json['totalSessionsCompleted'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      lastPracticeDate: json['lastPracticeDate'] != null
          ? DateTime.parse(json['lastPracticeDate'] as String)
          : null,
      wordsPerMinute: json['wordsPerMinute'] as int? ?? 5,
      totalCharactersSent: json['totalCharactersSent'] as int? ?? 0,
      totalCharactersReceived: json['totalCharactersReceived'] as int? ?? 0,
    );
  }
}

/// Represents a practice session
class PracticeSession {
  final DateTime startTime;
  DateTime? endTime;
  final String sessionType; // 'learn', 'practice', 'challenge'
  int correctAnswers;
  int totalAttempts;
  int wordsPerMinute;
  List<String> charactersLearned;

  PracticeSession({
    required this.startTime,
    this.endTime,
    required this.sessionType,
    this.correctAnswers = 0,
    this.totalAttempts = 0,
    this.wordsPerMinute = 0,
    this.charactersLearned = const [],
  });

  int get durationSeconds {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inSeconds;
  }

  double get accuracy {
    if (totalAttempts == 0) return 0.0;
    return correctAnswers / totalAttempts;
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'sessionType': sessionType,
        'correctAnswers': correctAnswers,
        'totalAttempts': totalAttempts,
        'wordsPerMinute': wordsPerMinute,
        'charactersLearned': charactersLearned,
      };

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      sessionType: json['sessionType'] as String,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      totalAttempts: json['totalAttempts'] as int? ?? 0,
      wordsPerMinute: json['wordsPerMinute'] as int? ?? 0,
      charactersLearned: (json['charactersLearned'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
    );
  }
}
