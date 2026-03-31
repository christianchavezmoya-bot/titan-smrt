from sqlalchemy import Column, Integer, String
from ..core.database import Base
from .base import BaseModelMixin

class Routine(Base, BaseModelMixin):
    __tablename__ = "routines"

    user_id = Column(String(36), nullable=False)
    name = Column(String(100), nullable=False)
    difficulty_rating = Column(Integer)
