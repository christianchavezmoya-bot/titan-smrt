import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/library_service.dart';
import '../services/offline_library_service.dart';
import '../services/local_store.dart';
import '../widgets/staggered_fade_in.dart';
import 'routine_detail_screen.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = LibraryService(context.read<ApiClient>());
    final offline = OfflineLibraryService(context.read<LocalStoreSqlite>());

    return SafeArea(
      child: StaggeredFadeIn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Exercises & Routines', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            const Text('Build your library and templates in a few taps.'),
            const SizedBox(height: 16),
            Text('Exercise Library', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<ExerciseDto>>(
              future: service.fetchExercises(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlaceholderTile(title: 'Loading exercises...');
                }
                if (snapshot.hasError) {
                  return const _PlaceholderTile(title: 'Failed to load exercises');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const _PlaceholderTile(title: 'No exercises yet');
                }
                return Column(
                  children: snapshot.data!
                      .map(
                        (exercise) => Card(
                          child: ListTile(
                            leading: _ExerciseMediaThumb(
                              url: exercise.mediaUrl,
                              type: exercise.mediaType,
                            ),
                            title: Text(exercise.name),
                            subtitle: Text(exercise.muscleGroup ?? 'Unknown'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _showMediaPreview(
                                context,
                                name: exercise.name,
                                url: exercise.mediaUrl,
                                type: exercise.mediaType,
                              );
                            },
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Routines', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<RoutineDto>>(
              future: service.fetchRoutines(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlaceholderTile(title: 'Loading routines...');
                }
                if (snapshot.hasError) {
                  return const _PlaceholderTile(title: 'Failed to load routines');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const _PlaceholderTile(title: 'No routines yet');
                }
                return Column(
                  children: snapshot.data!
                      .map(
                        (routine) => Card(
                          child: ListTile(
                            title: Text(routine.name),
                            subtitle: Text('Difficulty ${routine.difficulty ?? 0}/10'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RoutineDetailScreen(
                                    routineId: routine.id,
                                    title: routine.name,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Offline Library', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await _showCreateExerciseDialog(context, offline);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await _showCreateRoutineDialog(context, offline);
                  },
                  icon: const Icon(Icons.playlist_add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: offline.listExercises(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlaceholderTile(title: 'Loading offline exercises...');
                }
                if (snapshot.hasError) {
                  return const _PlaceholderTile(title: 'Offline exercises error');
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _PlaceholderTile(title: 'No offline exercises');
                }
                return Column(
                  children: items
                      .map(
                        (item) => Card(
                          child: ListTile(
                            leading: _ExerciseMediaThumb(
                              url: item['media_url'] as String?,
                              type: item['media_type'] as String?,
                            ),
                            title: Text(item['name'] as String? ?? ''),
                            subtitle: Text(item['muscle_group'] as String? ?? 'Unknown'),
                            onTap: () {
                              _showMediaPreview(
                                context,
                                name: item['name'] as String? ?? 'Exercise',
                                url: item['media_url'] as String?,
                                type: item['media_type'] as String?,
                              );
                            },
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: offline.listRoutines(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlaceholderTile(title: 'Loading offline routines...');
                }
                if (snapshot.hasError) {
                  return const _PlaceholderTile(title: 'Offline routines error');
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _PlaceholderTile(title: 'No offline routines');
                }
                return Column(
                  children: items
                      .map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item['name'] as String? ?? ''),
                            subtitle: Text('Difficulty ${item['difficulty_rating'] ?? 0}/10'),
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

Future<void> _showCreateExerciseDialog(
  BuildContext context,
  OfflineLibraryService offline,
) async {
  final name = TextEditingController();
  final muscle = TextEditingController();
  final equipment = TextEditingController();
  final mediaUrl = TextEditingController();
  String mediaType = 'gif';
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('New Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: muscle, decoration: const InputDecoration(labelText: 'Muscle')),
            TextField(controller: equipment, decoration: const InputDecoration(labelText: 'Equipment')),
            const SizedBox(height: 8),
            TextField(
              controller: mediaUrl,
              decoration: const InputDecoration(labelText: 'Media URL (GIF/MP4)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Media type'),
                const Spacer(),
                DropdownButton<String>(
                  value: mediaType,
                  items: const [
                    DropdownMenuItem(value: 'gif', child: Text('GIF')),
                    DropdownMenuItem(value: 'mp4', child: Text('MP4')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    mediaType = value;
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      );
    },
  );
  if (result == true) {
    await offline.createExercise(
      name: name.text,
      muscleGroup: muscle.text,
      equipment: equipment.text,
      mediaUrl: mediaUrl.text.isEmpty ? null : mediaUrl.text,
      mediaType: mediaUrl.text.isEmpty ? null : mediaType,
    );
  }
}

Future<void> _showCreateRoutineDialog(
  BuildContext context,
  OfflineLibraryService offline,
) async {
  final name = TextEditingController();
  final difficulty = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('New Routine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty (1-10)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      );
    },
  );
  if (result == true) {
    final value = int.tryParse(difficulty.text);
    await offline.createRoutine(name: name.text, difficultyRating: value);
  }
}

class _PlaceholderTile extends StatelessWidget {
  final String title;

  const _PlaceholderTile({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}

void _showMediaPreview(
  BuildContext context, {
  required String name,
  String? url,
  String? type,
}) {
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No media attached to this exercise.')),
    );
    return;
  }
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(name),
        content: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: type == 'gif'
                ? Image.network(url, fit: BoxFit.cover)
                : Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Icon(Icons.play_circle_fill, size: 64),
                    ),
                  ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
    },
  );
}

class _ExerciseMediaThumb extends StatelessWidget {
  const _ExerciseMediaThumb({this.url, this.type});

  final String? url;
  final String? type;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        backgroundColor: Colors.black26,
        child: Icon(Icons.fitness_center, size: 18),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: type == 'gif'
            ? Image.network(url!, fit: BoxFit.cover)
            : Container(
                color: Colors.black54,
                child: const Icon(Icons.play_circle_fill, color: Colors.white),
              ),
      ),
    );
  }
}
