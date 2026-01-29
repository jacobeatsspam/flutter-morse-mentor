import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/morse_code.dart';
import '../models/user_progress.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../widgets/telegraph_key_layout.dart';
import '../widgets/morse_display.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  MorseCharacter? _currentChar; // Currently displayed character
  List<String> _inputSymbols = [];
  String _currentPattern = ''; // Pattern currently being typed (before commit)
  String _feedback = '';
  bool _showingResult = false;
  bool _isError = false; // True when showing error state (red symbols)
  DateTime? _keyDownTime; // Track when key was pressed down
  Timer? _autoCheckTimer; // Timer for auto-checking after pause
  int _consecutiveMastered = 0; // Track consecutive mastered chars for review
  int? _practiceLevel; // Selected practice level (null = use current unlocked level)
  
  // Audio feedback
  bool _audioEnabled = true;
  final AudioPlayer _tonePlayer = AudioPlayer();
  Uint8List? _toneBytes; // Pre-generated tone for playback

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _tonePlayer.dispose();
    super.dispose();
  }

  /// Initialize audio - generate a tone for playback
  void _initAudio() {
    // Generate 2 seconds of tone at 700Hz (enough for any key press)
    const sampleRate = 44100;
    const frequency = 700.0;
    const durationMs = 2000;
    const numSamples = sampleRate * durationMs ~/ 1000;
    
    // Generate WAV file in memory
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Sine wave with fade in/out
      var amplitude = sin(2 * pi * frequency * t);
      // Apply envelope for first/last 10ms to avoid clicks
      const fadeSamples = sampleRate * 10 ~/ 1000;
      if (i < fadeSamples) {
        amplitude *= i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        amplitude *= (numSamples - i) / fadeSamples;
      }
      samples.add((amplitude * 32767 * 0.7).round().clamp(-32768, 32767));
    }
    
    _toneBytes = _createWavBytes(samples, sampleRate);
  }

  /// Create WAV file bytes from PCM samples
  Uint8List _createWavBytes(List<int> samples, int sampleRate) {
    final byteData = ByteData(44 + samples.length * 2);
    
    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + samples.length * 2, Endian.little); // File size - 8
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Chunk size
    byteData.setUint16(20, 1, Endian.little);  // Audio format (PCM)
    byteData.setUint16(22, 1, Endian.little);  // Num channels (mono)
    byteData.setUint32(24, sampleRate, Endian.little); // Sample rate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    byteData.setUint16(32, 2, Endian.little);  // Block align
    byteData.setUint16(34, 16, Endian.little); // Bits per sample
    
    // data chunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, samples.length * 2, Endian.little); // Data size
    
    // Audio data
    for (int i = 0; i < samples.length; i++) {
      byteData.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    
    return byteData.buffer.asUint8List();
  }

  /// Start playing tone (called on key down)
  Future<void> _startTone() async {
    if (!_audioEnabled || _toneBytes == null) return;
    try {
      await _tonePlayer.play(BytesSource(_toneBytes!));
    } catch (e) {
      // Ignore audio player errors during rapid tapping
      // The player can get into an invalid state when play/stop are called quickly
    }
  }

  /// Stop playing tone (called on key up)
  Future<void> _stopTone() async {
    try {
      await _tonePlayer.stop();
    } catch (e) {
      // Ignore audio player errors during rapid tapping
    }
  }

  static final _random = Random();

  /// Select the next character to practice using smart weighting
  MorseCharacter _selectNextCharacter(ProgressService progress) {
    final activeLevel = _practiceLevel ?? progress.progress.currentLevel;
    final availableChars = learningOrder
        .where((c) => c.difficulty <= activeLevel)
        .toList();

    if (availableChars.isEmpty) {
      return learningOrder.first;
    }

    // Filter out the current character to avoid immediate repeats
    // (unless it's the only character available)
    final candidates = availableChars.length > 1 && _currentChar != null
        ? availableChars.where((c) => c.character != _currentChar!.character).toList()
        : availableChars;

    // Build weighted list based on mastery and accuracy
    final List<(MorseCharacter, double)> weightedChars = [];
    
    for (final char in candidates) {
      final charProgress = progress.getCharacterProgress(char.character);
      double weight;
      
      if (charProgress.mastered) {
        // Mastered: low weight (occasional review)
        weight = 0.1;
        // Every 5+ unmastered chars practiced, slightly higher chance for review
        if (_consecutiveMastered >= 5) {
          weight = 0.5;
        }
      } else if (charProgress.totalAttempts == 0) {
        // Never attempted: high priority to introduce new chars
        weight = 2.0;
      } else if (charProgress.accuracy < 0.7) {
        // Low accuracy: needs more practice
        weight = 3.0;
      } else if (charProgress.accuracy < 0.9) {
        // Medium accuracy: moderate priority
        weight = 1.5;
      } else {
        // High accuracy but not mastered: normal priority
        weight = 1.0;
      }
      
      weightedChars.add((char, weight));
    }

    // Weighted random selection using proper Random
    final totalWeight = weightedChars.fold(0.0, (sum, item) => sum + item.$2);
    if (totalWeight <= 0) {
      return candidates.first;
    }
    
    var randomValue = _random.nextDouble() * totalWeight;
    
    for (final (char, weight) in weightedChars) {
      randomValue -= weight;
      if (randomValue <= 0) {
        return char;
      }
    }
    
    return candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressService>();
    final activeLevel = _practiceLevel ?? progress.progress.currentLevel;
    final availableChars = learningOrder
        .where((c) => c.difficulty <= activeLevel)
        .toList();

    if (availableChars.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No characters available')),
      );
    }

    // Initialize or use existing current character
    _currentChar ??= _selectNextCharacter(progress);
    final currentChar = _currentChar!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LEARN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressBar(progress, availableChars.length),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Level indicator
                    _buildLevelIndicator(progress),
                    const SizedBox(height: 24),

                    // Character display
                    _buildCharacterDisplay(currentChar),
                    const SizedBox(height: 32),

                    // Input display
                    _buildInputSection(),
                    const SizedBox(height: 16),

                    // Feedback
                    if (_feedback.isNotEmpty)
                      _buildFeedback()
                          .animate()
                          .fadeIn()
                          .shake(hz: 3, duration: 300.ms),
                  ],
                ),
              ),
            ),

            // Telegraph key with audio toggle (using shared layout)
            TelegraphKeyLayout(
              onKeyDown: _onKeyDown,
              onKeyUp: _onKeyUp,
              enabled: !_showingResult,
              rightColumnButtons: [
                _buildSquareButton(
                  icon: _audioEnabled ? Icons.volume_up : Icons.volume_off,
                  label: _audioEnabled ? 'SOUND' : 'MUTED',
                  onPressed: () {
                    setState(() {
                      _audioEnabled = !_audioEnabled;
                    });
                  },
                  highlighted: _audioEnabled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ProgressService progress, int totalChars) {
    final masteredCount = progress.getMasteredCharacters().length;
    final progressPercent = totalChars > 0 ? masteredCount / totalChars : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              Text(
                '$masteredCount / $totalChars mastered',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.brass,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 6,
              backgroundColor: AppColors.mahogany,
              valueColor: const AlwaysStoppedAnimation(AppColors.signalGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelIndicator(ProgressService progress) {
    final unlockedLevel = progress.progress.currentLevel;
    final activeLevel = _practiceLevel ?? unlockedLevel;
    final canAdvance = progress.canAdvanceLevel();

    // Fixed height to prevent layout shift when ADVANCE button appears
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 1; i <= 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: i <= unlockedLevel ? () {
                  setState(() {
                    _practiceLevel = i;
                    _currentChar = null; // Will select new character on rebuild
                    _inputSymbols = [];
                    _currentPattern = '';
                    _feedback = '';
                  });
                } : null,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= unlockedLevel ? AppColors.brass : AppColors.mahogany,
                    border: Border.all(
                      color: i == activeLevel ? AppColors.signalGreen : 
                             (i <= unlockedLevel ? AppColors.brass : AppColors.divider),
                      width: i == activeLevel ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: i <= unlockedLevel ? AppColors.darkWood : AppColors.textMuted,
                        fontWeight: i == activeLevel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (canAdvance && activeLevel == unlockedLevel)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: TextButton.icon(
                onPressed: () async {
                  await progress.advanceLevel();
                  setState(() {
                    _practiceLevel = null; // Reset to new level
                    _currentChar = null; // Will select new character on rebuild
                  });
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('ADVANCE'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacterDisplay(MorseCharacter char) {
    final settings = context.watch<SettingsService>();
    final progress = context.watch<ProgressService>();
    final charProgress = progress.getCharacterProgress(char.character);
    
    // Calculate mastery progress based on sliding window
    // Need windowSize attempts (15) at 90%+ accuracy
    const windowSize = CharacterProgress.windowSize;
    const requiredAccuracy = 0.9;
    final attemptsProgress = (charProgress.recentAttempts.length / windowSize).clamp(0.0, 1.0);
    final accuracyOk = charProgress.recentAttempts.isEmpty || charProgress.accuracy >= requiredAccuracy;

    return Column(
      children: [
        // Large character with progress ring
        Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring behind the character
            SizedBox(
              width: 130,
              height: 130,
              child: CircularProgressIndicator(
                value: attemptsProgress,
                strokeWidth: 5,
                backgroundColor: AppColors.mahogany,
                valueColor: AlwaysStoppedAnimation(
                  charProgress.mastered 
                      ? AppColors.signalGreen 
                      : (accuracyOk ? AppColors.brass : AppColors.warningAmber),
                ),
              ),
            ),
            // Character box
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: charProgress.mastered ? AppColors.signalGreen : AppColors.brass, 
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  char.character,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 64,
                        color: charProgress.mastered ? AppColors.signalGreen : AppColors.brass,
                      ),
                ),
              ),
            ),
            // Mastery checkmark
            if (charProgress.mastered)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.signalGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

        const SizedBox(height: 12),
        
        // Character mastery stats
        _buildCharacterStats(charProgress),

        const SizedBox(height: 16),

        // Morse pattern (hint)
        if (settings.showHints) ...[
          MorseDisplay(
            pattern: char.morse,
            elementSize: 20,
            animated: true,
          ),
          const SizedBox(height: 12),
          Text(
            MorseCode.formatForDisplay(char.morse),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 4,
                ),
          ),
        ],

        const SizedBox(height: 16),

        // Mnemonic
        Text(
          char.mnemonic,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildCharacterStats(CharacterProgress charProgress) {
    const windowSize = CharacterProgress.windowSize;
    
    if (charProgress.mastered) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, size: 16, color: AppColors.signalGreen),
          const SizedBox(width: 4),
          Text(
            'Mastered!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.signalGreen,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      );
    }
    
    if (charProgress.recentAttempts.isEmpty) {
      return Text(
        'New character - give it a try!',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
      );
    }
    
    final recentCount = charProgress.recentAttempts.length;
    final recentCorrect = charProgress.recentCorrect;
    final accuracyPercent = (charProgress.accuracy * 100).round();
    final accuracyColor = charProgress.accuracy >= 0.9 
        ? AppColors.signalGreen 
        : (charProgress.accuracy >= 0.7 ? AppColors.warningAmber : AppColors.errorRed);
    
    // Show progress toward mastery
    final attemptsNeeded = windowSize - recentCount;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          attemptsNeeded > 0 
              ? '$recentCorrect/$recentCount (need ${attemptsNeeded} more)'
              : '$recentCorrect/$windowSize correct',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accuracyColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$accuracyPercent% accuracy',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accuracyColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    final hasInput = _inputSymbols.isNotEmpty || _currentPattern.isNotEmpty;
    
    return Column(
      children: [
        Text(
          'YOUR INPUT',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (hasInput) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Show committed symbols (MorseInputStream has its own decoration)
              if (_inputSymbols.isNotEmpty)
                Flexible(
                  child: MorseInputStream(
                    symbols: _inputSymbols,
                    color: _isError ? AppColors.errorRed : null,
                  ),
                ),
              // Show current pattern being typed (with different styling)
              if (_currentPattern.isNotEmpty)
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  margin: EdgeInsets.only(left: _inputSymbols.isNotEmpty ? 8 : 0),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isError ? AppColors.errorRed : AppColors.warningAmber,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      MorseCode.formatForDisplay(_currentPattern),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _isError ? AppColors.errorRed : AppColors.warningAmber,
                            letterSpacing: 4,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFeedback() {
    final isCorrect = _feedback.startsWith('Correct');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.signalGreen.withAlpha(26)
            : AppColors.errorRed.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? AppColors.signalGreen : AppColors.errorRed,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.error_outline,
            color: isCorrect ? AppColors.signalGreen : AppColors.errorRed,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _feedback,
              style: TextStyle(
                color: isCorrect ? AppColors.signalGreen : AppColors.errorRed,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a square button matching the Compose screen style
  Widget _buildSquareButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool highlighted = false,
  }) {
    return SizedBox(
      width: 56,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: highlighted ? AppColors.signalGreen.withAlpha(50) : null,
          side: highlighted 
              ? const BorderSide(color: AppColors.signalGreen) 
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  void _onKeyDown() {
    if (_showingResult) return;
    _keyDownTime = DateTime.now();
    _startTone();
  }

  void _onKeyUp() {
    _stopTone();
    if (_showingResult || _keyDownTime == null) return;

    final duration = DateTime.now().difference(_keyDownTime!).inMilliseconds;
    _keyDownTime = null;

    // Use a generous fixed threshold for touchscreen input (matching compose screen)
    // - Taps under 200ms = dot
    // - Taps 200ms or longer = dash
    // This is more forgiving than strict Morse timing
    const int dotThreshold = 200; // milliseconds
    final symbol = duration < dotThreshold ? '.' : '-';

    setState(() {
      _currentPattern += symbol;
      _feedback = '';
    });

    // Schedule auto-check after a generous pause (800ms like compose screen)
    // This gives users plenty of time between symbols
    _autoCheckTimer?.cancel();
    const int letterGapTimeout = 800; // milliseconds
    _autoCheckTimer = Timer(
      const Duration(milliseconds: letterGapTimeout),
      _commitPatternAndCheck,
    );
  }

  /// Commit the current pattern to input symbols and check the answer
  void _commitPatternAndCheck() {
    if (_currentPattern.isEmpty || _showingResult) return;

    setState(() {
      // Move current pattern to input symbols
      _inputSymbols.addAll(_currentPattern.split(''));
      _currentPattern = '';
    });

    _checkAnswer();
  }

  void _checkAnswer() {
    _autoCheckTimer?.cancel();
    
    if (_currentChar == null) return;
    
    final progress = context.read<ProgressService>();
    final currentChar = _currentChar!;

    final inputPattern = _inputSymbols.join();
    final correct = inputPattern == currentChar.morse;

    // Record the attempt
    progress.recordAttempt(currentChar.character, correct);
    
    // Track mastery for review scheduling
    final charProgress = progress.getCharacterProgress(currentChar.character);
    if (charProgress.mastered) {
      _consecutiveMastered = 0; // Reset counter after reviewing a mastered char
    } else {
      _consecutiveMastered++;
    }

    if (correct) {
      // Correct: brief celebration, then advance to next character
      setState(() {
        _showingResult = true;
        _feedback = 'Correct!';
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _currentChar = _selectNextCharacter(progress);
            _inputSymbols = [];
            _currentPattern = '';
            _feedback = '';
            _showingResult = false;
          });
        }
      });
    } else {
      // Incorrect: show red symbols briefly, then clear
      setState(() {
        _isError = true;
      });

      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _inputSymbols = [];
            _currentPattern = '';
            _isError = false;
          });
        }
      });
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('How to Learn'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Look at the character shown'),
            SizedBox(height: 8),
            Text('2. Study the morse pattern (dots and dashes)'),
            SizedBox(height: 8),
            Text('3. Tap the telegraph key to input:'),
            Text('   • Quick tap = dot (dit)'),
            Text('   • Long press = dash (dah)'),
            SizedBox(height: 8),
            Text('4. Your input will be checked automatically'),
            SizedBox(height: 16),
            Text(
              'Tip: Use the mnemonic to help remember the pattern!',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}
