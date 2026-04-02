import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/library_service.dart';
import '../services/offline_library_service.dart';
import '../services/local_store.dart';
import '../widgets/staggered_fade_in.dart';
import 'routine_detail_screen.dart';

// ── Muscle group colours ────────────────────────────────────────────────────
const _muscleColors = <String, Color>{
  'Chest':     Color(0xFFE53935),
  'Back':      Color(0xFF1E88E5),
  'Shoulders': Color(0xFF8E24AA),
  'Arms':      Color(0xFFFF8F00),
  'Legs':      Color(0xFF43A047),
  'Core':      Color(0xFF00ACC1),
  'Cardio':    Color(0xFFFF5722),
  'Full Body': Color(0xFF6D4C41),
};

Color _colorFor(String? group) =>
    _muscleColors[group ?? ''] ?? const Color(0xFF607D8B);

// ── Body regions for diagram (normalised 0-1 coordinates) ──────────────────
const _bodyRegions = <String, List<Rect>>{
  'Chest':     [Rect.fromLTWH(0.30, 0.22, 0.40, 0.14)],
  'Back':      [Rect.fromLTWH(0.30, 0.22, 0.40, 0.18)],
  'Shoulders': [
    Rect.fromLTWH(0.13, 0.20, 0.17, 0.10),
    Rect.fromLTWH(0.70, 0.20, 0.17, 0.10),
  ],
  'Arms':      [
    Rect.fromLTWH(0.10, 0.30, 0.14, 0.22),
    Rect.fromLTWH(0.76, 0.30, 0.14, 0.22),
  ],
  'Legs':      [
    Rect.fromLTWH(0.28, 0.55, 0.19, 0.36),
    Rect.fromLTWH(0.53, 0.55, 0.19, 0.36),
  ],
  'Core':      [Rect.fromLTWH(0.30, 0.36, 0.40, 0.16)],
  'Cardio':    [Rect.fromLTWH(0.25, 0.20, 0.50, 0.72)],
  'Full Body': [Rect.fromLTWH(0.25, 0.20, 0.50, 0.72)],
};

class _BodyDiagram extends StatelessWidget {
  const _BodyDiagram({required this.muscleGroup});
  final String muscleGroup;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 180,
      child: CustomPaint(painter: _BodyPainter(muscleGroup)),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.muscleGroup);
  final String muscleGroup;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final highlight = Paint()
      ..color = (_muscleColors[muscleGroup] ?? const Color(0xFF607D8B)).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    void drawRounded(Rect r, Paint p, {double radius = 8}) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);
    }

    // helper to scale normalised rect
    Rect s(Rect r) => Rect.fromLTWH(
          r.left * size.width,
          r.top * size.height,
          r.width * size.width,
          r.height * size.height,
        );

    // head
    final headRect = s(const Rect.fromLTWH(0.35, 0.02, 0.30, 0.14));
    drawRounded(headRect, base, radius: 20);
    drawRounded(headRect, outline, radius: 20);

    // torso
    final torsoRect = s(const Rect.fromLTWH(0.28, 0.18, 0.44, 0.34));
    drawRounded(torsoRect, base);
    drawRounded(torsoRect, outline);

    // left arm
    final lArmRect = s(const Rect.fromLTWH(0.10, 0.20, 0.16, 0.28));
    drawRounded(lArmRect, base);
    drawRounded(lArmRect, outline);

    // right arm
    final rArmRect = s(const Rect.fromLTWH(0.74, 0.20, 0.16, 0.28));
    drawRounded(rArmRect, base);
    drawRounded(rArmRect, outline);

    // left leg
    final lLegRect = s(const Rect.fromLTWH(0.28, 0.54, 0.20, 0.42));
    drawRounded(lLegRect, base);
    drawRounded(lLegRect, outline);

    // right leg
    final rLegRect = s(const Rect.fromLTWH(0.52, 0.54, 0.20, 0.42));
    drawRounded(rLegRect, base);
    drawRounded(rLegRect, outline);

    // highlight active regions
    final regions = _bodyRegions[muscleGroup] ?? [];
    for (final r in regions) {
      drawRounded(s(r), highlight);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.muscleGroup != muscleGroup;
}

// ── Main screen ─────────────────────────────────────────────────────────────

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
            Text('Exercises & Routines',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            const Text('Build your library and templates in a few taps.'),
            const SizedBox(height: 16),
            Text('Exercise Library',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<ExerciseDto>>(
              future: service.fetchExercises(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlaceholderTile(title: 'Loading exercises...');
                }
                if (snapshot.hasError) {
                  return const _PlaceholderTile(
                      title: 'Failed to load exercises');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const _PlaceholderTile(title: 'No exercises yet');
                }

                // group by muscle group
                final grouped = <String, List<ExerciseDto>>{};
                for (final ex in snapshot.data!) {
                  final g = ex.muscleGroup ?? 'Other';
                  grouped.putIfAbsent(g, () => []).add(ex);
                }
                final sortedGroups = grouped.keys.toList()..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in sortedGroups) ...[
                      _MuscleGroupHeader(group: group),
                      ...grouped[group]!.map(
                        (exercise) => _ExerciseTile(
                          name: exercise.name,
                          muscleGroup: exercise.muscleGroup,
                          equipment: exercise.equipment,
                          mediaUrl: exercise.mediaUrl,
                          mediaType: exercise.mediaType,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
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
                  return const _PlaceholderTile(
                      title: 'Failed to load routines');
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
                            subtitle:
                                Text('Difficulty ${routine.difficulty ?? 0}/10'),
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
                Text('Offline Library',
                    style: Theme.of(context).textTheme.titleLarge),
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
                  return const _PlaceholderTile(
                      title: 'Loading offline exercises...');
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const _PlaceholderTile(title: 'No offline exercises');
                }
                return Column(
                  children: items
                      .map(
                        (item) => _ExerciseTile(
                          name: item['name'] as String? ?? '',
                          muscleGroup: item['muscle_group'] as String?,
                          equipment: item['equipment'] as String?,
                          mediaUrl: item['media_url'] as String?,
                          mediaType: item['media_type'] as String?,
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
                final items = snapshot.data ?? [];
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: items
                      .map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item['name'] as String? ?? ''),
                            subtitle: Text(
                                'Difficulty ${item['difficulty_rating'] ?? 0}/10'),
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

// ── Reusable exercise tile ───────────────────────────────────────────────────

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.name,
    this.muscleGroup,
    this.equipment,
    this.mediaUrl,
    this.mediaType,
  });

  final String name;
  final String? muscleGroup;
  final String? equipment;
  final String? mediaUrl;
  final String? mediaType;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _ExerciseMediaThumb(url: mediaUrl, type: mediaType),
        title: Text(name),
        subtitle: equipment != null
            ? Text(equipment!, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => showExerciseDetail(
          context,
          name: name,
          muscleGroup: muscleGroup,
          equipment: equipment,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        ),
      ),
    );
  }
}

// ── Muscle group section header ──────────────────────────────────────────────

class _MuscleGroupHeader extends StatelessWidget {
  const _MuscleGroupHeader({required this.group});
  final String group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _colorFor(group),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            group.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _colorFor(group),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exercise detail sheet ────────────────────────────────────────────────────

void showExerciseDetail(
  BuildContext context, {
  required String name,
  String? muscleGroup,
  String? equipment,
  String? mediaUrl,
  String? mediaType,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                if (equipment != null)
                  Text(equipment,
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 20),

                // image + diagram side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // exercise image
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _buildMedia(mediaUrl, mediaType),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // muscle diagram
                    Column(
                      children: [
                        _BodyDiagram(muscleGroup: muscleGroup ?? ''),
                        const SizedBox(height: 8),
                        if (muscleGroup != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _colorFor(muscleGroup).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _colorFor(muscleGroup), width: 1),
                            ),
                            child: Text(
                              muscleGroup,
                              style: TextStyle(
                                color: _colorFor(muscleGroup),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildMedia(String? url, String? type) {
  if (url == null || url.isEmpty) {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.fitness_center, size: 48, color: Colors.white38),
      ),
    );
  }
  if (type == 'mp4') {
    return Container(
      color: Colors.black,
      child: const Center(
          child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70)),
    );
  }
  // gif or image — both render with Image.network
  return Image.network(
    url,
    fit: BoxFit.cover,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return Container(
        color: Colors.white10,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    },
    errorBuilder: (_, __, ___) => Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.fitness_center, size: 48, color: Colors.white38),
      ),
    ),
  );
}

// ── Thumbnail ────────────────────────────────────────────────────────────────

class _ExerciseMediaThumb extends StatelessWidget {
  const _ExerciseMediaThumb({this.url, this.type});

  final String? url;
  final String? type;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        backgroundColor: Colors.white12,
        child: Icon(Icons.fitness_center, size: 18, color: Colors.white54),
      );
    }
    if (type == 'mp4') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          color: Colors.black54,
          child:
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white12,
            child: const Icon(Icons.fitness_center,
                size: 18, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

// ── Dialogs ──────────────────────────────────────────────────────────────────

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
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: muscle,
                decoration: const InputDecoration(labelText: 'Muscle')),
            TextField(
                controller: equipment,
                decoration: const InputDecoration(labelText: 'Equipment')),
            const SizedBox(height: 8),
            TextField(
              controller: mediaUrl,
              decoration:
                  const InputDecoration(labelText: 'Media URL (GIF/MP4)'),
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
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
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: difficulty,
              decoration:
                  const InputDecoration(labelText: 'Difficulty (1-10)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      );
    },
  );
  if (result == true) {
    final value = int.tryParse(difficulty.text);
    await offline.createRoutine(
        name: name.text, difficultyRating: value);
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
      ),
    );
  }
}
