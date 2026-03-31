import 'local_store.dart';

class OfflineLibraryService {
  OfflineLibraryService(this._store);

  final LocalStoreSqlite _store;

  Future<List<Map<String, dynamic>>> listExercises() => _store.listExercises();

  Future<List<Map<String, dynamic>>> listRoutines() => _store.listRoutines();

  Future<String> createExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
    String? mediaUrl,
    String? mediaType,
  }) {
    return _store.createExercise(
      name: name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
  }

  Future<String> createRoutine({required String name, int? difficultyRating}) {
    return _store.createRoutine(name: name, difficultyRating: difficultyRating);
  }

  Future<void> updateExercise({
    required String id,
    required String name,
    String? muscleGroup,
    String? equipment,
    String? mediaUrl,
    String? mediaType,
  }) {
    return _store.updateExercise(
      id: id,
      name: name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
  }

  Future<void> updateRoutine({
    required String id,
    required String name,
    int? difficultyRating,
  }) {
    return _store.updateRoutine(
      id: id,
      name: name,
      difficultyRating: difficultyRating,
    );
  }

  Future<void> deleteExercise(String id) => _store.deleteExercise(id);

  Future<void> deleteRoutine(String id) => _store.deleteRoutine(id);

  Future<List<Map<String, dynamic>>> listRoutineExercises(String routineId) {
    return _store.listRoutineExercises(routineId);
  }

  Future<String> addRoutineExercise({
    required String routineId,
    required String exerciseId,
  }) {
    return _store.addRoutineExercise(routineId: routineId, exerciseId: exerciseId);
  }

  Future<void> updateRoutineExercise({
    required String id,
    int? displayOrder,
    String? defaultSets,
  }) {
    return _store.updateRoutineExercise(
      id: id,
      displayOrder: displayOrder,
      defaultSets: defaultSets,
    );
  }

  Future<void> reorderRoutineExercise({
    required String id,
    required int newOrder,
  }) {
    return _store.reorderRoutineExercise(id: id, newOrder: newOrder);
  }

  Future<void> deleteRoutineExercise(String id) => _store.deleteRoutineExercise(id);
}
