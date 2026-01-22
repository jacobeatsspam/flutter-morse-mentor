import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_theme.dart';

/// Displays morse code visually (dots and dashes)
class MorseDisplay extends StatelessWidget {
  /// The morse pattern to display (e.g., ".-" for A)
  final String pattern;

  /// Size of each element
  final double elementSize;

  /// Whether to animate the display
  final bool animated;

  /// Highlight the current element being played
  final int? activeIndex;

  const MorseDisplay({
    super.key,
    required this.pattern,
    this.elementSize = 24,
    this.animated = false,
    this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (pattern.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pattern.length, (index) {
        final element = pattern[index];
        final isActive = activeIndex == index;

        Widget child;
        if (element == '.') {
          child = _Dot(
            size: elementSize,
            isActive: isActive,
          );
        } else if (element == '-') {
          child = _Dash(
            size: elementSize,
            isActive: isActive,
          );
        } else {
          return const SizedBox.shrink();
        }

        if (animated) {
          child = child
              .animate(delay: Duration(milliseconds: index * 100))
              .fadeIn()
              .scale(begin: const Offset(0.5, 0.5));
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: elementSize * 0.15),
          child: child,
        );
      }),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final bool isActive;

  const _Dot({required this.size, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.signalGreen : AppColors.brass,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.signalGreen.withAlpha(128),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

class _Dash extends StatelessWidget {
  final double size;
  final bool isActive;

  const _Dash({required this.size, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 3,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        color: isActive ? AppColors.signalGreen : AppColors.brass,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.signalGreen.withAlpha(128),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Displays a live morse input stream
class MorseInputStream extends StatelessWidget {
  /// List of symbols entered so far
  final List<String> symbols;

  /// Maximum symbols to display
  final int maxSymbols;

  /// Size of each element
  final double elementSize;

  const MorseInputStream({
    super.key,
    required this.symbols,
    this.maxSymbols = 20,
    this.elementSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final displaySymbols = symbols.length > maxSymbols
        ? symbols.sublist(symbols.length - maxSymbols)
        : symbols;

    return Container(
      height: elementSize + 16,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Keep newest symbols visible
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < displaySymbols.length; i++) ...[
                  if (displaySymbols[i] == '.')
                    _Dot(size: elementSize)
                  else if (displaySymbols[i] == '-')
                    _Dash(size: elementSize)
                  else if (displaySymbols[i] == ' ')
                    SizedBox(width: elementSize)
                  else if (displaySymbols[i] == '/')
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: elementSize * 0.5),
                      child: Text(
                        '/',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: elementSize,
                        ),
                      ),
                    ),
                  if (i < displaySymbols.length - 1 &&
                      displaySymbols[i] != ' ' &&
                      displaySymbols[i] != '/')
                    SizedBox(width: elementSize * 0.3),
                ],
                // Blinking cursor
                _BlinkingCursor(size: elementSize),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  final double size;

  const _BlinkingCursor({required this.size});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: 3,
          height: widget.size,
          margin: EdgeInsets.only(left: widget.size * 0.3),
          color: AppColors.brass.withAlpha((_controller.value * 255).toInt()),
        );
      },
    );
  }
}

/// Card displaying a character with its morse code
class MorseCharacterCard extends StatelessWidget {
  final String character;
  final String morse;
  final String? mnemonic;
  final bool isLearned;
  final VoidCallback? onTap;

  const MorseCharacterCard({
    super.key,
    required this.character,
    required this.morse,
    this.mnemonic,
    this.isLearned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLearned ? AppColors.signalGreen : AppColors.divider,
              width: isLearned ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Character
              Text(
                character,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: isLearned ? AppColors.signalGreen : AppColors.brass,
                    ),
              ),
              const SizedBox(height: 8),
              // Morse pattern
              MorseDisplay(pattern: morse),
              if (mnemonic != null) ...[
                const SizedBox(height: 8),
                Text(
                  mnemonic!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (isLearned) ...[
                const SizedBox(height: 8),
                const Icon(
                  Icons.check_circle,
                  color: AppColors.signalGreen,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
