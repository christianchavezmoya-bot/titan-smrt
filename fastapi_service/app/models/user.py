from sqlalchemy import Column, String
from ..core.database import Base
from .base import BaseModelMixin

class User(Base, BaseModelMixin):
    __tablename__ = "users"

    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    subscription_type = Column(String(20), default="free")
