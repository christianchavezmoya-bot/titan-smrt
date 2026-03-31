from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..core.auth import get_current_user
from ..core.database import get_db
from ..models.user import User
from ..models.user_profile import UserProfile
from ..schemas.profile import UserProfileRequest, UserProfileResponse

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("", response_model=UserProfileResponse)
def get_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UserProfileResponse:
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        return UserProfileResponse(user_id=current_user.id)
    return UserProfileResponse(
        user_id=current_user.id,
        age=profile.age,
        sex=profile.sex,
        height_cm=profile.height_cm,
        weight_kg=profile.weight_kg,
        goal_type=profile.goal_type,
        experience_level=profile.experience_level,
        equipment_access=profile.equipment_access,
        training_days_per_week=profile.training_days_per_week,
        injury_notes=profile.injury_notes,
    )


@router.put("", response_model=UserProfileResponse)
def update_profile(
    payload: UserProfileRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UserProfileResponse:
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        profile = UserProfile(user_id=current_user.id)
        db.add(profile)
    profile.age = payload.age
    profile.sex = payload.sex
    profile.height_cm = payload.height_cm
    profile.weight_kg = payload.weight_kg
    profile.goal_type = payload.goal_type
    profile.experience_level = payload.experience_level
    profile.equipment_access = payload.equipment_access
    profile.training_days_per_week = payload.training_days_per_week
    profile.injury_notes = payload.injury_notes
    db.commit()
    db.refresh(profile)
    return UserProfileResponse(
        user_id=current_user.id,
        age=profile.age,
        sex=profile.sex,
        height_cm=profile.height_cm,
        weight_kg=profile.weight_kg,
        goal_type=profile.goal_type,
        experience_level=profile.experience_level,
        equipment_access=profile.equipment_access,
        training_days_per_week=profile.training_days_per_week,
        injury_notes=profile.injury_notes,
    )
