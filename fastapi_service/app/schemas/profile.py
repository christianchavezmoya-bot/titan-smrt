from typing import Optional
from pydantic import BaseModel


class UserProfileRequest(BaseModel):
    age: Optional[int] = None
    sex: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    goal_type: Optional[str] = None
    experience_level: Optional[str] = None
    equipment_access: Optional[str] = None
    training_days_per_week: Optional[int] = None
    injury_notes: Optional[str] = None


class UserProfileResponse(UserProfileRequest):
    user_id: str
