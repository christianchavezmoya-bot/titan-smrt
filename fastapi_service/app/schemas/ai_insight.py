from pydantic import BaseModel
from typing import Optional

class AIInsightResponse(BaseModel):
    id: str
    date: Optional[str] = None
    insight_type: Optional[str] = None
    actionable_advice: Optional[str] = None
    confidence_score: Optional[float] = None

class AIInsightListResponse(BaseModel):
    insights: list[AIInsightResponse]
