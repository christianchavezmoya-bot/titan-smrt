import os
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings with environment variable support."""

    # API Settings
    API_V1_PREFIX: str = "/v1"
    PROJECT_NAME: str = "Titan API"
    VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days

    # Database — overridden by DATABASE_URL env var in production
    DATABASE_URL: str = "sqlite:///./titan.db"

    # CORS — allow all origins (mobile app uses direct IP, not a browser origin)
    BACKEND_CORS_ORIGINS: list[str] = ["*"]

    # File Upload
    MAX_UPLOAD_SIZE: int = 50 * 1024 * 1024  # 50MB
    ALLOWED_VIDEO_EXTENSIONS: set[str] = {".mp4", ".mov", ".avi", ".webm"}
    UPLOAD_DIR: str = "./uploads"

    # AI Service (optional)
    AI_SERVICE_URL: Optional[str] = None
    AI_API_KEY: Optional[str] = None

    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 60

    # Logging
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
