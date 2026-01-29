import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import 'learn_screen.dart';
import 'practice_screen.dart';
import 'challenge_screen.dart';
import 'reference_screen.dart';
import 'settings_screen.dart';
import 'compose_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final settings = context.read<SettingsService>();
    final progress = context.read<ProgressService>();
    await settings.initialize();
    await progress.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with logo and stats
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Main menu options
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildMenuCard(
                    icon: Icons.menu_book_outlined,
                    title: 'REFERENCE',
                    subtitle: 'Morse code charts, Q-codes & prosigns',
                    color: AppColors.textSecondary,
                    onTap: () => _navigateTo(const ReferenceScreen()),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.school_outlined,
                    title: 'LEARN',
                    subtitle: 'Master the morse alphabet step by step',
                    color: AppColors.brass,
                    onTap: () => _navigateTo(const LearnScreen()),
                  ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.fitness_center_outlined,
                    title: 'PRACTICE',
                    subtitle: 'Free-form sending and receiving drills',
                    color: AppColors.copper,
                    onTap: () => _navigateTo(const PracticeScreen()),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'CHALLENGE',
                    subtitle: 'Test your skills against the clock',
                    color: AppColors.warningAmber,
                    onTap: () => _navigateTo(const ChallengeScreen()),
                  ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.send_outlined,
                    title: 'COMPOSE',
                    subtitle: 'Tap a message and share via text or audio',
                    color: AppColors.signalGreen,
                    onTap: () => _navigateTo(const ComposeScreen()),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                ]),
              ),
            ),

            // Bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progress = context.watch<ProgressService>();
    final stats = progress.getStatistics();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.mahogany,
            AppColors.darkWood,
          ],
        ),
      ),
      child: Column(
        children: [
          // App title and settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MORSE',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.brass,
                          height: 1,
                        ),
                  ).animate().fadeIn().shimmer(
                        delay: 500.ms,
                        duration: 1500.ms,
                        color: AppColors.copper.withAlpha(77),
                      ),
                  Text(
                    'MENTOR',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1,
                        ),
                  ).animate().fadeIn(delay: 100.ms),
                ],
              ),
              IconButton(
                onPressed: () => _navigateTo(const SettingsScreen()),
                icon: const Icon(Icons.settings_outlined, size: 28),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.brass,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Stats row (tappable to see full stats)
          GestureDetector(
            onTap: () => _navigateTo(const StatsScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.darkWood.withAlpha(128),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    label: 'STREAK',
                    value: '${stats['currentStreak']}',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  _buildStatItem(
                    label: 'MASTERED',
                    value: '${stats['charactersMastered']}/${stats['totalCharacters']}',
                    icon: Icons.check_circle_outline,
                  ),
                  _buildStatItem(
                    label: 'WPM',
                    value: '${stats['wordsPerMinute']}',
                    icon: Icons.speed_outlined,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.brass, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
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
            border: Border.all(color: AppColors.divider),
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
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
