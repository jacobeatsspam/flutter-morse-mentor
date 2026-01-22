import '../core/constants/morse_code.dart';

/// Service for encoding and decoding morse code
class MorseService {
  /// Decode a series of key press timings into morse code symbols
  /// Returns a list of dots and dashes based on press durations
  List<String> decodeTimings(List<int> pressDurations, int wpm) {
    final dotThreshold = MorseCode.getDotDuration(wpm) * 2;
    return pressDurations.map((duration) {
      return duration < dotThreshold ? '.' : '-';
    }).toList();
  }

  /// Determine if a gap between presses indicates a new letter or word
  /// Returns: 'symbol' for same letter, 'letter' for new letter, 'word' for new word
  String classifyGap(int gapDuration, int wpm) {
    final letterGap = MorseCode.getLetterGap(wpm);
    final wordGap = MorseCode.getWordGap(wpm);

    if (gapDuration >= wordGap) {
      return 'word';
    } else if (gapDuration >= letterGap) {
      return 'letter';
    }
    return 'symbol';
  }

  /// Convert a morse pattern to its character equivalent
  String? patternToChar(String pattern) {
    return MorseCode.morseToCharacter(pattern);
  }

  /// Convert a character to its morse pattern
  String? charToPattern(String char) {
    return MorseCode.charToMorse(char);
  }

  /// Convert full text to morse code string
  String textToMorse(String text) {
    return MorseCode.textToMorse(text);
  }

  /// Convert morse code string to text
  String morseToText(String morse) {
    return MorseCode.morseToText(morse);
  }

  /// Validate if a morse pattern is valid
  bool isValidPattern(String pattern) {
    if (pattern.isEmpty) return false;
    // Check if pattern only contains dots and dashes
    if (!RegExp(r'^[.\-]+$').hasMatch(pattern)) return false;
    // Check if it maps to a known character
    return MorseCode.morseToChar.containsKey(pattern);
  }

  /// Get timing sequence for playing a morse character
  /// Returns list of (duration, isSignal) tuples
  List<({int duration, bool isSignal})> getPlaybackTimings(
    String pattern,
    int wpm,
  ) {
    final List<({int duration, bool isSignal})> timings = [];
    final dotDuration = MorseCode.getDotDuration(wpm);
    final dashDuration = MorseCode.getDashDuration(wpm);
    final symbolGap = MorseCode.getSymbolGap(wpm);

    for (int i = 0; i < pattern.length; i++) {
      // Add the signal (dot or dash)
      if (pattern[i] == '.') {
        timings.add((duration: dotDuration, isSignal: true));
      } else if (pattern[i] == '-') {
        timings.add((duration: dashDuration, isSignal: true));
      }

      // Add gap between symbols (but not after last symbol)
      if (i < pattern.length - 1) {
        timings.add((duration: symbolGap, isSignal: false));
      }
    }

    return timings;
  }

  /// Get random character for practice based on difficulty level
  String getRandomCharacter(int maxDifficulty) {
    final availableChars = learningOrder
        .where((c) => c.difficulty <= maxDifficulty)
        .toList();
    
    if (availableChars.isEmpty) return 'E';
    
    availableChars.shuffle();
    return availableChars.first.character;
  }

  /// Get random word for practice (common CW abbreviations)
  String getRandomWord(int maxLength) {
    const commonWords = [
      'CQ', 'DE', 'TNX', 'RST', 'UR', 'ES', 'FB', 'OM', 'YL', 'XYL',
      'WX', 'ANT', 'RIG', 'PSE', 'QTH', 'QSL', 'QSO', 'QRZ', 'HI',
      'THE', 'AND', 'FOR', 'ARE', 'BUT', 'NOT', 'YOU', 'ALL', 'CAN',
      'SOS', 'OK', 'YES', 'NO', 'HELP', 'TEST', 'CALL', 'NAME',
    ];

    final filtered = commonWords.where((w) => w.length <= maxLength).toList();
    filtered.shuffle();
    return filtered.first;
  }

  /// Calculate WPM from timing data
  /// Uses the PARIS standard (50 timing units per word)
  double calculateWpm(List<int> pressDurations, List<int> gaps) {
    if (pressDurations.isEmpty) return 0;

    // Total time in milliseconds
    int totalTime = pressDurations.reduce((a, b) => a + b);
    if (gaps.isNotEmpty) {
      totalTime += gaps.reduce((a, b) => a + b);
    }

    // Count total elements (dots and dashes)
    final totalElements = pressDurations.length;

    // Estimate average dot duration (assuming mix of dots and dashes)
    // Average element is about 2 units (1 for dot, 3 for dash, average = 2)
    final avgElementTime = totalTime / totalElements;
    final estimatedDotTime = avgElementTime / 2;

    // WPM = 1200 / dot_duration_ms
    return 1200 / estimatedDotTime;
  }

  /// Get hint for a character (show the morse pattern visually)
  String getHint(String character) {
    final pattern = charToPattern(character);
    if (pattern == null) return '';

    // Convert to visual representation
    return pattern.split('').map((s) => s == '.' ? '●' : '━━').join(' ');
  }

  /// Get mnemonic for a character
  String? getMnemonic(String character) {
    final char = learningOrder.where(
      (c) => c.character == character.toUpperCase(),
    ).firstOrNull;
    return char?.mnemonic;
  }
}
