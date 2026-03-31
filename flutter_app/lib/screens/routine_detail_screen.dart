import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../services/api_client.dart';
import '../services/library_service.dart';
import '../services/local_store.dart';
import '../services/offline_library_service.dart';
import '../widgets/staggered_fade_in.dart';

class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key, required this.routineId, required this.title});

  final String routineId;
  final String title;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late final LibraryService _service;
  late final OfflineLibraryService _offline;
  late final LocalStoreSqlite _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service = LibraryService(context.read<ApiClient>());
    _offline = OfflineLibraryService(context.read<LocalStoreSqlite>());
    _store = context.read<LocalStoreSqlite>();
  }

  Future<void> _addExercise() async {
    HapticFeedback.selectionClick();
    final exercises = await _service.fetchExercises();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: exercises
              .map(
                (exercise) => ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(exercise.muscleGroup ?? 'Unknown'),
                  onTap: () async {
                    try {
                      await _service.addExerciseToRoutine(widget.routineId, exercise.id);
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to add exercise')),
                      );
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _addOfflineExercise() async {
    HapticFeedback.selectionClick();
    final exercises = await _offline.listExercises();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (exercises.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No offline exercises yet. Add one in Library.'),
          ));
        }
        return ListView(
          children: exercises
              .map(
                (exercise) => ListTile(
                  title: Text(exercise['name'] as String? ?? ''),
                  subtitle: Text(exercise['muscle_group'] as String? ?? 'Unknown'),
                  onTap: () async {
                    await _offline.addRoutineExercise(
                      routineId: widget.routineId,
                      exerciseId: exercise['id'] as String,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'online',
            onPressed: _addExercise,
            child: const Icon(Icons.cloud),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'offline',
            onPressed: _addOfflineExercise,
            child: const Icon(Icons.phone_iphone),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StaggeredFadeIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tap a row to edit default sets. Drag to reorder.'),
                const SizedBox(height: 12),
                Text('Online Routine', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                FutureBuilder<List<RoutineExerciseDto>>(
                  future: _service.fetchRoutineExercises(widget.routineId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Failed to load routine'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('No online exercises yet.'),
                      );
                    }
                    final items = snapshot.data!;
                    return ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) async {
                        HapticFeedback.selectionClick();
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final moved = items.removeAt(oldIndex);
                        items.insert(newIndex, moved);
                        final payload = <Map<String, dynamic>>[];
                        for (var i = 0; i < items.length; i++) {
                          payload.add({'id': items[i].id, 'order': i + 1});
                        }
                        try {
                          await _service.reorderRoutineExercises(widget.routineId, payload);
                        } catch (_) {
                          if (!mounted) return;
                          await _store.queueRoutineReorder(
                            widget.routineId,
                            jsonEncode(payload),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reorder queued for sync')),
                          );
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                      children: [
                        for (final item in items)
                          Card(
                            key: ValueKey(item.id),
                            child: ListTile(
                              title: Text(item.exerciseName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order ${item.displayOrder}'),
                                  if ((item.defaultSets ?? '').isNotEmpty)
                                    Text(
                                      _prettyJson(item.defaultSets!),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              leading: const Icon(Icons.drag_handle),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  try {
                                    await _service.removeRoutineExercise(item.id);
                                  } catch (_) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Failed to remove exercise')),
                                    );
                                  }
                                  if (!mounted) return;
                                  setState(() {});
                                },
                              ),
                              onTap: () async {
                                await _showOnlineDefaultSetsDialog(
                                  context,
                                  item.id,
                                  _service,
                                  item.defaultSets,
                                );
                                if (!mounted) return;
                                setState(() {});
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Offline Routine', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _offline.listRoutineExercises(widget.routineId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Failed to load offline routine'));
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('No offline exercises yet.'),
                      );
                    }
                    return ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) async {
                        HapticFeedback.selectionClick();
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final moved = items.removeAt(oldIndex);
                        items.insert(newIndex, moved);
                        for (var i = 0; i < items.length; i++) {
                          await _offline.reorderRoutineExercise(
                            id: items[i]['id'] as String,
                            newOrder: i + 1,
                          );
                        }
                        if (!mounted) return;
                        setState(() {});
                      },
                      children: [
                        for (final item in items)
                          Card(
                            key: ValueKey(item['id']),
                            child: ListTile(
                              title: Text(item['exercise_name'] as String? ?? 'Unknown'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order ${item['display_order'] ?? 0}'),
                                  if ((item['default_sets'] as String? ?? '').isNotEmpty)
                                    Text(
                                      _prettyJson(item['default_sets'] as String),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              leading: const Icon(Icons.drag_handle),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  await _offline.deleteRoutineExercise(item['id'] as String);
                                  if (!mounted) return;
                                  setState(() {});
                                },
                              ),
                              onTap: () async {
                                await _showDefaultSetsDialog(
                                  context,
                                  item['id'] as String,
                                  _offline,
                                  item['default_sets'] as String?,
                                );
                                if (!mounted) return;
                                setState(() {});
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showDefaultSetsDialog(
  BuildContext context,
  String routineExerciseId,
  OfflineLibraryService offline,
  String? existing,
) async {
  final controller = TextEditingController(text: existing ?? '');
  String? errorText;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Default Sets'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'JSON',
                    hintText: '[{\"reps\": 10, \"type\": \"normal\"}]',
                  ),
                  maxLines: 3,
                  onChanged: (_) {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setState(() => errorText = null);
                      return;
                    }
                    try {
                      final decoded = jsonDecode(text);
                      final error = _validateDefaultSetsSchema(decoded);
                      setState(() => errorText = error);
                    } catch (error) {
                      setState(() => errorText = error.toString());
                    }
                  },
                ),
                if (controller.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: HighlightView(
                      _prettyJson(controller.text.trim()),
                      language: 'json',
                      theme: atomOneDarkTheme,
                      textStyle: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    try {
                      final decoded = jsonDecode(text);
                      final error = _validateDefaultSetsSchema(decoded);
                      if (error != null) {
                        setState(() => errorText = error);
                        return;
                      }
                    } catch (error) {
                      setState(() => errorText = error.toString());
                      return;
                    }
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  if (result == true) {
    final text = controller.text.trim();
    await offline.updateRoutineExercise(
      id: routineExerciseId,
      defaultSets: text,
    );
  }
}

Future<void> _showOnlineDefaultSetsDialog(
  BuildContext context,
  String routineExerciseId,
  LibraryService service,
  String? existing,
) async {
  final controller = TextEditingController(text: existing ?? '');
  String? errorText;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Default Sets'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'JSON',
                    hintText: '[{\"reps\": 10, \"type\": \"normal\"}]',
                  ),
                  maxLines: 3,
                  onChanged: (_) {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setState(() => errorText = null);
                      return;
                    }
                    try {
                      final decoded = jsonDecode(text);
                      final error = _validateDefaultSetsSchema(decoded);
                      setState(() => errorText = error);
                    } catch (error) {
                      setState(() => errorText = error.toString());
                    }
                  },
                ),
                if (controller.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: HighlightView(
                      _prettyJson(controller.text.trim()),
                      language: 'json',
                      theme: atomOneDarkTheme,
                      textStyle: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    try {
                      final decoded = jsonDecode(text);
                      final error = _validateDefaultSetsSchema(decoded);
                      if (error != null) {
                        setState(() => errorText = error);
                        return;
                      }
                    } catch (error) {
                      setState(() => errorText = error.toString());
                      return;
                    }
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  if (result == true) {
    final text = controller.text.trim();
    try {
      await service.updateRoutineExerciseDefaultSets(routineExerciseId, text);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update default sets')),
        );
      }
    }
  }
}

String _prettyJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(decoded);
  } catch (_) {
    return raw;
  }
}

String? _validateDefaultSetsSchema(Object? decoded) {
  if (decoded is! List) return 'Root must be an array of sets.';
  for (final item in decoded) {
    if (item is! Map) return 'Each set must be an object.';
    if (!item.containsKey('reps')) return 'Each set must include reps.';
    final reps = item['reps'];
    final type = item['type'];
    final rpe = item['rpe'];
    if (reps is! int && reps is! double) return 'Reps must be a number.';
    if (type != null && type is! String) return 'Type must be a string.';
    if (rpe != null && rpe is! int && rpe is! double) return 'RPE must be a number.';
    if (type != null &&
        type != 'normal' &&
        type != 'warmup' &&
        type != 'dropset' &&
        type != 'failure') {
      return 'Type must be one of normal, warmup, dropset, failure.';
    }
  }
  return null;
}
