from pydantic import BaseModel

class AIAnalyzeResponse(BaseModel):
    rep_count: int
    form_score: float
    feedback_text: str

class InsightResponse(BaseModel):
    plateau_warning: str
    suggestion: str
