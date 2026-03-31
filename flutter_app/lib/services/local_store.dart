import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'sync_service.dart';

class LocalStoreSqlite implements LocalStore {
  LocalStoreSqlite._(this._db, this._lastSyncAt);

  final Database _db;
  DateTime? _lastSyncAt;

  static Future<LocalStoreSqlite> open() async {
    final dbPath = await getDatabasesPath();
    final database = await openDatabase(
      path.join(dbPath, 'titan.db'),
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE workouts (
            id TEXT PRIMARY KEY,
            routine_id TEXT,
            start_time TEXT,
            end_time TEXT,
            total_volume REAL,
            notes TEXT,
            ai_insight TEXT,
            form_score_average REAL,
            updated_at TEXT,
            is_dirty INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE workout_sets (
            id TEXT PRIMARY KEY,
            workout_id TEXT,
            exercise_id TEXT,
            set_order INTEGER,
            weight_kg REAL,
            reps INTEGER,
            rpe INTEGER,
            rest_time_seconds INTEGER,
            video_url TEXT,
            form_confidence REAL,
            updated_at TEXT,
            is_dirty INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE routines (
            id TEXT PRIMARY KEY,
            name TEXT,
            difficulty_rating INTEGER,
            updated_at TEXT,
            is_dirty INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE routine_exercises (
            id TEXT PRIMARY KEY,
            routine_id TEXT,
            exercise_id TEXT,
            display_order INTEGER,
            default_sets TEXT,
            updated_at TEXT,
            is_dirty INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE exercises (
            id TEXT PRIMARY KEY,
            name TEXT,
            muscle_group TEXT,
            equipment TEXT,
            media_url TEXT,
            media_type TEXT,
            updated_at TEXT,
            is_dirty INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_reorders (
            id TEXT PRIMARY KEY,
            routine_id TEXT,
            payload TEXT,
            updated_at TEXT,
            is_dirty INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE conflict_audit (
            id TEXT PRIMARY KEY,
            entity TEXT,
            entity_id TEXT,
            resolution TEXT,
            local_snapshot TEXT,
            server_snapshot TEXT,
            created_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE routine_exercises (
              id TEXT PRIMARY KEY,
              routine_id TEXT,
              exercise_id TEXT,
              display_order INTEGER,
              updated_at TEXT,
              is_dirty INTEGER DEFAULT 0
            )
          ''');
          await db.execute('ALTER TABLE exercises ADD COLUMN muscle_group TEXT');
          await db.execute('ALTER TABLE exercises ADD COLUMN equipment TEXT');
          await db.execute('''
            CREATE TABLE pending_reorders (
              id TEXT PRIMARY KEY,
              routine_id TEXT,
              payload TEXT,
              updated_at TEXT,
              is_dirty INTEGER DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE routine_exercises ADD COLUMN default_sets TEXT');
          await db.execute('''
            CREATE TABLE conflict_audit (
              id TEXT PRIMARY KEY,
              entity TEXT,
              entity_id TEXT,
              resolution TEXT,
              local_snapshot TEXT,
              server_snapshot TEXT,
              created_at TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE exercises ADD COLUMN media_url TEXT');
          await db.execute('ALTER TABLE exercises ADD COLUMN media_type TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE conflict_audit ADD COLUMN local_snapshot TEXT');
          await db.execute('ALTER TABLE conflict_audit ADD COLUMN server_snapshot TEXT');
        }
      },
    );

    final meta = await database.query('sync_meta', where: 'key = ?', whereArgs: ['last_sync_at']);
    DateTime? lastSyncAt;
    if (meta.isNotEmpty && meta.first['value'] != null) {
      lastSyncAt = DateTime.tryParse(meta.first['value'] as String);
    }

    return LocalStoreSqlite._(database, lastSyncAt);
  }

  @override
  DateTime? get lastSyncAt => _lastSyncAt;

  @override
  Future<Map<String, List<Map<String, dynamic>>>> dumpDirtyEntities() async {
    final workouts = await _db.query('workouts', where: 'is_dirty = 1');
    final workoutSets = await _db.query('workout_sets', where: 'is_dirty = 1');
    final routines = await _db.query('routines', where: 'is_dirty = 1');
    final routineExercises = await _db.query('routine_exercises', where: 'is_dirty = 1');
    final exercises = await _db.query('exercises', where: 'is_dirty = 1');

    return {
      'workouts': workouts,
      'workout_sets': workoutSets,
      'routines': routines,
      'routine_exercises': routineExercises,
      'exercises': exercises,
    };
  }

  @override
  Future<void> resolveConflicts(List<SyncConflict> conflicts) async {
    if (conflicts.isEmpty) {
      return;
    }
    // Placeholder: keep server version, do not modify local.
  }

  @override
  Future<void> keepLocal(SyncConflict conflict) async {
    final entity = conflict.entity;
    if (!_isKnownTable(entity)) return;
    final data = Map<String, Object?>.from(conflict.client);
    data['is_dirty'] = 1;
    await _db.insert(entity, data, conflictAlgorithm: ConflictAlgorithm.replace);
    await _logConflictResolution(conflict, 'local');
  }

  @override
  Future<void> keepServer(SyncConflict conflict) async {
    final entity = conflict.entity;
    if (!_isKnownTable(entity)) return;
    final data = Map<String, Object?>.from(conflict.server);
    data['is_dirty'] = 0;
    await _db.insert(entity, data, conflictAlgorithm: ConflictAlgorithm.replace);
    await _logConflictResolution(conflict, 'server');
  }

  @override
  Future<void> applyServerUpdates(List<Map<String, dynamic>> updates) async {
    for (final update in updates) {
      final entity = update['entity'] as String?;
      final data = update['data'] as Map<String, dynamic>?;
      if (entity == null || data == null) {
        continue;
      }
      await _db.insert(entity, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<void> markSynced() async {
    await _db.update('workouts', {'is_dirty': 0});
    await _db.update('workout_sets', {'is_dirty': 0});
    await _db.update('routines', {'is_dirty': 0});
    await _db.update('routine_exercises', {'is_dirty': 0});
    await _db.update('exercises', {'is_dirty': 0});

    _lastSyncAt = DateTime.now().toUtc();
    await _db.insert(
      'sync_meta',
      {'key': 'last_sync_at', 'value': _lastSyncAt!.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  bool _isKnownTable(String name) {
    return {
      'workouts',
      'workout_sets',
      'routines',
      'routine_exercises',
      'exercises',
    }.contains(name);
  }

  Future<void> _logConflictResolution(SyncConflict conflict, String resolution) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      'conflict_audit',
      {
        'id': const Uuid().v4(),
        'entity': conflict.entity,
        'entity_id': conflict.id,
        'resolution': resolution,
        'local_snapshot': jsonEncode(conflict.client),
        'server_snapshot': jsonEncode(conflict.server),
        'created_at': now,
      },
    );
  }

  Future<String> createExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('exercises', {
      'id': id,
      'name': name,
      'muscle_group': muscleGroup,
      'equipment': equipment,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'updated_at': now,
      'is_dirty': 1,
    });
    return id;
  }

  Future<void> updateExercise({
    required String id,
    required String name,
    String? muscleGroup,
    String? equipment,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'exercises',
      {
        'name': name,
        'muscle_group': muscleGroup,
        'equipment': equipment,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'updated_at': now,
        'is_dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExercise(String id) async {
    await _db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> listExercises() async {
    return _db.query('exercises', orderBy: 'name ASC');
  }

  Future<String> createRoutine({
    required String name,
    int? difficultyRating,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('routines', {
      'id': id,
      'name': name,
      'difficulty_rating': difficultyRating,
      'updated_at': now,
      'is_dirty': 1,
    });
    return id;
  }

  Future<void> updateRoutine({
    required String id,
    required String name,
    int? difficultyRating,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'routines',
      {
        'name': name,
        'difficulty_rating': difficultyRating,
        'updated_at': now,
        'is_dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRoutine(String id) async {
    await _db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> listRoutines() async {
    return _db.query('routines', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> listRoutineExercises(String routineId) async {
    return _db.rawQuery('''
      SELECT re.id, re.routine_id, re.exercise_id, re.display_order, re.default_sets,
             e.name AS exercise_name
      FROM routine_exercises re
      LEFT JOIN exercises e ON e.id = re.exercise_id
      WHERE re.routine_id = ?
      ORDER BY re.display_order ASC
    ''', [routineId]);
  }

  Future<String> addRoutineExercise({
    required String routineId,
    required String exerciseId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final count = Sqflite.firstIntValue(await _db.rawQuery(
          'SELECT COUNT(*) FROM routine_exercises WHERE routine_id = ?',
          [routineId],
        )) ??
        0;
    await _db.insert('routine_exercises', {
      'id': id,
      'routine_id': routineId,
      'exercise_id': exerciseId,
      'display_order': count + 1,
      'default_sets': null,
      'updated_at': now,
      'is_dirty': 1,
    });
    return id;
  }

  Future<void> updateRoutineExercise({
    required String id,
    int? displayOrder,
    String? defaultSets,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = <String, Object?>{
      'updated_at': now,
      'is_dirty': 1,
    };
    if (displayOrder != null) {
      data['display_order'] = displayOrder;
    }
    if (defaultSets != null) {
      data['default_sets'] = defaultSets;
    }
    await _db.update(
      'routine_exercises',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reorderRoutineExercise({
    required String id,
    required int newOrder,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'routine_exercises',
      {
        'display_order': newOrder,
        'updated_at': now,
        'is_dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRoutineExercise(String id) async {
    await _db.delete('routine_exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> createWorkout({String? routineId}) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('workouts', {
      'id': id,
      'routine_id': routineId,
      'start_time': now,
      'updated_at': now,
      'is_dirty': 1,
      'total_volume': 0.0,
    });
    return id;
  }

  Future<void> endWorkout(String workoutId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'workouts',
      {'end_time': now, 'updated_at': now, 'is_dirty': 1},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<void> addSet({
    required String workoutId,
    required String exerciseId,
    required double weight,
    required int reps,
    int? rpe,
    int? restTimeSeconds,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert('workout_sets', {
      'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'set_order': 0,
      'weight_kg': weight,
      'reps': reps,
      'rpe': rpe,
      'rest_time_seconds': restTimeSeconds,
      'updated_at': now,
      'is_dirty': 1,
    });

    final workout = await _db.query('workouts', where: 'id = ?', whereArgs: [workoutId]);
    if (workout.isNotEmpty) {
      final total = (workout.first['total_volume'] as num?)?.toDouble() ?? 0.0;
      final newTotal = total + (weight * reps);
      await _db.update(
        'workouts',
        {'total_volume': newTotal, 'updated_at': now, 'is_dirty': 1},
        where: 'id = ?',
        whereArgs: [workoutId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> listWorkouts() async {
    return _db.query('workouts', orderBy: 'start_time DESC');
  }

  Future<List<Map<String, dynamic>>> listSets(String workoutId) async {
    return _db.query('workout_sets', where: 'workout_id = ?', whereArgs: [workoutId]);
  }

  Future<int> countSets(String workoutId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM workout_sets WHERE workout_id = ?',
      [workoutId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<double> maxSetWeight(String exerciseId) async {
    final result = await _db.rawQuery(
      'SELECT MAX(weight_kg) as max_weight FROM workout_sets WHERE exercise_id = ?',
      [exerciseId],
    );
    return (result.first['max_weight'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> maxEstimatedOneRm(String exerciseId) async {
    final result = await _db.rawQuery(
      'SELECT MAX(weight_kg * (1 + reps / 30.0)) as max_rm FROM workout_sets WHERE exercise_id = ?',
      [exerciseId],
    );
    return (result.first['max_rm'] as num?)?.toDouble() ?? 0.0;
  }

  Future<bool> isWorkoutPr(String workoutId) async {
    final sets = await _db.query(
      'workout_sets',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
    for (final set in sets) {
      final exerciseId = set['exercise_id'] as String?;
      if (exerciseId == null) continue;
      final weight = (set['weight_kg'] as num?)?.toDouble() ?? 0.0;
      final reps = (set['reps'] as num?)?.toDouble() ?? 0.0;
      if (weight <= 0 || reps <= 0) continue;
      final estimate = weight * (1 + reps / 30.0);
      final prevMax = await _maxEstimatedOneRmBefore(exerciseId, workoutId);
      if (estimate > prevMax) {
        return true;
      }
    }
    return false;
  }

  Future<List<String>> listPrExerciseNames(String workoutId) async {
    final sets = await _db.rawQuery(
      '''
      SELECT ws.exercise_id, ws.weight_kg, ws.reps, e.name AS exercise_name
      FROM workout_sets ws
      LEFT JOIN exercises e ON e.id = ws.exercise_id
      WHERE ws.workout_id = ?
      ''',
      [workoutId],
    );
    final maxByExercise = <String, double>{};
    final nameByExercise = <String, String>{};
    for (final set in sets) {
      final exerciseId = set['exercise_id'] as String?;
      if (exerciseId == null) continue;
      final weight = (set['weight_kg'] as num?)?.toDouble() ?? 0.0;
      final reps = (set['reps'] as num?)?.toDouble() ?? 0.0;
      if (weight <= 0 || reps <= 0) continue;
      final estimate = weight * (1 + reps / 30.0);
      maxByExercise[exerciseId] = (maxByExercise[exerciseId] ?? 0.0).clamp(0.0, double.infinity);
      if (estimate > maxByExercise[exerciseId]!) {
        maxByExercise[exerciseId] = estimate;
      }
      nameByExercise[exerciseId] = set['exercise_name'] as String? ?? 'Unknown';
    }

    final prNames = <String>[];
    for (final entry in maxByExercise.entries) {
      final prevMax = await _maxEstimatedOneRmBefore(entry.key, workoutId);
      if (entry.value > prevMax) {
        prNames.add(nameByExercise[entry.key] ?? 'Unknown');
      }
    }
    return prNames;
  }

  Future<List<Map<String, dynamic>>> listExercisePrLeaderboard() async {
    return _db.rawQuery('''
      SELECT e.name AS exercise_name,
             MAX(ws.weight_kg * (1 + ws.reps / 30.0)) AS max_rm
      FROM workout_sets ws
      LEFT JOIN exercises e ON e.id = ws.exercise_id
      GROUP BY ws.exercise_id, e.name
      ORDER BY max_rm DESC
      LIMIT 10
    ''');
  }

  Future<double> _maxEstimatedOneRmBefore(String exerciseId, String workoutId) async {
    final result = await _db.rawQuery(
      '''
      SELECT MAX(weight_kg * (1 + reps / 30.0)) as max_rm
      FROM workout_sets
      WHERE exercise_id = ? AND workout_id != ?
      ''',
      [exerciseId, workoutId],
    );
    return (result.first['max_rm'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> queueRoutineReorder(String routineId, String payload) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.insert(
      'pending_reorders',
      {
        'id': const Uuid().v4(),
        'routine_id': routineId,
        'payload': payload,
        'updated_at': now,
        'is_dirty': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> listPendingReorders() async {
    return _db.query('pending_reorders', where: 'is_dirty = 1');
  }

  Future<void> clearPendingReorder(String id) async {
    await _db.delete('pending_reorders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> listConflictAudit() async {
    return _db.query('conflict_audit', orderBy: 'created_at DESC');
  }

  Future<void> clearConflictAudit() async {
    await _db.delete('conflict_audit');
  }
}
