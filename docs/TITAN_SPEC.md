# Titan App: Product & Technical Specification v1.0

This document defines the structure, UX rules, data layout, API surface, and build prompts
for the Titan app using Flutter (client) and FastAPI (AI + backend).

## 1) User Experience (UX) and the "3-Click" Information Architecture

### A) The 3-Click Flow (Happy Path)

Click 1 (Launch)
- User opens app; the "Smart Start" button is centered and pulsing.
- System logic: app checks the Routines table. If today is "Leg Day," it auto-loads the
  Leg Routine. If no routine, it asks "Quick Start or Routine?"

Click 2 (Action)
- User completes a set and taps the massive "Finish Set" circle.
- System logic: camera snap (optional), rest timer starts, heart rate analysis begins.

Click 3 (Review)
- User finishes workout and taps "End Session."
- System logic: summary screen appears with XP gained, form score, AI advice.

### B) Navigation Structure

- Tab 1: Hub (Home) - Active workout screen (if active) or "Ready" state.
- Tab 2: Analytics - Heatmaps and AI insights.
- Tab 3: Exercises/Routines - Library of movements and templates.
- Tab 4: Profile - Settings, Subscription, Social Feed.

### C) 3-Click Rule Mapping

- Start a workout: Hub -> Smart Start -> Finish Set -> End Session.
- Log a set: Hub -> exercise card -> Finish Set.
- Find a routine: Hub -> Quick Start -> Routine picker.
- View AI insight: Analytics -> Insight card.
- Upgrade to Pro: Profile -> Subscription -> Start Trial.

## 2) Data Layout (Database Schema)

Dual database strategy:
- SQLite on-device for offline-first logging.
- PostgreSQL remote for sync, social, and AI training.

### A) Core Tables (Relational)

```sql
-- USERS & AUTH
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    subscription_type VARCHAR(20) DEFAULT 'free', -- 'free', 'pro'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- EXERCISES (Global Library + Custom)
CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID, -- NULL if default exercise, UUID if user-created
    name VARCHAR(100) NOT NULL,
    muscle_group VARCHAR(50), -- 'Chest', 'Back', 'Legs'
    equipment VARCHAR(50), -- 'Barbell', 'Dumbbell', 'Cable'
    is_default BOOLEAN DEFAULT FALSE
);

-- ROUTINES (Templates)
CREATE TABLE routines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    difficulty_rating INTEGER CHECK (difficulty_rating BETWEEN 1 AND 10)
);

-- ROUTINE_DETAILS (What exercises are in a template)
CREATE TABLE routine_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    routine_id UUID REFERENCES routines(id),
    exercise_id UUID REFERENCES exercises(id),
    display_order INTEGER,
    default_sets JSONB -- e.g., [{"reps": 10, "type": "normal"}, {"reps": 8, "type": "dropset"}]
);

-- WORKOUT LOGS (The actual history)
CREATE TABLE workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    routine_id UUID REFERENCES routines(id), -- Optional, if following a plan
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    total_volume FLOAT, -- Calculated field
    notes TEXT,
    ai_insight TEXT, -- Text blob for AI summary
    form_score_average FLOAT -- 0.0 to 1.0
);

-- WORKOUT SETS (The granular data)
CREATE TABLE workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID REFERENCES workouts(id),
    exercise_id UUID REFERENCES exercises(id),
    set_order INTEGER,
    weight_kg FLOAT,
    reps INTEGER,
    rpe INTEGER, -- Rate of Perceived Exertion (1-10)
    rest_time_seconds INTEGER, -- How long they rested before this set
    video_url TEXT, -- S3 path to form video
    form_confidence FLOAT -- AI score for that specific set
);

-- NUTRITION INTEGRATION
CREATE TABLE nutrition_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    date DATE,
    protein FLOAT,
    carbs FLOAT,
    fats FLOAT
);
```

### B) Offline Sync Metadata

- Each table mirrors local SQLite with `updated_at` and `is_dirty` flags.
- Sync uses last-write-wins with server-side conflict reporting.
- Conflicts preserve local `start_time` and `end_time` as source of truth.

## 3) API Surface (FastAPI + REST)

Base URL: `https://api.titanapp.com/v1`

| Method | Endpoint | Description | Request Body | Response |
| --- | --- | --- | --- | --- |
| POST | `/auth/register` | Create user | `{email, password, username}` | `{user_id, token}` |
| POST | `/workout/start` | Initialize session | `{routine_id?}` | `{workout_id, suggested_exercises}` |
| POST | `/workout/log-set` | Save a set | `{workout_id, exercise_id, weight, reps}` | `{success, updated_volume}` |
| POST | `/ai/analyze` | Upload form video | `{video_file, exercise_id}` | `{rep_count, form_score, feedback_text}` |
| GET | `/user/insights` | Get AI coach advice | `None` | `{plateau_warning, suggestion}` |
| POST | `/nutrition/log` | Log macros | `{protein, carbs, fats}` | `{daily_total}` |

## 4) Detailed Development Prompts

### Frontend Prompt (Flutter)

"Create a Flutter widget named ActiveWorkoutCard. Use Stack and Positioned widgets to overlay
a 'Heart Rate Graph' (using fl_chart) over a blurred background image of the gym.

The center of the card must have a huge GestureDetector. When tapped, it should trigger a
haptic feedback (HapticFeedback.heavyImpact) and animate a checkmark filling up the screen.

Include a 'Smart Timer' in the bottom corner. This timer should not count down seconds linearly.
Instead, it should simulate 'Recovery' by changing color from Red to Green. If we have a
Heart Rate stream (from health package), only turn Green when HR drops below 100bpm."

### Backend Prompt (Python FastAPI)

"Write a FastAPI endpoint /workout/analyze_progression.

Logic:

Accept user_id and exercise_name as input.
Query the database for the last 6 sessions of that exercise.
Calculate the 1RM (One Rep Max) for each session using the Epley Formula:
`weight * (1 + reps/30)`.
If the average 1RM of the last 3 sessions is less than the 3 sessions before that, return a
JSON object:

```json
{
  \"status\": \"stagnant\",
  \"message\": \"Your strength on Bench Press has plateaued.\",
  \"suggestion\": \"Increase intensity by adding 2.5kg or decrease rest intervals to 90s.\"
}
```

Otherwise, return:
`{ \"status\": \"gaining\", \"message\": \"You are progressing!\" }`."

## 5) Monetization Logic (Free vs. Pro)

Feature gating model with a 7-day free trial (no credit card required).

### A) AI Coach
- Free: Generic summary ("You are doing great!").
- Pro: Detailed analysis from `analyze_progression`.

### B) Hardware Integration
- Free: Manual logging only.
- Pro: Apple Watch / Garmin / BLE HR monitoring.

Implementation note (FastAPI):

```python
if user.subscription_level == "free":
    return {"message": "Upgrade to Pro to see AI Analysis"}
return run_complex_ai_analysis(user)
```

## 6) Killer Features (Differentiators)

- Sparring Partner mode (BLE pairing, shared timers, synergy bonus XP).
- AR racking guidance (camera highlights required dumbbells).
- Dynamic difficulty adjustment after failed sets.

