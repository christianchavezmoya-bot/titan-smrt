from datetime import date, datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..schemas.nutrition import (
    NutritionLogRequest,
    NutritionLogResponse,
    NutritionSummaryResponse,
    NutritionWeeklyResponse,
    NutritionDaySummary,
)
from ..core.auth import get_current_user
from ..core.database import get_db
from ..models.user import User
from ..models.nutrition_log import NutritionLog
from ..models.workout import Workout
from ..models.user_profile import UserProfile

router = APIRouter(prefix="/nutrition", tags=["nutrition"])

@router.post("/log", response_model=NutritionLogResponse)
def log_nutrition(
    payload: NutritionLogRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> NutritionLogResponse:
    log_date = payload.date or date.today()
    existing = (
        db.query(NutritionLog)
        .filter(NutritionLog.user_id == current_user.id, NutritionLog.date == log_date)
        .first()
    )
    if not existing:
        existing = NutritionLog(user_id=current_user.id, date=log_date)
        db.add(existing)
    existing.protein = payload.protein
    existing.carbs = payload.carbs
    existing.fats = payload.fats
    db.commit()
    total = payload.protein + payload.carbs + payload.fats
    calories = payload.protein * 4 + payload.carbs * 4 + payload.fats * 9
    return NutritionLogResponse(daily_total=total, calories=calories, date=log_date)


@router.get("/today", response_model=NutritionLogResponse)
def get_today(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> NutritionLogResponse:
    today = date.today()
    log = (
        db.query(NutritionLog)
        .filter(NutritionLog.user_id == current_user.id, NutritionLog.date == today)
        .first()
    )
    if not log:
        return NutritionLogResponse(daily_total=0, calories=0, date=today)
    total = (log.protein or 0) + (log.carbs or 0) + (log.fats or 0)
    calories = (log.protein or 0) * 4 + (log.carbs or 0) * 4 + (log.fats or 0) * 9
    return NutritionLogResponse(daily_total=total, calories=calories, date=today)


@router.get("/summary", response_model=NutritionSummaryResponse)
def summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> NutritionSummaryResponse:
    today = date.today()
    log = (
        db.query(NutritionLog)
        .filter(NutritionLog.user_id == current_user.id, NutritionLog.date == today)
        .first()
    )
    protein = log.protein if log else 0.0
    carbs = log.carbs if log else 0.0
    fats = log.fats if log else 0.0
    calories = protein * 4 + carbs * 4 + fats * 9

    cutoff = datetime.utcnow() - timedelta(days=7)
    volume = (
        db.query(Workout)
        .filter(Workout.user_id == current_user.id, Workout.created_at >= cutoff)
        .all()
    )
    training_volume = sum(w.total_volume or 0 for w in volume)

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    goal = profile.goal_type if profile else None
    weight_kg = profile.weight_kg if profile else None

    suggestion = "Log meals consistently to improve coaching accuracy."
    if weight_kg:
        carb_target = weight_kg * (3.0 if goal == "strength" else 2.0)
        if training_volume > 5000 and carbs < carb_target:
            suggestion = "Carbs are low for your recent training load. Add 30-60g carbs."
        elif goal == "fat_loss" and calories > weight_kg * 35:
            suggestion = "Calories are high for fat loss. Consider a small deficit."
        elif goal == "hypertrophy" and calories < weight_kg * 30:
            suggestion = "Calories are low for hypertrophy. Add a small surplus."
        else:
            suggestion = "Nutrition looks aligned with your training."

    return NutritionSummaryResponse(
        date=today,
        protein=protein,
        carbs=carbs,
        fats=fats,
        calories=calories,
        training_volume_7d=training_volume,
        suggestion=suggestion,
    )


@router.get("/weekly", response_model=NutritionWeeklyResponse)
def weekly(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> NutritionWeeklyResponse:
    end_date = date.today()
    start_date = end_date - timedelta(days=6)
    logs = (
        db.query(NutritionLog)
        .filter(
            NutritionLog.user_id == current_user.id,
            NutritionLog.date >= start_date,
            NutritionLog.date <= end_date,
        )
        .all()
    )
    log_map = {log.date: log for log in logs if log.date}

    days: list[NutritionDaySummary] = []
    total_calories = 0.0
    for i in range(7):
        day = start_date + timedelta(days=i)
        log = log_map.get(day)
        protein = log.protein if log else 0.0
        carbs = log.carbs if log else 0.0
        fats = log.fats if log else 0.0
        calories = protein * 4 + carbs * 4 + fats * 9
        total_calories += calories
        days.append(
            NutritionDaySummary(
                date=day,
                protein=protein,
                carbs=carbs,
                fats=fats,
                calories=calories,
            )
        )

    average_calories = total_calories / 7
    return NutritionWeeklyResponse(
        start_date=start_date,
        end_date=end_date,
        days=days,
        total_calories=total_calories,
        average_calories=average_calories,
    )
