# Titan API Contracts (Draft)

Base URL: https://api.titanapp.com/v1

## Auth

POST /auth/register
- Request: { email, password, username }
- Response: { user_id, token }

POST /auth/login
- Request: { email, password }
- Response: { token }

## Workouts

POST /workout/start
- Request: { routine_id? }
- Response: { workout_id, suggested_exercises }

POST /workout/log-set
- Request: { workout_id, exercise_id, weight, reps, rpe?, rest_time_seconds? }
- Response: { success, updated_volume }

POST /workout/end
- Request: { workout_id }
- Response: { summary, form_score_average, ai_insight }

## AI

POST /ai/analyze
- Request: multipart form: { video_file, exercise_id }
- Response: { rep_count, form_score, feedback_text }

GET /user/insights
- Response: { plateau_warning, suggestion }

## Nutrition

POST /nutrition/log
- Request: { protein, carbs, fats }
- Response: { daily_total }

## Sync

POST /sync
- Request: { last_sync_at, entities: { workouts: [], sets: [], routines: [] } }
- Response: { conflicts: [], updated_entities: [] }

