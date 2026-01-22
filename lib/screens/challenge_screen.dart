import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/morse_code.dart';
import '../services/morse_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../widgets/telegraph_key.dart';
import '../widgets/morse_display.dart';

enum ChallengeType { speedRun, accuracy, endurance }

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  ChallengeType? _selectedChallenge;
  bool _challengeActive = false;
  bool _challengeComplete = false;

  // Challenge state
  int _score = 0;
  int _correctCount = 0;
  int _totalCount = 0;
  int _timeRemaining = 60;
  Timer? _timer;

  // Current target
  String _targetChar = '';
  List<String> _inputSymbols = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startChallenge(ChallengeType type) {
    setState(() {
      _selectedChallenge = type;
      _challengeActive = true;
      _challengeComplete = false;
      _score = 0;
      _correctCount = 0;
      _totalCount = 0;
      _timeRemaining = type == ChallengeType.endurance ? 0 : 60;
    });

    _generateNewTarget();

    if (type != ChallengeType.endurance) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _timeRemaining--;
          if (_timeRemaining <= 0) {
            _endChallenge();
          }
        });
      });
    } else {
      // Endurance mode - count up
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _timeRemaining++;
        });
      });
    }
  }

  void _endChallenge() {
    _timer?.cancel();
    setState(() {
      _challengeActive = false;
      _challengeComplete = true;
    });
  }

  void _generateNewTarget() {
    final progress = context.read<ProgressService>();
    final morseService = context.read<MorseService>();
    final level = progress.progress.currentLevel;

    setState(() {
      _targetChar = morseService.getRandomCharacter(level);
      _inputSymbols = [];
    });
  }

  void _handleKeyPress(int duration) {
    if (!_challengeActive) return;

    final settings = context.read<SettingsService>();
    final dotThreshold = MorseCode.getDotDuration(settings.wordsPerMinute) * 2;

    setState(() {
      _inputSymbols.add(duration < dotThreshold ? '.' : '-');
    });

    // Auto-check
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _inputSymbols.isNotEmpty && _challengeActive) {
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
        _score += _calculatePoints();
      });

      _generateNewTarget();
    } else if (targetMorse != null && inputPattern.length >= targetMorse.length) {
      // Wrong
      setState(() {
        _totalCount++;
        _inputSymbols = [];

        // In accuracy mode, end on first mistake
        if (_selectedChallenge == ChallengeType.accuracy) {
          _endChallenge();
        }

        // In endurance mode, 3 strikes
        if (_selectedChallenge == ChallengeType.endurance) {
          final mistakes = _totalCount - _correctCount;
          if (mistakes >= 3) {
            _endChallenge();
          }
        }
      });
    }
  }

  int _calculatePoints() {
    // Base points
    int points = 10;

    // Bonus for speed (characters per minute)
    if (_selectedChallenge == ChallengeType.speedRun) {
      points += (_correctCount ~/ 10) * 5;
    }

    // Bonus for streak in accuracy mode
    if (_selectedChallenge == ChallengeType.accuracy) {
      points += _correctCount * 2;
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (_challengeComplete) {
      return _buildResultsScreen();
    }

    if (_challengeActive) {
      return _buildChallengeScreen();
    }

    return _buildSelectionScreen();
  }

  Widget _buildSelectionScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHALLENGE'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select a Challenge',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            _ChallengeCard(
              icon: Icons.speed,
              title: 'SPEED RUN',
              description: 'Send as many characters as possible in 60 seconds',
              color: AppColors.warningAmber,
              onTap: () => _startChallenge(ChallengeType.speedRun),
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),

            const SizedBox(height: 16),

            _ChallengeCard(
              icon: Icons.gps_fixed,
              title: 'ACCURACY',
              description: 'Perfect run - one mistake ends the challenge',
              color: AppColors.signalGreen,
              onTap: () => _startChallenge(ChallengeType.accuracy),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

            const SizedBox(height: 16),

            _ChallengeCard(
              icon: Icons.fitness_center,
              title: 'ENDURANCE',
              description: 'Go as long as you can - 3 strikes and you\'re out',
              color: AppColors.copper,
              onTap: () => _startChallenge(ChallengeType.endurance),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

            const Spacer(),

            // High scores preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Text(
                    'YOUR BEST',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HighScoreItem(label: 'Speed', value: '-'),
                      _HighScoreItem(label: 'Accuracy', value: '-'),
                      _HighScoreItem(label: 'Endurance', value: '-'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getChallengeTitle()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _endChallenge,
        ),
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.mahogany,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.timer,
                  value: _formatTime(_timeRemaining),
                  label: _selectedChallenge == ChallengeType.endurance
                      ? 'TIME'
                      : 'REMAINING',
                ),
                _buildStatItem(
                  icon: Icons.star,
                  value: '$_score',
                  label: 'SCORE',
                ),
                _buildStatItem(
                  icon: Icons.check,
                  value: '$_correctCount',
                  label: 'CORRECT',
                ),
              ],
            ),
          ),

          // Strike indicator for endurance mode
          if (_selectedChallenge == ChallengeType.endurance)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final mistakes = _totalCount - _correctCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < mistakes ? Icons.close : Icons.favorite,
                      color: i < mistakes
                          ? AppColors.errorRed
                          : AppColors.signalGreen,
                      size: 32,
                    ),
                  );
                }),
              ),
            ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SEND:',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.brass, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        _targetChar,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 72,
                              color: AppColors.brass,
                            ),
                      ),
                    ),
                  )
                      .animate(
                        onComplete: (controller) => controller.reset(),
                      )
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        duration: 200.ms,
                      ),

                  const SizedBox(height: 32),

                  // Input display
                  MorseInputStream(symbols: _inputSymbols),
                ],
              ),
            ),
          ),

          // Telegraph key
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: TelegraphKey(
              onPress: _handleKeyPress,
              enabled: _challengeActive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    final accuracy = _totalCount > 0 ? (_correctCount / _totalCount * 100) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RESULTS'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getResultIcon(),
                size: 80,
                color: _getResultColor(),
              ).animate().scale(delay: 200.ms),

              const SizedBox(height: 24),

              Text(
                _getResultMessage(),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 48),

              // Score card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brass, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'FINAL SCORE',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_score',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppColors.brass,
                          ),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResultStat(
                          label: 'Correct',
                          value: '$_correctCount',
                        ),
                        _ResultStat(
                          label: 'Total',
                          value: '$_totalCount',
                        ),
                        _ResultStat(
                          label: 'Accuracy',
                          value: '${accuracy.toInt()}%',
                        ),
                      ],
                    ),
                    if (_selectedChallenge == ChallengeType.endurance) ...[
                      const SizedBox(height: 16),
                      _ResultStat(
                        label: 'Time',
                        value: _formatTime(_timeRemaining),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _challengeComplete = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('MENU'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _startChallenge(_selectedChallenge!),
                    icon: const Icon(Icons.replay),
                    label: const Text('RETRY'),
                  ),
                ],
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.brass, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  String _getChallengeTitle() {
    switch (_selectedChallenge) {
      case ChallengeType.speedRun:
        return 'SPEED RUN';
      case ChallengeType.accuracy:
        return 'ACCURACY';
      case ChallengeType.endurance:
        return 'ENDURANCE';
      default:
        return 'CHALLENGE';
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  IconData _getResultIcon() {
    if (_correctCount >= 30) return Icons.emoji_events;
    if (_correctCount >= 15) return Icons.star;
    return Icons.thumb_up;
  }

  Color _getResultColor() {
    if (_correctCount >= 30) return AppColors.warningAmber;
    if (_correctCount >= 15) return AppColors.brass;
    return AppColors.signalGreen;
  }

  String _getResultMessage() {
    if (_correctCount >= 30) return 'Outstanding!';
    if (_correctCount >= 20) return 'Excellent work!';
    if (_correctCount >= 10) return 'Good job!';
    return 'Keep practicing!';
  }
}

class _ChallengeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ChallengeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(128)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: color,
                            letterSpacing: 2,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighScoreItem extends StatelessWidget {
  final String label;
  final String value;

  const _HighScoreItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.brass,
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

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;

  const _ResultStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
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
