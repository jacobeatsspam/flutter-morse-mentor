import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../services/progress_service.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('STATISTICS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress stats
          _buildSectionHeader(context, 'PROGRESS'),
          _buildStatTile(context, 'Current Level', '${progress.progress.currentLevel}'),
          _buildStatTile(context, 'Characters Mastered', '${progress.getMasteredCharacters().length}'),

          const SizedBox(height: 24),

          // Time stats
          _buildSectionHeader(context, 'TIME'),
          _buildStatTile(context, 'Total Practice Time', _formatTime(progress.progress.totalPracticeTime)),
          _buildStatTile(context, 'Sessions Completed', '${progress.progress.totalSessionsCompleted}'),

          const SizedBox(height: 24),

          // Streak stats
          _buildSectionHeader(context, 'STREAKS'),
          _buildStatTile(context, 'Current Streak', '${progress.progress.currentStreak} days'),
          _buildStatTile(context, 'Best Streak', '${progress.progress.bestStreak} days'),

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

  Widget _buildStatTile(BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.brass,
                ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
