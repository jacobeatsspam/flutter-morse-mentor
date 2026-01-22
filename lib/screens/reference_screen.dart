import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/morse_code.dart';

class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    return Container(
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
    );
  }

  Widget _buildProsignsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: MorseCode.prosigns.length,
      itemBuilder: (context, index) {
        final entry = MorseCode.prosigns.entries.elementAt(index);
        return Container(
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
              Text(
                entry.value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.warningAmber,
                      letterSpacing: 2,
                    ),
              ),
            ],
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
        return Container(
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
            ],
          ),
        );
      },
    );
  }
}
