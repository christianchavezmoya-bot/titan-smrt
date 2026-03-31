from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, UploadFile, File, Depends
from sqlalchemy.orm import Session
from ..schemas.ai import AIAnalyzeResponse
from ..schemas.ai_insight import AIInsightListResponse, AIInsightResponse
from ..schemas.profile import UserProfileResponse
from ..core.auth import get_current_user
from ..core.database import get_db
from ..models.user import User
from ..models.ai_insight import AIInsight
from ..models.workout import Workout
from ..models.workout_set import WorkoutSet
from ..models.exercise import Exercise
from ..models.user_profile import UserProfile

router = APIRouter(prefix="/ai", tags=["ai"])

@router.post("/analyze", response_model=AIAnalyzeResponse)
def analyze(
    video_file: UploadFile = File(...),
    exercise_id: str = "",
    current_user: User = Depends(get_current_user),
) -> AIAnalyzeResponse:
    return AIAnalyzeResponse(rep_count=0, form_score=0.0, feedback_text="")

@router.get("/insights", response_model=AIInsightListResponse)
def insights(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AIInsightListResponse:
    items = (
        db.query(AIInsight)
        .filter(AIInsight.user_id == current_user.id)
        .order_by(AIInsight.created_at.desc())
        .limit(10)
        .all()
    )
    return AIInsightListResponse(
        insights=[
            AIInsightResponse(
                id=item.id,
                date=item.date.isoformat() if item.date else None,
                insight_type=item.insight_type,
                actionable_advice=item.actionable_advice,
                confidence_score=item.confidence_score,
            )
            for item in items
        ]
    )


@router.post("/coach", response_model=AIInsightListResponse)
def coach(
    exercise_id: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AIInsightListResponse:
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    now = datetime.utcnow()
    cutoff_recent = now - timedelta(days=21)
    cutoff_prior = now - timedelta(days=42)

    insights: List[AIInsight] = []
    exercise_filter = []
    if exercise_id:
        exercise_filter = [WorkoutSet.exercise_id == exercise_id]

    recent_sets = (
        db.query(WorkoutSet, Workout)
        .join(Workout, Workout.id == WorkoutSet.workout_id)
        .filter(
            Workout.user_id == current_user.id,
            WorkoutSet.created_at >= cutoff_recent,
            *exercise_filter,
        )
        .all()
    )
    prior_sets = (
        db.query(WorkoutSet, Workout)
        .join(Workout, Workout.id == WorkoutSet.workout_id)
        .filter(
            Workout.user_id == current_user.id,
            WorkoutSet.created_at < cutoff_recent,
            WorkoutSet.created_at >= cutoff_prior,
            *exercise_filter,
        )
        .all()
    )

    def volume(sets):
        return sum((s.weight_kg or 0) * (s.reps or 0) for s, _ in sets)

    recent_volume = volume(recent_sets)
    prior_volume = volume(prior_sets)

    if prior_volume > 0:
        delta = (recent_volume - prior_volume) / prior_volume
        if delta < 0.02:
            insights.append(
                AIInsight(
                    user_id=current_user.id,
                    date=now.date(),
                    insight_type="plateau",
                    actionable_advice="Volume has not increased in 3 weeks. Consider a deload or add a small load.",
                    confidence_score=0.7,
                )
            )

    def avg_rpe(sets):
        values = [s.rpe for s, _ in sets if s.rpe]
        return sum(values) / len(values) if values else None

    recent_rpe = avg_rpe(recent_sets)
    if recent_rpe is not None:
        if recent_rpe >= 9:
            insights.append(
                AIInsight(
                    user_id=current_user.id,
                    date=now.date(),
                    insight_type="autoregulation",
                    actionable_advice="High RPE trend. Reduce load 2.5–5% or extend rest by 30–60s.",
                    confidence_score=0.65,
                )
            )
        elif recent_rpe <= 6:
            insights.append(
                AIInsight(
                    user_id=current_user.id,
                    date=now.date(),
                    insight_type="autoregulation",
                    actionable_advice="Low RPE trend. Add 2.5kg or +1–2 reps next session.",
                    confidence_score=0.6,
                )
            )

    if profile and profile.goal_type == "fat_loss":
        insights.append(
            AIInsight(
                user_id=current_user.id,
                date=now.date(),
                insight_type="goal",
                actionable_advice="Maintain short rests (60–90s) and keep total volume high.",
                confidence_score=0.5,
            )
        )

    if profile and profile.goal_type == "strength":
        insights.append(
            AIInsight(
                user_id=current_user.id,
                date=now.date(),
                insight_type="goal",
                actionable_advice="Prioritize heavy top sets (3–5 reps) with full recovery (2–3 min).",
                confidence_score=0.5,
            )
        )

    # Nutrition-aware insight (if macros logged today)
    from ..models.nutrition_log import NutritionLog
    today_log = (
        db.query(NutritionLog)
        .filter(NutritionLog.user_id == current_user.id, NutritionLog.date == now.date())
        .first()
    )
    if today_log and profile and profile.weight_kg:
        calories = (today_log.protein or 0) * 4 + (today_log.carbs or 0) * 4 + (today_log.fats or 0) * 9
        if profile.goal_type == "fat_loss" and calories > profile.weight_kg * 35:
            insights.append(
                AIInsight(
                    user_id=current_user.id,
                    date=now.date(),
                    insight_type="nutrition",
                    actionable_advice="Calories are high for fat loss today. Trim ~200 kcal tomorrow.",
                    confidence_score=0.55,
                )
            )
        elif profile.goal_type == "hypertrophy" and calories < profile.weight_kg * 30:
            insights.append(
                AIInsight(
                    user_id=current_user.id,
                    date=now.date(),
                    insight_type="nutrition",
                    actionable_advice="Calories are low for hypertrophy. Add a small surplus (200–300 kcal).",
                    confidence_score=0.55,
                )
            )

    if not insights:
        insights.append(
            AIInsight(
                user_id=current_user.id,
                date=now.date(),
                insight_type="progress",
                actionable_advice="Great work. Keep progressing with small load increases weekly.",
                confidence_score=0.4,
            )
        )

    for item in insights:
        db.add(item)
    db.commit()

    return AIInsightListResponse(
        insights=[
            AIInsightResponse(
                id=item.id,
                date=item.date.isoformat() if item.date else None,
                insight_type=item.insight_type,
                actionable_advice=item.actionable_advice,
                confidence_score=item.confidence_score,
            )
            for item in insights
        ]
    )
