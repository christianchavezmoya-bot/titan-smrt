from sqlalchemy import Column, String, Boolean
from ..core.database import Base
from .base import BaseModelMixin

class Exercise(Base, BaseModelMixin):
    __tablename__ = "exercises"

    user_id = Column(String(36), nullable=True)
    name = Column(String(100), nullable=False)
    muscle_group = Column(String(50))
    equipment = Column(String(50))
    media_url = Column(String(255))
    media_type = Column(String(20))
    is_default = Column(Boolean, default=False)
