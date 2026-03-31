from fastapi import APIRouter
from . import auth, workout, ai, nutrition, sync, library, profile

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(workout.router)
api_router.include_router(ai.router)
api_router.include_router(nutrition.router)
api_router.include_router(sync.router)
api_router.include_router(library.router)
api_router.include_router(profile.router)
