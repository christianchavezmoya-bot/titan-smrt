from pydantic import BaseModel
from typing import Optional

class ExerciseCreate(BaseModel):
    name: str
    muscle_group: Optional[str] = None
    equipment: Optional[str] = None
    media_url: Optional[str] = None
    media_type: Optional[str] = None

class ExerciseResponse(BaseModel):
    id: str
    name: str
    muscle_group: Optional[str] = None
    equipment: Optional[str] = None
    media_url: Optional[str] = None
    media_type: Optional[str] = None
    is_default: bool

class RoutineCreate(BaseModel):
    name: str
    difficulty_rating: Optional[int] = None

class RoutineResponse(BaseModel):
    id: str
    name: str
    difficulty_rating: Optional[int] = None


class RoutineExerciseCreate(BaseModel):
    exercise_id: str


class RoutineExerciseResponse(BaseModel):
    id: str
    routine_id: str
    exercise_id: str
    exercise_name: str
    display_order: int
    default_sets: Optional[str] = None
    media_url: Optional[str] = None
    media_type: Optional[str] = None
    muscle_group: Optional[str] = None
    equipment: Optional[str] = None


class RoutineExerciseDefaultSetsUpdate(BaseModel):
    default_sets: Optional[str] = None
