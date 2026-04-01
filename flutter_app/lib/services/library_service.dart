import 'dart:convert';
import 'api_client.dart';

class LibraryService {
  LibraryService(this._client);

  final ApiClient _client;

  Future<List<ExerciseDto>> fetchExercises() async {
    final response = await _client.getJson('/v1/exercises');
    if (response.statusCode != 200) {
      throw Exception('Failed to load exercises');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ExerciseDto.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<RoutineDto>> fetchRoutines() async {
    final response = await _client.getJson('/v1/routines');
    if (response.statusCode != 200) {
      throw Exception('Failed to load routines');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => RoutineDto.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<RoutineExerciseDto>> fetchRoutineExercises(String routineId) async {
    final response = await _client.getJson('/v1/routines/$routineId/exercises');
    if (response.statusCode != 200) {
      throw Exception('Failed to load routine exercises');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => RoutineExerciseDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addExerciseToRoutine(String routineId, String exerciseId) async {
    final response = await _client.postJson(
      '/v1/routines/$routineId/exercises',
      {'exercise_id': exerciseId},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add exercise to routine');
    }
  }

  Future<void> removeRoutineExercise(String routineExerciseId) async {
    final response = await _client.postJson(
      '/v1/routines/exercises/$routineExerciseId/delete',
      {},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove exercise');
    }
  }

  Future<void> reorderRoutineExercises(String routineId, List<Map<String, dynamic>> payload) async {
    final response = await _client.postJson('/v1/routines/$routineId/reorder', payload);
    if (response.statusCode != 200) {
      throw Exception('Failed to reorder routine');
    }
  }

  Future<void> updateRoutineExerciseDefaultSets(String routineExerciseId, String? defaultSets) async {
    final response = await _client.postJson(
      '/v1/routines/exercises/$routineExerciseId/default_sets',
      {'default_sets': defaultSets},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update default sets');
    }
  }
}

class ExerciseDto {
  ExerciseDto({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.equipment,
    this.mediaUrl,
    this.mediaType,
  });

  final String id;
  final String name;
  final String? muscleGroup;
  final String? equipment;
  final String? mediaUrl;
  final String? mediaType;

  factory ExerciseDto.fromJson(Map<String, dynamic> json) {
    return ExerciseDto(
      id: json['id'] as String,
      name: json['name'] as String,
      muscleGroup: json['muscle_group'] as String?,
      equipment: json['equipment'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }
}

class RoutineDto {
  RoutineDto({required this.id, required this.name, required this.difficulty});

  final String id;
  final String name;
  final int? difficulty;

  factory RoutineDto.fromJson(Map<String, dynamic> json) {
    return RoutineDto(
      id: json['id'] as String,
      name: json['name'] as String,
      difficulty: json['difficulty_rating'] as int?,
    );
  }
}

class RoutineExerciseDto {
  RoutineExerciseDto({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.displayOrder,
    this.defaultSets,
  });

  final String id;
  final String exerciseId;
  final String exerciseName;
  final int displayOrder;
  final String? defaultSets;

  factory RoutineExerciseDto.fromJson(Map<String, dynamic> json) {
    return RoutineExerciseDto(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
      defaultSets: json['default_sets'] as String?,
    );
  }
}
