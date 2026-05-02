"""
AI Coach Service - Python/FastAPI
Handles: Pose Estimation, Form Feedback, LLM Coaching, Recommendations
Tech: PyTorch, Triton Inference Server, CoreML/NNAPI bridge
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import numpy as np
import asyncio
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Titan AI Coach Service",
    description="AI-powered fitness coaching, form analysis, and personalized recommendations",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============ DATA MODELS ============

class WorkoutSet(BaseModel):
    exercise_id: str
    exercise_name: str
    weight: float
    reps: int
    rpe: Optional[int] = None
    timestamp: datetime

class WorkoutSession(BaseModel):
    user_id: str
    session_id: str
    sets: List[WorkoutSet]
    duration_minutes: float

class HealthMetrics(BaseModel):
    user_id: str
    date: datetime
    hrv: Optional[float] = None  # Heart Rate Variability
    resting_hr: Optional[int] = None  # Resting Heart Rate
    sleep_duration: Optional[float] = None  # Hours
    sleep_quality: Optional[int] = None  # 1-100
    steps: Optional[int] = None
    active_calories: Optional[int] = None

class RecoveryInput(BaseModel):
    user_id: str
    hrv: float
    resting_hr: int
    sleep_duration: float
    sleep_quality: int
    yesterday_strain: float  # 0-21 scale (like Whoop)
    yesterday_workout_type: Optional[str] = None

class RecoveryScore(BaseModel):
    score: int  # 0-100
    status: str  # "poor", "moderate", "good", "excellent"
    hrv_status: str
    sleep_status: str
    strain_recommendation: str
    recommended_workout_type: str

class FormAnalysisResult(BaseModel):
    rep_count: int
    form_score: float  # 0-100
    issues: List[str]
    suggestions: List[str]
    joint_angles: Dict[str, List[float]]

class ProgressionAnalysis(BaseModel):
    exercise_name: str
    status: str  # "gaining", "stagnant", "regressing"
    one_rm_trend: List[float]
    message: str
    suggestion: str

class WorkoutRecommendation(BaseModel):
    workout_id: str
    workout_name: str
    difficulty: str
    duration_minutes: int
    reason: str
    match_score: float

class AICoachFeedback(BaseModel):
    message: str
    tone: str  # "encouraging", "challenging", "informative"
    action_items: List[str]

# ============ AI AGENTS ============

class RecoveryAgent:
    """
    The Recovery & Strain Agent (The "Whoop" Brain)
    Trigger: Runs every morning at 4:00 AM user local time
    """
    
    # 14-day rolling baseline storage (in production, use database)
    baselines: Dict[str, Dict[str, List[float]]] = {}
    
    def calculate_recovery(self, input_data: RecoveryInput) -> RecoveryScore:
        user_id = input_data.user_id
        
        # Get or initialize baseline
        if user_id not in self.baselines:
            self.baselines[user_id] = {
                "hrv": [],
                "resting_hr": [],
                "sleep": [],
            }
        
        baseline = self.baselines[user_id]
        
        # Calculate HRV score (compare to 14-day baseline)
        hrv_baseline = np.mean(baseline["hrv"]) if baseline["hrv"] else input_data.hrv
        hrv_std = np.std(baseline["hrv"]) if len(baseline["hrv"]) > 1 else 10
        
        hrv_z_score = (input_data.hrv - hrv_baseline) / hrv_std if hrv_std > 0 else 0
        hrv_score = max(0, min(100, 50 + (hrv_z_score * 15)))
        
        # Calculate sleep score
        sleep_baseline = np.mean(baseline["sleep"]) if baseline["sleep"] else 7.5
        sleep_ratio = input_data.sleep_duration / sleep_baseline
        sleep_score = min(100, input_data.sleep_quality * sleep_ratio)
        
        # Calculate HR score (lower resting HR is better)
        hr_baseline = np.mean(baseline["resting_hr"]) if baseline["resting_hr"] else input_data.resting_hr
        hr_score = max(0, min(100, 100 - (input_data.resting_hr - hr_baseline) * 2))
        
        # Factor in yesterday's strain
        strain_factor = max(0.7, 1 - (input_data.yesterday_strain / 30))
        
        # Calculate weighted recovery score
        recovery_score = int((
            hrv_score * 0.4 +
            sleep_score * 0.25 +
            hr_score * 0.2 +
            strain_factor * 100 * 0.15
        ))
        
        # Update baseline
        baseline["hrv"].append(input_data.hrv)
        baseline["resting_hr"].append(input_data.resting_hr)
        baseline["sleep"].append(input_data.sleep_duration)
        
        # Keep only last 14 days
        for key in baseline:
            if len(baseline[key]) > 14:
                baseline[key] = baseline[key][-14:]
        
        # Determine status
        if recovery_score >= 80:
            status = "excellent"
            strain_rec = "High intensity training recommended"
            workout_rec = "strength_heavy"
        elif recovery_score >= 66:
            status = "good"
            strain_rec = "Moderate intensity training recommended"
            workout_rec = "strength_moderate"
        elif recovery_score >= 33:
            status = "moderate"
            strain_rec = "Low intensity or recovery session recommended"
            workout_rec = "recovery"
        else:
            status = "poor"
            strain_rec = "Rest day strongly recommended"
            workout_rec = "rest"
        
        return RecoveryScore(
            score=recovery_score,
            status=status,
            hrv_status="above_baseline" if hrv_z_score > 0.5 else "below_baseline" if hrv_z_score < -0.5 else "normal",
            sleep_status="optimal" if input_data.sleep_duration >= 7.5 else "insufficient",
            strain_recommendation=strain_rec,
            recommended_workout_type=workout_rec,
        )


class SmartSchedulerAgent:
    """
    The Smart Scheduling Agent (The 'Keep' Personal Trainer)
    Trigger: Runs immediately after the Recovery Agent finishes
    """
    
    def adjust_workout(self, recovery_score: RecoveryScore, planned_workout: Dict[str, Any]) -> Dict[str, Any]:
        score = recovery_score.score
        
        if score >= 66:
            # Full workout as planned
            return {
                **planned_workout,
                "modification": "none",
                "message": "You're fully recovered! Go crush your planned workout.",
            }
        
        elif score >= 33:
            # Reduce volume by 20%
            return {
                **planned_workout,
                "modification": "volume_reduced",
                "volume_adjustment": 0.8,
                "message": f"Recovery is moderate ({score}%). Reducing volume by 20%. Focus on form.",
                "sets": planned_workout.get("sets", []),
                # In production, actually reduce the sets/reps
            }
        
        else:
            # Replace with recovery workout
            return {
                "workout_id": "recovery_yoga_20min",
                "workout_name": "20-Minute Restorative Yoga",
                "workout_type": "recovery",
                "difficulty": "K1",
                "duration_minutes": 20,
                "modification": "replaced",
                "message": f"Your recovery is low ({score}%). Heavy training may cause injury. I've swapped in a gentle recovery session instead.",
                "reason": "prioritize_recovery",
            }


class DynamicNutritionAgent:
    """
    The Dynamic Nutrition Agent (The 'MacroFactor' Brain)
    Trigger: Runs once a week (e.g., Sunday night)
    """
    
    def calculate_adjustments(
        self,
        user_id: str,
        current_macros: Dict[str, int],
        weekly_calorie_avg: float,
        weekly_protein_avg: float,
        weight_trend: List[float],  # Last 4 weeks
        goal: str,  # "lose", "maintain", "gain"
        activity_level: str,
    ) -> Dict[str, Any]:
        
        # Calculate weight change trend
        if len(weight_trend) >= 4:
            weight_change = weight_trend[-1] - weight_trend[0]
            weekly_change = weight_change / 4
        else:
            weekly_change = 0
        
        # Target rates
        target_rates = {
            "lose": -0.5,  # -0.5 kg per week
            "maintain": 0,
            "gain": 0.25,  # +0.25 kg per week
        }
        
        target = target_rates.get(goal, 0)
        deviation = weekly_change - target
        
        adjustments = {
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fats": 0,
        }
        
        message = ""
        
        # Adjust based on goal and progress
        if goal == "lose":
            if deviation > 0.1:  # Not losing fast enough
                adjustments["calories"] = -150
                adjustments["carbs"] = -20
                message = "Weight loss has stalled. Reducing calories by 150/day."
            elif deviation < -0.7:  # Losing too fast
                adjustments["calories"] = 100
                message = "Weight loss is too rapid. Adding 100 calories to preserve muscle."
            else:
                message = "On track! Maintain current macros."
                
        elif goal == "gain":
            if deviation < 0.1:  # Not gaining
                adjustments["calories"] = 200
                adjustments["protein"] = 10
                message = "Weight gain slower than target. Adding 200 calories."
            elif deviation > 0.4:  # Gaining too fast (likely fat)
                adjustments["calories"] = -100
                message = "Gaining a bit too fast. Slight calorie reduction."
            else:
                message = "Clean gains! Keep it up."
        
        # Ensure minimum protein (2g per kg body weight)
        min_protein = 150  # Simplified; in production, calculate from user weight
        if current_macros["protein"] + adjustments["protein"] < min_protein:
            adjustments["protein"] = min_protein - current_macros["protein"]
        
        return {
            "adjustments": adjustments,
            "new_macros": {
                "calories": current_macros["calories"] + adjustments["calories"],
                "protein": current_macros["protein"] + adjustments["protein"],
                "carbs": current_macros["carbs"] + adjustments["carbs"],
                "fats": current_macros["fats"] + adjustments["fats"],
            },
            "weekly_weight_change": weekly_change,
            "message": message,
            "recommendation": self._generate_recommendation(goal, deviation),
        }
    
    def _generate_recommendation(self, goal: str, deviation: float) -> str:
        if goal == "lose":
            if deviation > 0.3:
                return "Consider adding 2 cardio sessions per week and tracking food more precisely."
            return "Your deficit is well-calibrated. Stay consistent."
        elif goal == "gain":
            if deviation < 0:
                return "Add a post-workout shake and consider a bedtime snack."
            return "Surplus is appropriate. Ensure adequate sleep for muscle growth."
        return "Focus on consistency and adequate protein intake."


class FormAnalysisAgent:
    """
    Real-time form analysis using pose estimation
    Uses MediaPipe/TensorFlow for on-device processing
    """
    
    # Reference joint angles for exercises
    EXERCISE_REFERENCES = {
        "squat": {
            "knee_angle_min": 70,
            "knee_angle_max": 90,
            "hip_angle_min": 70,
            "back_angle": 90,
        },
        "deadlift": {
            "hip_angle_start": 45,
            "hip_angle_end": 180,
            "back_neutral": 180,
        },
        "bench_press": {
            "elbow_angle_bottom": 90,
            "elbow_angle_top": 180,
        },
        # Add more exercises
    }
    
    def analyze_video(self, video_data: bytes, exercise_name: str) -> FormAnalysisResult:
        """
        Analyze workout video for form feedback
        In production, use TensorFlow Lite / CoreML
        """
        # Placeholder implementation
        # In production:
        # 1. Extract frames from video
        # 2. Run pose estimation (MediaPipe)
        # 3. Calculate joint angles
        # 4. Compare to reference
        # 5. Generate feedback
        
        reference = self.EXERCISE_REFERENCES.get(exercise_name.lower(), {})
        
        return FormAnalysisResult(
            rep_count=8,
            form_score=85.5,
            issues=[
                "Slight forward lean in bottom position",
            ],
            suggestions=[
                "Focus on keeping chest up",
                "Drive through heels",
            ],
            joint_angles={
                "knee": [85, 88, 82, 87],
                "hip": [75, 78, 72, 76],
            },
        )
    
    def analyze_frame(self, landmarks: List[Dict], exercise_name: str) -> Dict[str, Any]:
        """
        Real-time frame-by-frame analysis for live feedback
        """
        # Calculate current joint angles from landmarks
        # This would be called from mobile app's CoreML/NNAPI
        
        return {
            "rep_detected": True,
            "form_score": 0.92,
            "cues": ["Keep your back straight"],
        }


class ProgressionAgent:
    """
    Analyzes workout progression and detects plateaus
    """
    
    def analyze_progression(
        self,
        user_id: str,
        exercise_name: str,
        sessions: List[Dict[str, Any]],  # Last 6 sessions
    ) -> ProgressionAnalysis:
        
        if len(sessions) < 6:
            return ProgressionAnalysis(
                exercise_name=exercise_name,
                status="insufficient_data",
                one_rm_trend=[],
                message="Not enough data to analyze progression.",
                suggestion="Complete more workouts to track progress.",
            )
        
        # Calculate 1RM using Epley formula for each session
        # 1RM = weight * (1 + reps/30)
        one_rm_trend = []
        for session in sessions:
            max_1rm = 0
            for s in session.get("sets", []):
                weight = s.get("weight", 0)
                reps = s.get("reps", 0)
                if weight > 0 and reps > 0:
                    one_rm = weight * (1 + reps / 30)
                    max_1rm = max(max_1rm, one_rm)
            one_rm_trend.append(max_1rm)
        
        # Compare first 3 sessions to last 3 sessions
        first_half_avg = np.mean(one_rm_trend[:3])
        second_half_avg = np.mean(one_rm_trend[3:])
        
        change_percent = ((second_half_avg - first_half_avg) / first_half_avg) * 100
        
        if change_percent > 2:
            status = "gaining"
            message = f"Excellent! Your {exercise_name} strength is improving (+{change_percent:.1f}%)."
            suggestion = "Continue progressive overload. Consider increasing weight by 2.5%."
        elif change_percent < -2:
            status = "regressing"
            message = f"Your {exercise_name} strength has decreased ({change_percent:.1f}%)."
            suggestion = "Consider deload week, check recovery, and ensure adequate nutrition."
        else:
            status = "stagnant"
            message = f"Your {exercise_name} has plateaued."
            suggestion = "Try varying rep ranges, adding drop sets, or decreasing rest intervals to 90s."
        
        return ProgressionAnalysis(
            exercise_name=exercise_name,
            status=status,
            one_rm_trend=one_rm_trend,
            message=message,
            suggestion=suggestion,
        )


# Initialize agents
recovery_agent = RecoveryAgent()
scheduler_agent = SmartSchedulerAgent()
nutrition_agent = DynamicNutritionAgent()
form_agent = FormAnalysisAgent()
progression_agent = ProgressionAgent()

# ============ API ENDPOINTS ============

@app.get("/")
async def root():
    return {
        "status": "ok",
        "service": "ai-coach",
        "version": "1.0.0",
    }


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "ai-coach"}


# ============ RECOVERY ENDPOINTS ============

@app.post("/api/v1/ai/recovery/calculate")
async def calculate_recovery(input_data: RecoveryInput):
    """Calculate daily recovery score"""
    result = recovery_agent.calculate_recovery(input_data)
    return result


@app.get("/api/v1/ai/recovery/{user_id}")
async def get_recovery(user_id: str):
    """Get latest recovery score for user"""
    # In production, fetch from database
    return {
        "user_id": user_id,
        "score": 72,
        "status": "good",
        "timestamp": datetime.now(),
    }


# ============ SMART SCHEDULING ENDPOINTS ============

@app.post("/api/v1/ai/schedule/adjust")
async def adjust_workout(
    recovery_score: RecoveryScore,
    planned_workout: Dict[str, Any],
):
    """Dynamically adjust workout based on recovery"""
    result = scheduler_agent.adjust_workout(recovery_score, planned_workout)
    return result


@app.post("/api/v1/ai/schedule/recommend")
async def recommend_workout(
    user_id: str,
    recovery_score: int,
    available_equipment: List[str],
    preferred_duration: int,  # minutes
    goal: str,
):
    """Get personalized workout recommendation"""
    # In production, query workout database with AI ranking
    
    recommendations = [
        WorkoutRecommendation(
            workout_id="strength_upper_45min",
            workout_name="Upper Body Strength",
            difficulty="K3",
            duration_minutes=45,
            reason=f"Based on your {recovery_score}% recovery and strength goals",
            match_score=0.92,
        )
    ]
    
    return {"recommendations": recommendations}


# ============ FORM ANALYSIS ENDPOINTS ============

@app.post("/api/v1/ai/analyze/form")
async def analyze_form(
    video: UploadFile = File(...),
    exercise_name: str = "squat",
):
    """Analyze workout video for form feedback"""
    video_data = await video.read()
    result = form_agent.analyze_video(video_data, exercise_name)
    return result


@app.post("/api/v1/ai/analyze/frame")
async def analyze_frame(
    landmarks: List[Dict[str, float]],
    exercise_name: str,
):
    """Real-time frame analysis for live feedback"""
    result = form_agent.analyze_frame(landmarks, exercise_name)
    return result


# ============ PROGRESSION ENDPOINTS ============

@app.post("/api/v1/ai/analyze/progression")
async def analyze_progression(
    user_id: str,
    exercise_name: str,
    sessions: List[Dict[str, Any]],
):
    """Analyze strength progression and detect plateaus"""
    result = progression_agent.analyze_progression(user_id, exercise_name, sessions)
    return result


@app.get("/api/v1/ai/insights/{user_id}")
async def get_ai_insights(user_id: str):
    """Get comprehensive AI coaching insights"""
    return {
        "user_id": user_id,
        "insights": [
            {
                "type": "plateau_warning",
                "exercise": "Bench Press",
                "message": "Your strength has plateaued over the last 3 weeks.",
                "suggestion": "Try adding 2.5kg or decrease rest intervals to 90s.",
            },
            {
                "type": "achievement",
                "message": "You've hit the gym 5 days this week!",
                "badge": "consistency_champion",
            },
            {
                "type": "recovery_tip",
                "message": "Your HRV has been declining. Consider an extra rest day.",
            },
        ],
        "coaching_message": "Great consistency this week! Focus on progressive overload for your main lifts.",
    }


# ============ NUTRITION AI ENDPOINTS ============

@app.post("/api/v1/ai/nutrition/adjust")
async def adjust_nutrition(
    user_id: str,
    current_macros: Dict[str, int],
    weekly_calorie_avg: float,
    weekly_protein_avg: float,
    weight_trend: List[float],
    goal: str,
    activity_level: str,
):
    """Calculate macro adjustments based on progress"""
    result = nutrition_agent.calculate_adjustments(
        user_id,
        current_macros,
        weekly_calorie_avg,
        weekly_protein_avg,
        weight_trend,
        goal,
        activity_level,
    )
    return result


# ============ LLM COACHING ENDPOINTS ============

@app.post("/api/v1/ai/coach/chat")
async def chat_with_coach(
    user_id: str,
    message: str,
    context: Optional[Dict[str, Any]] = None,
):
    """Chat with AI fitness coach (LLM integration)"""
    # In production, integrate with LLM API (OpenAI, Anthropic, or fine-tuned model)
    
    # Simulated responses based on keywords
    response = ""
    tone = "encouraging"
    
    if "tired" in message.lower():
        response = "I hear you! It sounds like you might need more recovery. Let's look at your sleep and HRV data. Would you like me to suggest a lighter workout for today?"
        tone = "supportive"
    elif "plateau" in message.lower():
        response = "Plateaus are frustrating but normal! They often mean your body has adapted. Let's shake things up - I recommend trying a different rep range or adding intensity techniques like drop sets."
        tone = "informative"
    elif "motivation" in message.lower():
        response = "Remember why you started! You've already shown incredible dedication. Every rep counts, and I'm here to help you push through. Let's crush this workout together!"
        tone = "encouraging"
    else:
        response = "I'm here to help you reach your fitness goals! What specific aspect of your training would you like to discuss?"
    
    return AICoachFeedback(
        message=response,
        tone=tone,
        action_items=[
            "Log your next workout",
            "Check your recovery score",
        ],
    )


# ============ BACKGROUND TASKS ============

async def run_daily_recovery_check():
    """Background task that runs recovery calculations for all users"""
    logger.info("Running daily recovery check for all users...")
    # In production:
    # 1. Query all active users
    # 2. Fetch their health data from HealthKit/Google Fit
    # 3. Calculate recovery scores
    # 4. Store in database
    # 5. Trigger push notifications if recovery is low


async def run_weekly_nutrition_adjustment():
    """Background task for weekly macro adjustments"""
    logger.info("Running weekly nutrition adjustment...")
    # In production:
    # 1. Query users with nutrition tracking enabled
    # 2. Analyze their weekly data
    # 3. Calculate adjustments
    # 4. Update their macro targets
    # 5. Notify users of changes


# ============ STARTUP ============

@app.on_event("startup")
async def startup_event():
    logger.info("AI Coach Service starting up...")
    # In production, load ML models, connect to Triton, etc.


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("AI Coach Service shutting down...")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8083)