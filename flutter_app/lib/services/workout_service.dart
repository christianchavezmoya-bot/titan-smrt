import 'package:uuid/uuid.dart';
import 'local_store.dart';

class WorkoutService {
  WorkoutService(this._store);

  final LocalStoreSqlite _store;

  Future<String> startWorkout({String? routineId}) {
    return _store.createWorkout(routineId: routineId);
  }

  Future<void> logSet({
    required String workoutId,
    required String exerciseId,
    required double weight,
    required int reps,
    int? rpe,
    int? restTimeSeconds,
  }) {
    return _store.addSet(
      workoutId: workoutId,
      exerciseId: exerciseId,
      weight: weight,
      reps: reps,
      rpe: rpe,
      restTimeSeconds: restTimeSeconds,
    );
  }

  Future<void> endWorkout(String workoutId) {
    return _store.endWorkout(workoutId);
  }
}
