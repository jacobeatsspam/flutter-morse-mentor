/// Tracks learning progress for a single character
class CharacterProgress {
  final String character;
  int correctCount;
  int incorrectCount;
  int streak;
  int bestStreak;
  DateTime? lastPracticed;
  bool mastered;

  CharacterProgress({
    required this.character,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastPracticed,
    this.mastered = false,
  });

  int get totalAttempts => correctCount + incorrectCount;

  double get accuracy {
    if (totalAttempts == 0) return 0.0;
    return correctCount / totalAttempts;
  }

  /// A character is considered mastered after 10+ correct with 90%+ accuracy
  bool get shouldBeMastered => correctCount >= 10 && accuracy >= 0.9;

  void recordAttempt(bool correct) {
    if (correct) {
      correctCount++;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      incorrectCount++;
      streak = 0;
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
}
