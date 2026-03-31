from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..schemas.workout import (
    WorkoutStartRequest,
    WorkoutStartResponse,
    LogSetRequest,
    LogSetResponse,
    EndWorkoutRequest,
    EndWorkoutResponse,
    ProgressionRequest,
    ProgressionResponse,
)
from ..core.database import get_db
from ..core.auth import get_current_user
from ..models.workout import Workout
from ..models.workout_set import WorkoutSet
from ..models.user import User
from ..models.exercise import Exercise
from ..models.ai_insight import AIInsight

router = APIRouter(prefix="/workout", tags=["workout"])

@router.post("/start", response_model=WorkoutStartResponse)
def start_workout(
    payload: WorkoutStartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> WorkoutStartResponse:
    workout = Workout(
        user_id=current_user.id,
        routine_id=payload.routine_id,
        start_time=datetime.utcnow(),
    )
    db.add(workout)
    db.commit()
    db.refresh(workout)
    return WorkoutStartResponse(workout_id=workout.id, suggested_exercises=[])

@router.post("/log-set", response_model=LogSetResponse)
def log_set(
    payload: LogSetRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LogSetResponse:
    workout = db.query(Workout).filter(Workout.id == payload.workout_id).first()
    if not workout or workout.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workout not found")
    new_set = WorkoutSet(
        workout_id=payload.workout_id,
        exercise_id=payload.exercise_id,
        weight_kg=payload.weight,
        reps=payload.reps,
        rpe=payload.rpe,
        rest_time_seconds=payload.rest_time_seconds,
    )
    db.add(new_set)
    db.flush()
    volume_increment = payload.weight * payload.reps
    workout.total_volume = (workout.total_volume or 0.0) + volume_increment
    db.commit()
    return LogSetResponse(success=True, updated_volume=workout.total_volume or 0.0)

@router.post("/end", response_model=EndWorkoutResponse)
def end_workout(
    payload: EndWorkoutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> EndWorkoutResponse:
    workout = db.query(Workout).filter(Workout.id == payload.workout_id).first()
    if not workout or workout.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workout not found")
    workout.end_time = datetime.utcnow()
    db.commit()
    return EndWorkoutResponse(
        summary="Session complete",
        form_score_average=workout.form_score_average or 0.0,
        ai_insight=workout.ai_insight or "",
    )


@router.post("/analyze_progression", response_model=ProgressionResponse)
def analyze_progression(
    payload: ProgressionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProgressionResponse:
    if payload.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    exercise = db.query(Exercise).filter(Exercise.name == payload.exercise_name).first()
    if not exercise:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exercise not found")
    workout_id_rows = (
        db.query(WorkoutSet.workout_id)
        .join(Workout, Workout.id == WorkoutSet.workout_id)
        .filter(Workout.user_id == current_user.id, WorkoutSet.exercise_id == exercise.id)
        .order_by(WorkoutSet.created_at.desc())
        .distinct()
        .limit(6)
        .all()
    )
    workout_ids = [row[0] for row in workout_id_rows]
    if len(workout_ids) < 6:
        return ProgressionResponse(status="gaining", message="Not enough data yet.")

    one_rm_values: list[float] = []
    for workout_id in workout_ids:
        sets = (
            db.query(WorkoutSet)
            .filter(WorkoutSet.workout_id == workout_id, WorkoutSet.exercise_id == exercise.id)
            .all()
        )
        if not sets:
            continue
        session_max = max(s.weight_kg * (1 + (s.reps or 0) / 30) for s in sets)
        one_rm_values.append(session_max)

    if len(one_rm_values) < 6:
        return ProgressionResponse(status="gaining", message="Not enough data yet.")

    recent_avg = sum(one_rm_values[:3]) / 3
    prior_avg = sum(one_rm_values[3:6]) / 3
    if recent_avg < prior_avg:
        response = ProgressionResponse(
            status="stagnant",
            message=f"Your strength on {payload.exercise_name} has plateaued.",
            suggestion="Increase intensity by adding 2.5kg or decrease rest intervals to 90s.",
        )
        insight_type = "plateau"
    else:
        response = ProgressionResponse(status="gaining", message="You are progressing!")
        insight_type = "progress"

    insight = AIInsight(
        user_id=current_user.id,
        date=datetime.utcnow().date(),
        insight_type=insight_type,
        actionable_advice=response.suggestion or response.message,
        confidence_score=0.7,
    )
    db.add(insight)
    db.commit()

    return response
