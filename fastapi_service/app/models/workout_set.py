from sqlalchemy import Column, Float, Integer, String
from ..core.database import Base
from .base import BaseModelMixin

class WorkoutSet(Base, BaseModelMixin):
    __tablename__ = "workout_sets"

    workout_id = Column(String(36), nullable=False)
    exercise_id = Column(String(36), nullable=False)
    set_order = Column(Integer)
    weight_kg = Column(Float)
    reps = Column(Integer)
    rpe = Column(Integer)
    rest_time_seconds = Column(Integer)
    video_url = Column(String)
    form_confidence = Column(Float)
