from sqlalchemy import Column, DateTime, Float, String
from ..core.database import Base
from .base import BaseModelMixin

class Workout(Base, BaseModelMixin):
    __tablename__ = "workouts"

    user_id = Column(String(36), nullable=False)
    routine_id = Column(String(36), nullable=True)
    start_time = Column(DateTime(timezone=True))
    end_time = Column(DateTime(timezone=True))
    total_volume = Column(Float)
    notes = Column(String)
    ai_insight = Column(String)
    form_score_average = Column(Float)
