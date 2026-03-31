import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_client.dart';
import '../services/nutrition_service.dart';
import '../widgets/staggered_fade_in.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fats = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _protein.dispose();
    _carbs.dispose();
    _fats.dispose();
    super.dispose();
  }

  Future<void> _save(NutritionService service) async {
    final p = double.tryParse(_protein.text) ?? 0;
    final c = double.tryParse(_carbs.text) ?? 0;
    final f = double.tryParse(_fats.text) ?? 0;
    setState(() => _isSaving = true);
    final result = await service.log(p, c, f);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition logged')),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log nutrition')),
      );
    }
  }

  Future<void> _exportCsv(NutritionWeekly weekly) async {
    final buffer = StringBuffer();
    buffer.writeln('date,protein,carbs,fats,calories');
    for (final day in weekly.days) {
      buffer.writeln(
          '${day.date},${day.protein},${day.carbs},${day.fats},${day.calories}');
    }
    final content = buffer.toString();
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Weekly CSV copied')),
    );
  }

  Future<void> _shareCsv(NutritionWeekly weekly) async {
    final buffer = StringBuffer();
    buffer.writeln('date,protein,carbs,fats,calories');
    for (final day in weekly.days) {
      buffer.writeln(
          '${day.date},${day.protein},${day.carbs},${day.fats},${day.calories}');
    }
    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/nutrition_weekly.csv').writeAsString(
      buffer.toString(),
    );
    await Share.shareXFiles([XFile(file.path)], text: 'Weekly nutrition');
  }

  @override
  Widget build(BuildContext context) {
    final service = NutritionService(context.read<ApiClient>());
    return SafeArea(
      child: StaggeredFadeIn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Nutrition', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Log Macros', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _protein,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Protein (g)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _carbs,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Carbs (g)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fats,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fats (g)'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : () => _save(service),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<NutritionSummary?>(
              future: service.summary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const _PlaceholderCard(label: 'Loading summary...');
                }
                final summary = snapshot.data!;
                return Card(
                  child: ListTile(
                    title: const Text('Today Summary'),
                    subtitle: Text(
                      '${summary.calories.toStringAsFixed(0)} kcal · '
                      '${summary.protein.toStringAsFixed(0)}P '
                      '${summary.carbs.toStringAsFixed(0)}C '
                      '${summary.fats.toStringAsFixed(0)}F',
                    ),
                    trailing: const Icon(Icons.insights),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<NutritionSummary?>(
              future: service.summary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const _PlaceholderCard(label: 'Loading insight...');
                }
                final summary = snapshot.data!;
                return Card(
                  child: ListTile(
                    title: const Text('AI Nutrition Insight'),
                    subtitle: Text(summary.suggestion),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<NutritionWeekly?>(
              future: service.weekly(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const _PlaceholderCard(label: 'Loading weekly trend...');
                }
                final weekly = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Trend', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    for (final day in weekly.days)
                      Card(
                        child: ListTile(
                          title: Text(day.date),
                          subtitle: Text(
                            '${day.calories.toStringAsFixed(0)} kcal · '
                            '${day.protein.toStringAsFixed(0)}P '
                            '${day.carbs.toStringAsFixed(0)}C '
                            '${day.fats.toStringAsFixed(0)}F',
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _exportCsv(weekly),
                            child: const Text('Copy CSV'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _shareCsv(weekly),
                            child: const Text('Share CSV'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
      ),
    );
  }
}
