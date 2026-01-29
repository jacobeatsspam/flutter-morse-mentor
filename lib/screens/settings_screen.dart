import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final progress = context.read<ProgressService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Speed settings
          _buildSectionHeader(context, 'SPEED'),
          _buildSliderTile(
            context: context,
            title: 'Words Per Minute',
            subtitle: '${settings.wordsPerMinute} WPM',
            value: settings.wordsPerMinute.toDouble(),
            min: 5,
            max: 40,
            divisions: 35,
            onChanged: (value) => settings.setWordsPerMinute(value.round()),
          ),
          _buildSliderTile(
            context: context,
            title: 'Farnsworth Speed',
            subtitle: '${settings.farnsworthWpm} WPM',
            value: settings.farnsworthWpm.toDouble(),
            min: 15,
            max: 40,
            divisions: 25,
            onChanged: (value) => settings.setfarnsworthWpm(value.round()),
          ),

          const SizedBox(height: 24),

          // Audio settings
          _buildSectionHeader(context, 'AUDIO'),
          _buildSliderTile(
            context: context,
            title: 'Volume',
            subtitle: '${(settings.volume * 100).round()}%',
            value: settings.volume,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: settings.setVolume,
          ),
          _buildSliderTile(
            context: context,
            title: 'Tone Frequency',
            subtitle: '${settings.toneFrequency} Hz',
            value: settings.toneFrequency.toDouble(),
            min: 400,
            max: 1000,
            divisions: 12,
            onChanged: (value) => settings.setToneFrequency(value.round()),
          ),

          const SizedBox(height: 24),

          // Input settings
          _buildSectionHeader(context, 'INPUT'),
          _buildSwitchTile(
            context: context,
            title: 'Haptic Feedback',
            subtitle: 'Vibrate on key press',
            value: settings.hapticFeedback,
            onChanged: settings.setHapticFeedback,
          ),

          const SizedBox(height: 24),

          // Danger zone
          _buildSectionHeader(context, 'DATA'),
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: ListTile(
              leading: const Icon(Icons.refresh, color: AppColors.warningAmber),
              title: const Text('Reset Settings'),
              subtitle: const Text('Restore default settings'),
              onTap: () => _confirmAction(
                context,
                'Reset Settings',
                'This will restore all settings to their defaults.',
                () => settings.resetToDefaults(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.errorRed.withAlpha(128)),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.errorRed),
              title: const Text(
                'Reset Progress',
                style: TextStyle(color: AppColors.errorRed),
              ),
              subtitle: const Text('Delete all learning progress'),
              onTap: () => _confirmAction(
                context,
                'Reset Progress',
                'This will permanently delete all your learning progress. This cannot be undone.',
                () => progress.resetProgress(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // About
          Center(
            child: Column(
              children: [
                Text(
                  'MORSE MENTOR',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.brass,
            ),
      ),
    );
  }

  Widget _buildSliderTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : 1,
            onChanged: onChanged,
            activeColor: AppColors.brass,
            inactiveColor: AppColors.mahogany,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.signalGreen,
      ),
    );
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(
              'CONFIRM',
              style: TextStyle(
                color: title.contains('Progress')
                    ? AppColors.errorRed
                    : AppColors.brass,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
