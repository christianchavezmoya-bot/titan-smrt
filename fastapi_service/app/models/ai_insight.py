from sqlalchemy import Column, Date, Float, String
from ..core.database import Base
from .base import BaseModelMixin

class AIInsight(Base, BaseModelMixin):
    __tablename__ = "ai_insights"

    user_id = Column(String(36), nullable=False)
    date = Column(Date)
    insight_type = Column(String(50))
    actionable_advice = Column(String(500))
    confidence_score = Column(Float)
