from sqlalchemy import Column, Date, Float, String
from ..core.database import Base
from .base import BaseModelMixin

class NutritionLog(Base, BaseModelMixin):
    __tablename__ = "nutrition_logs"

    user_id = Column(String(36), nullable=False)
    date = Column(Date)
    protein = Column(Float)
    carbs = Column(Float)
    fats = Column(Float)
