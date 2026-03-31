from datetime import date
from typing import Optional
from pydantic import BaseModel

class NutritionLogRequest(BaseModel):
    protein: float
    carbs: float
    fats: float
    date: Optional[date] = None

class NutritionLogResponse(BaseModel):
    daily_total: float
    calories: float
    date: date

class NutritionSummaryResponse(BaseModel):
    date: date
    protein: float
    carbs: float
    fats: float
    calories: float
    training_volume_7d: float
    suggestion: str


class NutritionDaySummary(BaseModel):
    date: date
    protein: float
    carbs: float
    fats: float
    calories: float


class NutritionWeeklyResponse(BaseModel):
    start_date: date
    end_date: date
    days: list[NutritionDaySummary]
    total_calories: float
    average_calories: float
