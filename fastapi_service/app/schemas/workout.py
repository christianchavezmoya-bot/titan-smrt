from typing import Optional

from pydantic import BaseModel
from typing import Optional

class WorkoutStartRequest(BaseModel):
    routine_id: Optional[str] = None

class WorkoutStartResponse(BaseModel):
    workout_id: str
    suggested_exercises: list[str]

class LogSetRequest(BaseModel):
    workout_id: str
    exercise_id: str
    weight: float
    reps: int
    rpe: Optional[int] = None
    rest_time_seconds: Optional[int] = None

class LogSetResponse(BaseModel):
    success: bool
    updated_volume: float

class EndWorkoutRequest(BaseModel):
    workout_id: str

class EndWorkoutResponse(BaseModel):
    summary: str
    form_score_average: float
    ai_insight: str


class ProgressionRequest(BaseModel):
    user_id: str
    exercise_name: str


class ProgressionResponse(BaseModel):
    status: str
    message: str
    suggestion: Optional[str] = None
