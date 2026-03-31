from sqlalchemy import Column, Integer, String, Float
from ..core.database import Base
from .base import BaseModelMixin


class UserProfile(Base, BaseModelMixin):
    __tablename__ = "user_profiles"

    user_id = Column(String(36), nullable=False, unique=True)
    age = Column(Integer)
    sex = Column(String(20))
    height_cm = Column(Float)
    weight_kg = Column(Float)
    goal_type = Column(String(30))
    experience_level = Column(String(30))
    equipment_access = Column(String(30))
    training_days_per_week = Column(Integer)
    injury_notes = Column(String(255))
