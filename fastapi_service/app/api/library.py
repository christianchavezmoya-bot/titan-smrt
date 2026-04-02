from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..core.auth import get_current_user
from ..core.database import get_db
from ..models.exercise import Exercise
from ..models.routine import Routine
from ..models.routine_exercise import RoutineExercise
from ..models.user import User
from ..schemas.library import (
    ExerciseCreate,
    ExerciseResponse,
    RoutineCreate,
    RoutineResponse,
    RoutineExerciseCreate,
    RoutineExerciseResponse,
    RoutineExerciseDefaultSetsUpdate,
)

router = APIRouter(tags=["library"])

@router.get("/exercises", response_model=list[ExerciseResponse])
def list_exercises(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[ExerciseResponse]:
    exercises = (
        db.query(Exercise)
        .filter((Exercise.user_id == current_user.id) | (Exercise.is_default == True))
        .all()
    )
    return [
        ExerciseResponse(
            id=ex.id,
            name=ex.name,
            muscle_group=ex.muscle_group,
            equipment=ex.equipment,
            media_url=ex.media_url,
            media_type=ex.media_type,
            is_default=ex.is_default,
        )
        for ex in exercises
    ]

@router.post("/exercises", response_model=ExerciseResponse)
def create_exercise(
    payload: ExerciseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ExerciseResponse:
    exercise = Exercise(
        user_id=current_user.id,
        name=payload.name,
        muscle_group=payload.muscle_group,
        equipment=payload.equipment,
        media_url=payload.media_url,
        media_type=payload.media_type,
        is_default=False,
    )
    db.add(exercise)
    db.commit()
    db.refresh(exercise)
    return ExerciseResponse(
        id=exercise.id,
        name=exercise.name,
        muscle_group=exercise.muscle_group,
        equipment=exercise.equipment,
        media_url=exercise.media_url,
        media_type=exercise.media_type,
        is_default=exercise.is_default,
    )

@router.get("/routines", response_model=list[RoutineResponse])
def list_routines(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[RoutineResponse]:
    routines = db.query(Routine).filter(Routine.user_id == current_user.id).all()
    return [
        RoutineResponse(id=r.id, name=r.name, difficulty_rating=r.difficulty_rating)
        for r in routines
    ]

@router.post("/routines", response_model=RoutineResponse)
def create_routine(
    payload: RoutineCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RoutineResponse:
    routine = Routine(
        user_id=current_user.id,
        name=payload.name,
        difficulty_rating=payload.difficulty_rating,
    )
    db.add(routine)
    db.commit()
    db.refresh(routine)
    return RoutineResponse(
        id=routine.id, name=routine.name, difficulty_rating=routine.difficulty_rating
    )


@router.get("/routines/{routine_id}/exercises", response_model=list[RoutineExerciseResponse])
def list_routine_exercises(
    routine_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[RoutineExerciseResponse]:
    routine = (
        db.query(Routine)
        .filter(Routine.id == routine_id, Routine.user_id == current_user.id)
        .first()
    )
    if not routine:
        return []
    exercises = (
        db.query(RoutineExercise, Exercise)
        .join(Exercise, Exercise.id == RoutineExercise.exercise_id)
        .filter(RoutineExercise.routine_id == routine_id)
        .order_by(RoutineExercise.display_order.asc())
        .all()
    )
    return [
        RoutineExerciseResponse(
            id=re.id,
            routine_id=re.routine_id,
            exercise_id=re.exercise_id,
            exercise_name=exercise.name,
            display_order=re.display_order or 0,
            default_sets=re.default_sets,
            media_url=exercise.media_url,
            media_type=exercise.media_type,
            muscle_group=exercise.muscle_group,
            equipment=exercise.equipment,
        )
        for re, exercise in exercises
    ]


@router.post("/routines/{routine_id}/exercises", response_model=RoutineExerciseResponse)
def add_routine_exercise(
    routine_id: str,
    payload: RoutineExerciseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RoutineExerciseResponse:
    routine = (
        db.query(Routine)
        .filter(Routine.id == routine_id, Routine.user_id == current_user.id)
        .first()
    )
    if not routine:
        return RoutineExerciseResponse(
            id="",
            routine_id=routine_id,
            exercise_id=payload.exercise_id,
            exercise_name="",
            display_order=0,
            default_sets=None,
        )
    count = (
        db.query(RoutineExercise)
        .filter(RoutineExercise.routine_id == routine_id)
        .count()
    )
    record = RoutineExercise(
        routine_id=routine_id,
        exercise_id=payload.exercise_id,
        display_order=count + 1,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    exercise = db.query(Exercise).filter(Exercise.id == payload.exercise_id).first()
    return RoutineExerciseResponse(
        id=record.id,
        routine_id=routine_id,
        exercise_id=payload.exercise_id,
        exercise_name=exercise.name if exercise else "",
        display_order=record.display_order or 0,
        default_sets=record.default_sets,
    )


@router.post("/routines/exercises/{routine_exercise_id}/delete")
def delete_routine_exercise(
    routine_exercise_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, bool]:
    record = (
        db.query(RoutineExercise)
        .join(Routine, Routine.id == RoutineExercise.routine_id)
        .filter(RoutineExercise.id == routine_exercise_id, Routine.user_id == current_user.id)
        .first()
    )
    if record:
        db.delete(record)
        db.commit()
    return {"success": True}


@router.post("/routines/exercises/{routine_exercise_id}/default_sets")
def update_routine_exercise_defaults(
    routine_exercise_id: str,
    payload: RoutineExerciseDefaultSetsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, bool]:
    record = (
        db.query(RoutineExercise)
        .join(Routine, Routine.id == RoutineExercise.routine_id)
        .filter(RoutineExercise.id == routine_exercise_id, Routine.user_id == current_user.id)
        .first()
    )
    if record:
        record.default_sets = payload.default_sets
        db.commit()
    return {"success": True}


@router.post("/routines/{routine_id}/reorder")
def reorder_routine_exercises(
    routine_id: str,
    payload: list[dict],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict[str, bool]:
    routine = (
        db.query(Routine)
        .filter(Routine.id == routine_id, Routine.user_id == current_user.id)
        .first()
    )
    if not routine:
        return {"success": False}
    for item in payload:
        routine_exercise_id = item.get("id")
        order = item.get("order")
        if not routine_exercise_id:
            continue
        record = (
            db.query(RoutineExercise)
            .filter(
                RoutineExercise.id == routine_exercise_id,
                RoutineExercise.routine_id == routine_id,
            )
            .first()
        )
        if record and isinstance(order, int):
            record.display_order = order
    db.commit()
    return {"success": True}
