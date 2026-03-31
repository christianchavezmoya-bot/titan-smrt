from sqlalchemy import Column, Integer, String
from ..core.database import Base
from .base import BaseModelMixin

class RoutineExercise(Base, BaseModelMixin):
    __tablename__ = "routine_exercises"

    routine_id = Column(String(36), nullable=False)
    exercise_id = Column(String(36), nullable=False)
    display_order = Column(Integer, default=0)
    default_sets = Column(String(500))
