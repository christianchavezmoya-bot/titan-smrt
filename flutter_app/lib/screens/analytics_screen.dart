import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/local_store.dart';
import '../widgets/staggered_fade_in.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.read<LocalStoreSqlite>();
    return SafeArea(
      child: StaggeredFadeIn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Analytics', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            const Text('Trends, PRs, and AI insights in one place.'),
            const SizedBox(height: 16),
            const _HeatmapCard(),
            const SizedBox(height: 16),
            Text('AI Insights', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const _InsightCarousel(),
            const SizedBox(height: 16),
            Text('PR Leaderboard', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: store.listExercisePrLeaderboard(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlaceholderCard(title: 'Loading PRs...');
                }
                if (snapshot.hasError) {
                  return const _PlaceholderCard(title: 'Failed to load PRs');
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _PlaceholderCard(title: 'No PRs yet');
                }
                return Column(
                  children: items
                      .map(
                        (item) => Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(item['exercise_name'] as String? ?? 'Unknown'),
                                ),
                                const SizedBox(width: 8),
                                const Chip(
                                  label: Text('PR'),
                                  avatar: Icon(Icons.emoji_events, size: 14),
                                ),
                              ],
                            ),
                            trailing:
                                Text('${(item['max_rm'] as num?)?.toStringAsFixed(1) ?? '0'}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1C), Color(0xFF101010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Muscle Heatmap', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: 28,
            itemBuilder: (context, index) {
              final intensity = (index % 4) * 0.2 + 0.2;
              return Container(
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFF1F1F1F), const Color(0xFFCCFF00), intensity),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightCarousel extends StatelessWidget {
  const _InsightCarousel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _InsightCard(
            title: 'Bench Plateau',
            message: 'Strength down 5%. Deload next week.',
          ),
          _InsightCard(
            title: 'Recovery Alert',
            message: 'Rest 20s longer for strength sets.',
          ),
          _InsightCard(
            title: 'Nutrition Impact',
            message: 'Low carbs linked to lower volume.',
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String message;

  const _InsightCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF151515)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Color(0xFF6200EA), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;

  const _PlaceholderCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
