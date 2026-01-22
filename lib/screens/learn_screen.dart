import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/morse_code.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../widgets/telegraph_key.dart';
import '../widgets/morse_display.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _currentCharIndex = 0;
  List<String> _inputSymbols = [];
  String _feedback = '';
  bool _showingResult = false;
  DateTime? _lastInputTime;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressService>();
    final availableChars = learningOrder
        .where((c) => c.difficulty <= (progress.progress.currentLevel))
        .toList();

    if (availableChars.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No characters available')),
      );
    }

    final currentChar = availableChars[_currentCharIndex % availableChars.length];

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

            // Telegraph key
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  TelegraphKey(
                    onPress: _handleKeyPress,
                    enabled: !_showingResult,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap the key to input morse code',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
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
    final level = progress.progress.currentLevel;
    final canAdvance = progress.canAdvanceLevel();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= level ? AppColors.brass : AppColors.mahogany,
                border: Border.all(
                  color: i == level ? AppColors.brass : AppColors.divider,
                  width: i == level ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '$i',
                  style: TextStyle(
                    color: i <= level ? AppColors.darkWood : AppColors.textMuted,
                    fontWeight: i == level ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        if (canAdvance)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: TextButton.icon(
              onPressed: () async {
                await progress.advanceLevel();
                setState(() {
                  _currentCharIndex = 0;
                });
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('ADVANCE'),
            ),
          ),
      ],
    );
  }

  Widget _buildCharacterDisplay(MorseCharacter char) {
    final settings = context.watch<SettingsService>();

    return Column(
      children: [
        // Large character
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brass, width: 2),
          ),
          child: Center(
            child: Text(
              char.character,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 72,
                    color: AppColors.brass,
                  ),
            ),
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

        const SizedBox(height: 24),

        // Morse pattern (hint)
        if (settings.showHints) ...[
          MorseDisplay(
            pattern: char.morse,
            elementSize: 20,
            animated: true,
          ),
          const SizedBox(height: 12),
          Text(
            char.morse.replaceAll('.', '● ').replaceAll('-', '━━ ').trim(),
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

  Widget _buildInputSection() {
    return Column(
      children: [
        Text(
          'YOUR INPUT',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: _inputSymbols.isEmpty
              ? Text(
                  'Press the key...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                )
              : MorseInputStream(symbols: _inputSymbols),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _clearInput,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('CLEAR'),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _inputSymbols.isEmpty ? null : _checkAnswer,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('CHECK'),
            ),
          ],
        ),
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
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.error_outline,
            color: isCorrect ? AppColors.signalGreen : AppColors.errorRed,
          ),
          const SizedBox(width: 12),
          Text(
            _feedback,
            style: TextStyle(
              color: isCorrect ? AppColors.signalGreen : AppColors.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  void _handleKeyPress(int duration) {
    if (_showingResult) return;

    final settings = context.read<SettingsService>();
    final dotThreshold = MorseCode.getDotDuration(settings.wordsPerMinute) * 2;

    setState(() {
      _inputSymbols.add(duration < dotThreshold ? '.' : '-');
      _lastInputTime = DateTime.now();
      _feedback = '';
    });

    // Auto-check after a pause (letter gap)
    Future.delayed(Duration(milliseconds: MorseCode.getLetterGap(settings.wordsPerMinute) * 2), () {
      if (_lastInputTime != null &&
          DateTime.now().difference(_lastInputTime!).inMilliseconds >=
              MorseCode.getLetterGap(settings.wordsPerMinute) * 2 &&
          _inputSymbols.isNotEmpty &&
          !_showingResult) {
        _checkAnswer();
      }
    });
  }

  void _checkAnswer() {
    final progress = context.read<ProgressService>();
    final availableChars = learningOrder
        .where((c) => c.difficulty <= progress.progress.currentLevel)
        .toList();
    final currentChar = availableChars[_currentCharIndex % availableChars.length];

    final inputPattern = _inputSymbols.join();
    final correct = inputPattern == currentChar.morse;

    setState(() {
      _showingResult = true;
      if (correct) {
        _feedback = 'Correct! Well done!';
      } else {
        _feedback = 'Try again. Expected: ${currentChar.morse}';
      }
    });

    // Record the attempt
    progress.recordAttempt(currentChar.character, correct);

    // Move to next character after delay
    if (correct) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _currentCharIndex++;
            _inputSymbols = [];
            _feedback = '';
            _showingResult = false;
          });
        }
      });
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _inputSymbols = [];
            _feedback = '';
            _showingResult = false;
          });
        }
      });
    }
  }

  void _clearInput() {
    setState(() {
      _inputSymbols = [];
      _feedback = '';
    });
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
