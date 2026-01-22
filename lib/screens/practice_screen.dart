import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/morse_code.dart';
import '../services/morse_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../widgets/telegraph_key.dart';
import '../widgets/morse_display.dart';

enum PracticeMode { send, receive, freeform }

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PRACTICE'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SEND'),
            Tab(text: 'RECEIVE'),
            Tab(text: 'FREEFORM'),
          ],
          indicatorColor: AppColors.brass,
          labelColor: AppColors.brass,
          unselectedLabelColor: AppColors.textMuted,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SendPractice(),
          _ReceivePractice(),
          _FreeformPractice(),
        ],
      ),
    );
  }
}

/// Send practice - user sends characters shown on screen
class _SendPractice extends StatefulWidget {
  const _SendPractice();

  @override
  State<_SendPractice> createState() => _SendPracticeState();
}

class _SendPracticeState extends State<_SendPractice> {
  String _targetChar = '';
  List<String> _inputSymbols = [];
  int _correctCount = 0;
  int _totalCount = 0;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _generateNewTarget();
  }

  void _generateNewTarget() {
    final progress = context.read<ProgressService>();
    final morseService = context.read<MorseService>();
    final level = progress.progress.currentLevel;

    setState(() {
      _targetChar = morseService.getRandomCharacter(level);
      _inputSymbols = [];
      _feedback = '';
    });
  }

  void _handleKeyPress(int duration) {
    final settings = context.read<SettingsService>();
    final dotThreshold = MorseCode.getDotDuration(settings.wordsPerMinute) * 2;

    setState(() {
      _inputSymbols.add(duration < dotThreshold ? '.' : '-');
    });

    // Check after brief delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _inputSymbols.isNotEmpty) {
        _checkInput();
      }
    });
  }

  void _checkInput() {
    final morseService = context.read<MorseService>();
    final targetMorse = morseService.charToPattern(_targetChar);
    final inputPattern = _inputSymbols.join();

    if (inputPattern == targetMorse) {
      // Correct!
      setState(() {
        _correctCount++;
        _totalCount++;
        _feedback = 'Correct!';
      });

      context.read<ProgressService>().recordAttempt(_targetChar, true);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _generateNewTarget();
      });
    } else if (targetMorse != null && inputPattern.length >= targetMorse.length) {
      // Wrong - too many or wrong symbols
      setState(() {
        _totalCount++;
        _feedback = 'Incorrect. Expected: $targetMorse';
      });

      context.read<ProgressService>().recordAttempt(_targetChar, false);

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _inputSymbols = [];
            _feedback = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final morseService = context.read<MorseService>();

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                label: 'Correct',
                value: '$_correctCount',
                color: AppColors.signalGreen,
              ),
              _StatChip(
                label: 'Total',
                value: '$_totalCount',
                color: AppColors.brass,
              ),
              _StatChip(
                label: 'Accuracy',
                value: _totalCount > 0
                    ? '${((_correctCount / _totalCount) * 100).toInt()}%'
                    : '-',
                color: AppColors.copper,
              ),
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Target character
                Text(
                  'Send this character:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brass, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _targetChar,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppColors.brass,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Input display
                MorseInputStream(symbols: _inputSymbols),
                const SizedBox(height: 16),

                // Feedback
                if (_feedback.isNotEmpty)
                  Text(
                    _feedback,
                    style: TextStyle(
                      color: _feedback.startsWith('Correct')
                          ? AppColors.signalGreen
                          : AppColors.errorRed,
                      fontSize: 16,
                    ),
                  ),

                // Hint button
                TextButton(
                  onPressed: () {
                    final pattern = morseService.charToPattern(_targetChar);
                    if (pattern != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Hint: $pattern'),
                          backgroundColor: AppColors.mahogany,
                        ),
                      );
                    }
                  },
                  child: const Text('SHOW HINT'),
                ),
              ],
            ),
          ),
        ),

        // Telegraph key
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: TelegraphKey(onPress: _handleKeyPress),
        ),
      ],
    );
  }
}

/// Receive practice - user decodes morse played to them
class _ReceivePractice extends StatefulWidget {
  const _ReceivePractice();

  @override
  State<_ReceivePractice> createState() => _ReceivePracticeState();
}

class _ReceivePracticeState extends State<_ReceivePractice> {
  String _targetChar = '';
  String _userGuess = '';
  bool _isPlaying = false;
  int _correctCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _generateNewTarget();
  }

  void _generateNewTarget() {
    final progress = context.read<ProgressService>();
    final morseService = context.read<MorseService>();
    final level = progress.progress.currentLevel;

    setState(() {
      _targetChar = morseService.getRandomCharacter(level);
      _userGuess = '';
    });
  }

  Future<void> _playMorse() async {
    final morseService = context.read<MorseService>();
    final settings = context.read<SettingsService>();
    final pattern = morseService.charToPattern(_targetChar);

    if (pattern == null) return;

    setState(() => _isPlaying = true);

    // Visual playback (in real app, would also play audio)
    for (int i = 0; i < pattern.length; i++) {
      await Future.delayed(
        Duration(milliseconds: pattern[i] == '.'
            ? MorseCode.getDotDuration(settings.wordsPerMinute)
            : MorseCode.getDashDuration(settings.wordsPerMinute)),
      );
      await Future.delayed(
        Duration(milliseconds: MorseCode.getSymbolGap(settings.wordsPerMinute)),
      );
    }

    setState(() => _isPlaying = false);
  }

  void _checkGuess(String guess) {
    final correct = guess.toUpperCase() == _targetChar;

    setState(() {
      _userGuess = guess.toUpperCase();
      _totalCount++;
      if (correct) _correctCount++;
    });

    context.read<ProgressService>().recordAttempt(_targetChar, correct);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _generateNewTarget();
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.read<ProgressService>();
    final availableChars = learningOrder
        .where((c) => c.difficulty <= progress.progress.currentLevel)
        .map((c) => c.character)
        .toList();

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                label: 'Correct',
                value: '$_correctCount',
                color: AppColors.signalGreen,
              ),
              _StatChip(
                label: 'Total',
                value: '$_totalCount',
                color: AppColors.brass,
              ),
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Listen and identify:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),

                // Play button
                ElevatedButton.icon(
                  onPressed: _isPlaying ? null : _playMorse,
                  icon: Icon(_isPlaying ? Icons.volume_up : Icons.play_arrow),
                  label: Text(_isPlaying ? 'PLAYING...' : 'PLAY MORSE'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // User's guess display
                if (_userGuess.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _userGuess,
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: _userGuess == _targetChar
                                  ? AppColors.signalGreen
                                  : AppColors.errorRed,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _userGuess == _targetChar
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _userGuess == _targetChar
                            ? AppColors.signalGreen
                            : AppColors.errorRed,
                      ),
                    ],
                  ),
                  if (_userGuess != _targetChar)
                    Text(
                      'Correct answer: $_targetChar',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ],
            ),
          ),
        ),

        // Character selection grid
        Container(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: availableChars.map((char) {
              return SizedBox(
                width: 48,
                height: 48,
                child: TextButton(
                  onPressed: _userGuess.isEmpty ? () => _checkGuess(char) : null,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Text(
                    char,
                    style: const TextStyle(
                      color: AppColors.brass,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Freeform practice - user can tap freely and see decoded output
class _FreeformPractice extends StatefulWidget {
  const _FreeformPractice();

  @override
  State<_FreeformPractice> createState() => _FreeformPracticeState();
}

class _FreeformPracticeState extends State<_FreeformPractice> {
  List<String> _inputSymbols = [];
  String _decodedText = '';
  String _currentPattern = '';
  Timer? _decodeTimer;

  @override
  void dispose() {
    _decodeTimer?.cancel();
    super.dispose();
  }

  void _handleKeyPress(int duration) {
    final settings = context.read<SettingsService>();
    final dotThreshold = MorseCode.getDotDuration(settings.wordsPerMinute) * 2;
    final symbol = duration < dotThreshold ? '.' : '-';

    setState(() {
      _inputSymbols.add(symbol);
      _currentPattern += symbol;
    });

    // Reset decode timer
    _decodeTimer?.cancel();
    _decodeTimer = Timer(
      Duration(milliseconds: MorseCode.getLetterGap(settings.wordsPerMinute)),
      _decodeLetter,
    );
  }

  void _decodeLetter() {
    final morseService = context.read<MorseService>();
    final char = morseService.patternToChar(_currentPattern);

    setState(() {
      if (char != null) {
        _decodedText += char;
        _inputSymbols.add(' ');
      } else if (_currentPattern.isNotEmpty) {
        _decodedText += '?';
        _inputSymbols.add(' ');
      }
      _currentPattern = '';
    });
  }

  void _addWordSpace() {
    if (_currentPattern.isNotEmpty) {
      _decodeLetter();
    }

    setState(() {
      _decodedText += ' ';
      _inputSymbols.add('/');
    });
  }

  void _clear() {
    setState(() {
      _inputSymbols = [];
      _decodedText = '';
      _currentPattern = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Decoded text display
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DECODED TEXT',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _decodedText.isEmpty ? 'Start tapping...' : _decodedText,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: _decodedText.isEmpty
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Morse input display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MorseInputStream(symbols: _inputSymbols),
        ),

        // Current pattern being entered
        if (_currentPattern.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Current: $_currentPattern',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.warningAmber,
                  ),
            ),
          ),

        // Control buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _addWordSpace,
                icon: const Icon(Icons.space_bar, size: 16),
                label: const Text('WORD'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('CLEAR'),
              ),
            ],
          ),
        ),

        // Telegraph key
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: TelegraphKey(onPress: _handleKeyPress),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ],
    );
  }
}
