from datetime import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..schemas.sync import SyncRequest, SyncResponse
from ..core.auth import get_current_user
from ..core.database import get_db
from ..models.user import User
from ..models.workout import Workout
from ..models.workout_set import WorkoutSet
from ..models.routine import Routine
from ..models.routine_exercise import RoutineExercise
from ..models.exercise import Exercise

router = APIRouter(prefix="/sync", tags=["sync"])

@router.post("", response_model=SyncResponse)
def sync(
    payload: SyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SyncResponse:
    conflicts: list[dict] = []

    def parse_ts(value: str | None) -> datetime | None:
        if not value:
            return None
        clean = value.replace("Z", "+00:00")
        return datetime.fromisoformat(clean)

    def upsert(
        model,
        incoming: dict,
        allowed_fields: set[str],
        owner_field: str | None,
    ):
        incoming_id = incoming.get("id")
        incoming_updated_at = parse_ts(incoming.get("updated_at"))
        existing = db.query(model).filter(model.id == incoming_id).first() if incoming_id else None

        if existing and existing.updated_at and incoming_updated_at:
            if existing.updated_at > incoming_updated_at:
                conflicts.append(
                    {
                        "entity": model.__tablename__,
                        "id": existing.id,
                        "server": {k: getattr(existing, k) for k in allowed_fields},
                        "client": incoming,
                    }
                )
                return

        if not existing:
            record = model()
            if incoming_id:
                record.id = incoming_id
            if owner_field:
                setattr(record, owner_field, current_user.id)
            for key in allowed_fields:
                if key in incoming:
                    value = incoming[key]
                    if isinstance(value, str) and key.endswith("_time"):
                        value = parse_ts(value)
                    setattr(record, key, value)
            db.add(record)
        else:
            for key in allowed_fields:
                if key in incoming:
                    value = incoming[key]
                    if isinstance(value, str) and key.endswith("_time"):
                        value = parse_ts(value)
                    setattr(existing, key, value)

    for workout in payload.entities.get("workouts", []):
        upsert(
            Workout,
            workout,
            {
                "routine_id",
                "start_time",
                "end_time",
                "total_volume",
                "notes",
                "ai_insight",
                "form_score_average",
            },
            "user_id",
        )

    for workout_set in payload.entities.get("workout_sets", []):
        workout_owner = db.query(Workout).filter(
            Workout.id == workout_set.get("workout_id"),
            Workout.user_id == current_user.id,
        ).first()
        if not workout_owner:
            conflicts.append(
                {
                    "entity": "workout_sets",
                    "id": workout_set.get("id", ""),
                    "server": {},
                    "client": workout_set,
                }
            )
            continue
        upsert(
            WorkoutSet,
            workout_set,
            {
                "workout_id",
                "exercise_id",
                "set_order",
                "weight_kg",
                "reps",
                "rpe",
                "rest_time_seconds",
                "video_url",
                "form_confidence",
            },
            None,
        )

    for routine in payload.entities.get("routines", []):
        upsert(
            Routine,
            routine,
            {
                "name",
                "difficulty_rating",
            },
            "user_id",
        )

    for exercise in payload.entities.get("exercises", []):
        upsert(
            Exercise,
            exercise,
            {
                "name",
                "muscle_group",
                "equipment",
                "media_url",
                "media_type",
                "is_default",
            },
            "user_id",
        )

    for routine_exercise in payload.entities.get("routine_exercises", []):
        routine_owner = db.query(Routine).filter(
            Routine.id == routine_exercise.get("routine_id"),
            Routine.user_id == current_user.id,
        ).first()
        if not routine_owner:
            conflicts.append(
                {
                    "entity": "routine_exercises",
                    "id": routine_exercise.get("id", ""),
                    "server": {},
                    "client": routine_exercise,
                }
            )
            continue
        upsert(
            RoutineExercise,
            routine_exercise,
            {
                "routine_id",
                "exercise_id",
                "display_order",
                "default_sets",
            },
            None,
        )

    db.commit()
    return SyncResponse(conflicts=conflicts, updated_entities=[])
