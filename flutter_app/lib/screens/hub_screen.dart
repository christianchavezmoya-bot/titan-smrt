import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/local_store.dart';
import '../services/settings_controller.dart';
import '../services/sync_controller.dart';
import '../services/sync_service.dart';
import '../services/timer_cues.dart';
import '../services/workout_service.dart';
import '../widgets/active_workout_card.dart';
import '../widgets/staggered_fade_in.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final store = context.read<LocalStoreSqlite>();
    String statusText;
    switch (sync.state) {
      case SyncState.syncing:
        statusText = 'Syncing...';
        break;
      case SyncState.ok:
        statusText = 'Synced';
        break;
      case SyncState.error:
        statusText = 'Sync failed';
        break;
      default:
        statusText = 'Idle';
    }
    final lastSync = sync.lastSyncAt?.toLocal().toIso8601String() ?? 'Never';

    return SafeArea(
      child: StaggeredFadeIn(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ready', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              const Text('Smart Start loads today’s predicted routine.'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(label: Text('$statusText · $lastSync')),
                  const Spacer(),
                  if (sync.conflicts.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const _SyncConflictsScreen()),
                        );
                      },
                      child: Text('Conflicts (${sync.conflicts.length})'),
                    ),
                  IconButton(
                    onPressed: sync.state == SyncState.syncing
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            sync.sync();
                          },
                    icon: const Icon(Icons.sync),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const ActiveWorkoutCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 400),
                      scale: 1,
                      child: FilledButton(
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          final service = WorkoutService(store);
                          final workoutId = await service.startWorkout();
                          if (!context.mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _WorkoutSessionScreen(workoutId: workoutId),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Smart Start'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        final service = WorkoutService(store);
                        final workoutId = await service.startWorkout();
                        if (!context.mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _WorkoutSessionScreen(workoutId: workoutId),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Quick Start'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Recent Workouts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: store.listWorkouts(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Failed to load workouts'));
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(child: Text('No workouts yet.'));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            title: Text('Workout ${index + 1}'),
                            subtitle: FutureBuilder<_WorkoutSummary>(
                              future: _buildSummary(store, item),
                              builder: (context, summarySnap) {
                                if (!summarySnap.hasData) {
                                  return const Text('Loading summary...');
                                }
                                final summary = summarySnap.data!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${summary.durationLabel} · ${summary.setCount} sets · ${summary.prLabel}',
                                    ),
                                    if (summary.prExercises.isNotEmpty)
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: -8,
                                        children: summary.prExercises
                                            .map(
                                              (name) => Chip(
                                                label: Text(name),
                                                avatar:
                                                    const Icon(Icons.emoji_events, size: 14),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                  ],
                                );
                              },
                            ),
                            trailing: Text('${item['total_volume'] ?? 0}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutSummary {
  _WorkoutSummary({
    required this.durationLabel,
    required this.setCount,
    required this.prLabel,
    required this.prExercises,
  });

  final String durationLabel;
  final int setCount;
  final String prLabel;
  final List<String> prExercises;
}

Future<_WorkoutSummary> _buildSummary(
  LocalStoreSqlite store,
  Map<String, dynamic> workout,
) async {
  final start = DateTime.tryParse(workout['start_time'] as String? ?? '');
  final end = DateTime.tryParse(workout['end_time'] as String? ?? '');
  final duration = (start != null && end != null)
      ? end.difference(start)
      : const Duration(minutes: 0);
  final setCount = await store.countSets(workout['id'] as String);
  final hasPr = await store.isWorkoutPr(workout['id'] as String);
  final prLabel = hasPr ? 'PR' : 'No PR';
  final prExercises = await store.listPrExerciseNames(workout['id'] as String);
  final durationLabel = duration.inMinutes > 0 ? '${duration.inMinutes} min' : 'In progress';
  return _WorkoutSummary(
    durationLabel: durationLabel,
    setCount: setCount,
    prLabel: prLabel,
    prExercises: prExercises,
  );
}

class _SyncConflictsScreen extends StatelessWidget {
  const _SyncConflictsScreen();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final store = context.read<LocalStoreSqlite>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Conflicts')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sync.conflicts.length,
        itemBuilder: (context, index) {
          final conflict = sync.conflicts[index];
          return Card(
            child: ListTile(
              title: Text('${conflict.entity} ${conflict.id}'),
              subtitle: const Text('Choose which version to keep.'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => _ConflictDetailDialog(
                          conflict: conflict,
                          onKeepLocal: () async {
                            await store.keepLocal(conflict);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kept local for ${conflict.id}')),
                            );
                          },
                          onKeepServer: () async {
                            await store.keepServer(conflict);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kept server for ${conflict.id}')),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'local') {
                        await store.keepLocal(conflict);
                      } else {
                        await store.keepServer(conflict);
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Resolved ${conflict.id}')),
                      );
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'local', child: Text('Keep Local')),
                      PopupMenuItem(value: 'server', child: Text('Keep Server')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConflictDetailDialog extends StatelessWidget {
  const _ConflictDetailDialog({
    required this.conflict,
    required this.onKeepLocal,
    required this.onKeepServer,
  });

  final SyncConflict conflict;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepServer;

  @override
  Widget build(BuildContext context) {
    final keys = <String>{}
      ..addAll(conflict.client.keys)
      ..addAll(conflict.server.keys);
    final orderedKeys = keys.toList()..sort();
    return AlertDialog(
      title: Text('Conflict ${conflict.id}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Field Differences', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final key in orderedKeys)
              _ConflictDiffRow(
                field: key,
                localValue: conflict.client[key],
                serverValue: conflict.server[key],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        OutlinedButton(onPressed: onKeepLocal, child: const Text('Keep Local')),
        FilledButton(onPressed: onKeepServer, child: const Text('Keep Server')),
      ],
    );
  }
}

class _ConflictDiffRow extends StatelessWidget {
  const _ConflictDiffRow({
    required this.field,
    required this.localValue,
    required this.serverValue,
  });

  final String field;
  final Object? localValue;
  final Object? serverValue;

  @override
  Widget build(BuildContext context) {
    final different = '$localValue' != '$serverValue';
    final color = different ? Colors.amberAccent : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(field, style: TextStyle(color: color))),
          Expanded(child: Text('$localValue', style: TextStyle(color: color))),
          Expanded(child: Text('$serverValue', style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _WorkoutSessionScreen extends StatefulWidget {
  const _WorkoutSessionScreen({required this.workoutId});

  final String workoutId;

  @override
  State<_WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<_WorkoutSessionScreen>
    with SingleTickerProviderStateMixin {
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  String? _selectedExerciseId;
  bool _isPr = false;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Timer? _restTimer;
  int _restDuration = 90;
  int _restRemaining = 0;
  bool _restRunning = false;
  bool _autoRest = true;

  Timer? _hiitTimer;
  int _hiitWork = 40;
  int _hiitRest = 20;
  int _hiitRounds = 8;
  int _hiitRound = 1;
  String _hiitPhase = 'work';
  int _hiitRemaining = 0;
  bool _hiitRunning = false;
  late final AnimationController _completeController;
  late final Animation<double> _completeScale;
  bool _showComplete = false;

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _ticker?.cancel();
    _restTimer?.cancel();
    _hiitTimer?.cancel();
    _completeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _completeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _completeScale = CurvedAnimation(parent: _completeController, curve: Curves.easeOutBack);
  }

  Future<void> _logSet() async {
    HapticFeedback.selectionClick();
    final store = context.read<LocalStoreSqlite>();
    final service = WorkoutService(store);
    final weight = double.tryParse(_weight.text) ?? 0;
    final reps = int.tryParse(_reps.text) ?? 0;
    if (weight <= 0 || reps <= 0 || _selectedExerciseId == null) return;
    await service.logSet(
      workoutId: widget.workoutId,
      exerciseId: _selectedExerciseId!,
      weight: weight,
      reps: reps,
    );
    _isPr = await store.isWorkoutPr(widget.workoutId);
    _showComplete = true;
    _completeController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _showComplete = false);
    });
    if (!mounted) return;
    _weight.clear();
    _reps.clear();
    _startRestTimer(fromSet: true);
    setState(() {});
  }

  void _startRestTimer({bool fromSet = false}) {
    if (fromSet && !_autoRest) return;
    _restTimer?.cancel();
    setState(() {
      _restRunning = true;
      _restRemaining = _restDuration;
    });
    final cues = TimerCues(context.read<SettingsController>());
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_restRemaining <= 0) {
        timer.cancel();
        setState(() => _restRunning = false);
        await cues.playRestComplete();
        return;
      }
      setState(() => _restRemaining -= 1);
      if (_restRemaining == 5) {
        await cues.playWarning(5);
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() => _restRunning = false);
  }

  void _startHiit() {
    _hiitTimer?.cancel();
    setState(() {
      _hiitRunning = true;
      _hiitRound = 1;
      _hiitPhase = 'work';
      _hiitRemaining = _hiitWork;
    });
    final cues = TimerCues(context.read<SettingsController>());
    cues.playStart();
    _hiitTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_hiitRemaining <= 0) {
        if (_hiitPhase == 'work') {
          setState(() {
            _hiitPhase = 'rest';
            _hiitRemaining = _hiitRest;
          });
          await cues.playWarning(0);
        } else {
          if (_hiitRound >= _hiitRounds) {
            timer.cancel();
            setState(() => _hiitRunning = false);
            await cues.playRestComplete();
            return;
          }
          setState(() {
            _hiitRound += 1;
            _hiitPhase = 'work';
            _hiitRemaining = _hiitWork;
          });
          await cues.playStart();
        }
      } else {
        setState(() => _hiitRemaining -= 1);
        if (_hiitRemaining == 5) {
          await cues.playWarning(5);
        }
      }
    });
  }

  void _stopHiit() {
    _hiitTimer?.cancel();
    setState(() => _hiitRunning = false);
  }

  Future<void> _endSession() async {
    final store = context.read<LocalStoreSqlite>();
    final service = WorkoutService(store);
    await service.endWorkout(widget.workoutId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<LocalStoreSqlite>();
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    }
    final elapsed = _formatDuration(_stopwatch.elapsed);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Active Session'),
            Text(elapsed, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: store.listExercises(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('Add an exercise in Library to log sets.');
              }
              final items = snapshot.data!;
              _selectedExerciseId ??= items.first['id'] as String?;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedExerciseId,
                          isExpanded: true,
                          items: items
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item['id'] as String?,
                                  child: Text(item['name'] as String? ?? ''),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _selectedExerciseId = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_isPr)
                        const Chip(
                          label: Text('PR'),
                          avatar: Icon(Icons.emoji_events, size: 16),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _reps,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _logSet,
                  child: const Text('Finish Set'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _endSession,
                  child: const Text('End Session'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Rest Timer'),
              subtitle: Text(
                _restRunning
                    ? 'Resting · ${_formatDuration(Duration(seconds: _restRemaining))}'
                    : 'Set to $_restDuration sec',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _restRunning ? null : () => setState(() => _restDuration += 15),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    onPressed: _restRunning
                        ? null
                        : () => setState(() {
                              if (_restDuration > 30) _restDuration -= 15;
                            }),
                    icon: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _restRunning ? null : _startRestTimer,
                  child: const Text('Start Rest'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _restRunning ? _stopRestTimer : null,
                  child: const Text('Stop Rest'),
                ),
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Auto-start after Finish Set'),
            value: _autoRest,
            onChanged: (value) => setState(() => _autoRest = value),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('HIIT Chronometer'),
              subtitle: Text(
                _hiitRunning
                    ? 'Round $_hiitRound/$_hiitRounds · $_hiitPhase · ${_formatDuration(Duration(seconds: _hiitRemaining))}'
                    : 'Work $_hiitWork s · Rest $_hiitRest s · $_hiitRounds rounds',
              ),
              trailing: const Icon(Icons.timer_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _hiitRunning ? null : _startHiit,
                  child: const Text('Start HIIT'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _hiitRunning ? _stopHiit : null,
                  child: const Text('Stop HIIT'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberStepper(
                  label: 'Work',
                  value: _hiitWork,
                  onChanged: (value) => setState(() => _hiitWork = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberStepper(
                  label: 'Rest',
                  value: _hiitRest,
                  onChanged: (value) => setState(() => _hiitRest = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _NumberStepper(
            label: 'Rounds',
            value: _hiitRounds,
            min: 1,
            step: 1,
            onChanged: (value) => setState(() => _hiitRounds = value),
          ),
          const SizedBox(height: 16),
          Text('Set Log', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: store.listSets(widget.workoutId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sets = snapshot.data!;
              if (sets.isEmpty) {
                return const Center(child: Text('No sets logged yet.'));
              }
              return Column(
                children: [
                  for (var i = 0; i < sets.length; i++)
                    Card(
                      child: ListTile(
                        title: Text('${sets[i]['weight_kg']} kg x ${sets[i]['reps']} reps'),
                        subtitle: Text('Set ${i + 1}'),
                      ),
                    ),
                ],
              );
            },
          ),
            ],
          ),
          if (_showComplete)
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _completeController,
                  child: Center(
                    child: ScaleTransition(
                      scale: _completeScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCCFF00), width: 1.2),
                        ),
                        child: const Text('Set Complete'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 5,
    this.step = 5,
  });

  final String label;
  final int value;
  final int min;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final iconButtonStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      minimumSize: const Size(32, 32),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              style: iconButtonStyle,
              icon: const Icon(Icons.remove, size: 18),
              onPressed: value > min ? () => onChanged(value - step) : null,
            ),
            SizedBox(
              width: 60,
              child: Text(
                '$value s',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              style: iconButtonStyle,
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => onChanged(value + step),
            ),
          ],
        ),
      ),
    );
  }
}
