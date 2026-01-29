import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/morse_code.dart';
import '../services/morse_audio_generator.dart';
import '../services/settings_service.dart';

class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Play morse code for a pattern at the specified speed
  Future<void> _playMorse(String morsePattern, {double speed = 1.0, bool useFarnsworth = false}) async {
    if (_isPlaying) return;

    final settings = context.read<SettingsService>();

    setState(() => _isPlaying = true);

    File? tempFile;
    try {
      // Stop any previous playback and reset player state
      await _audioPlayer.stop();
      
      final adjustedWpm = (settings.wordsPerMinute * speed).round().clamp(5, 50);
      final effectiveCharWpm = useFarnsworth ? settings.farnsworthWpm : null;
      
      final generator = MorseAudioGenerator(
        toneFrequency: settings.toneFrequency,
        wordsPerMinute: adjustedWpm,
        characterWpm: effectiveCharWpm,
      );
      final wavBytes = generator.generateWavFromMorseSync(morsePattern);

      // Write to temp file for more reliable playback (especially for slower speeds)
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/morse_ref_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavBytes);
      
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      await _audioPlayer.onPlayerComplete.first;
    } finally {
      // Clean up temp file
      try {
        await tempFile?.delete();
      } catch (_) {}
      
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  /// Show playback speed options menu
  void _showPlaySpeedMenu(BuildContext context, String character, String morsePattern) {
    final settings = context.read<SettingsService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkWood,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PLAY "$character"',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              morsePattern,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.warningAmber,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Standard Timing'),
              subtitle: Text('Play at ${settings.wordsPerMinute} WPM'),
              onTap: () {
                Navigator.pop(ctx);
                _playMorse(morsePattern);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Farnsworth Timing'),
              subtitle: Text(
                'Characters at ${settings.farnsworthWpm} WPM, gaps at ${settings.wordsPerMinute} WPM',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _playMorse(morsePattern, useFarnsworth: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.slow_motion_video),
              title: const Text('Half Speed (1/2)'),
              subtitle: Text('Play at ${(settings.wordsPerMinute / 2).round()} WPM'),
              onTap: () {
                Navigator.pop(ctx);
                _playMorse(morsePattern, speed: 0.5);
              },
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_bottom),
              title: const Text('Quarter Speed (1/4)'),
              subtitle: Text('Play at ${(settings.wordsPerMinute / 4).round()} WPM'),
              onTap: () {
                Navigator.pop(ctx);
                _playMorse(morsePattern, speed: 0.25);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REFERENCE'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'ALPHABET'),
            Tab(text: 'NUMBERS'),
            Tab(text: 'PROSIGNS'),
            Tab(text: 'Q-CODES'),
          ],
          indicatorColor: AppColors.brass,
          labelColor: AppColors.brass,
          unselectedLabelColor: AppColors.textMuted,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlphabetTab(),
          _buildNumbersTab(),
          _buildProsignsTab(),
          _buildQCodesTab(),
        ],
      ),
    );
  }

  Widget _buildAlphabetTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: MorseCode.letters.length,
      itemBuilder: (context, index) {
        final entry = MorseCode.letters.entries.elementAt(index);
        return _buildCompactCard(entry.key, entry.value);
      },
    );
  }

  Widget _buildNumbersTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: MorseCode.numbers.length,
      itemBuilder: (context, index) {
        final entry = MorseCode.numbers.entries.elementAt(index);
        return _buildCompactCard(entry.key, entry.value);
      },
    );
  }

  Widget _buildCompactCard(String character, String morse) {
    return GestureDetector(
      onTap: _isPlaying ? null : () => _playMorse(morse),
      onLongPress: _isPlaying ? null : () => _showPlaySpeedMenu(context, character, morse),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              character,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.brass,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              morse,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.warningAmber,
                    letterSpacing: 1,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProsignsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: MorseCode.prosigns.length,
      itemBuilder: (context, index) {
        final entry = MorseCode.prosigns.entries.elementAt(index);
        return GestureDetector(
          onTap: _isPlaying ? null : () => _playMorse(entry.value),
          onLongPress: _isPlaying ? null : () => _showPlaySpeedMenu(context, entry.key, entry.value),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.brass,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.warningAmber,
                          letterSpacing: 2,
                        ),
                  ),
                ),
                Icon(
                  Icons.volume_up,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQCodesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: MorseCode.qCodes.length,
      itemBuilder: (context, index) {
        final entry = MorseCode.qCodes.entries.elementAt(index);
        final morsePattern = MorseCode.textToMorse(entry.key);
        return GestureDetector(
          onTap: _isPlaying ? null : () => _playMorse(morsePattern),
          onLongPress: _isPlaying ? null : () => _showPlaySpeedMenu(context, entry.key, morsePattern),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.brass,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Icon(
                  Icons.volume_up,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
