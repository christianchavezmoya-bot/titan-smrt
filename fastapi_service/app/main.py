from typing import Dict
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware as FastAPICORSMiddleware

from .api.router import api_router
from .core.database import Base, engine
from .core.config import settings
from .core.logging import app_logger
from .core.middleware import RequestLoggingMiddleware, ErrorHandlingMiddleware, CORSMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    app_logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION}")
    app_logger.info(f"Debug mode: {settings.DEBUG}")
    
    # Create database tables
    Base.metadata.create_all(bind=engine)
    app_logger.info("Database tables created/verified")
    
    yield
    
    # Shutdown
    app_logger.info("Shutting down application")


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    debug=settings.DEBUG,
    lifespan=lifespan,
)

# Add custom middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(ErrorHandlingMiddleware)
app.add_middleware(CORSMiddleware)

# Add FastAPI CORS middleware as fallback
app.add_middleware(
    FastAPICORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
def health_check() -> Dict[str, str]:
    """Root health check endpoint."""
    return {
        "status": "ok",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
    }


@app.get("/v1/health")
def health_check_v1() -> Dict[str, str]:
    """Versioned health check endpoint."""
    return {
        "status": "ok",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
    }
