"""
Run from fastapi_service directory:
  .venv/bin/python seed_exercises.py
"""
import uuid
from datetime import datetime, timezone
from app.core.database import SessionLocal, engine
from app.models.exercise import Exercise
from app.models.base import BaseModelMixin
from app.core.database import Base

Base.metadata.create_all(bind=engine)

EXERCISES = [
    # Chest
    ("Barbell Bench Press",     "Chest",     "Barbell"),
    ("Dumbbell Bench Press",    "Chest",     "Dumbbell"),
    ("Incline Bench Press",     "Chest",     "Barbell"),
    ("Incline Dumbbell Press",  "Chest",     "Dumbbell"),
    ("Cable Fly",               "Chest",     "Cable"),
    ("Dumbbell Fly",            "Chest",     "Dumbbell"),
    ("Push Up",                 "Chest",     "Bodyweight"),
    ("Chest Dip",               "Chest",     "Bodyweight"),

    # Back
    ("Pull Up",                 "Back",      "Bodyweight"),
    ("Chin Up",                 "Back",      "Bodyweight"),
    ("Barbell Row",             "Back",      "Barbell"),
    ("Dumbbell Row",            "Back",      "Dumbbell"),
    ("Lat Pulldown",            "Back",      "Cable"),
    ("Seated Cable Row",        "Back",      "Cable"),
    ("Deadlift",                "Back",      "Barbell"),
    ("Romanian Deadlift",       "Back",      "Barbell"),

    # Shoulders
    ("Barbell Overhead Press",  "Shoulders", "Barbell"),
    ("Dumbbell Shoulder Press", "Shoulders", "Dumbbell"),
    ("Lateral Raise",           "Shoulders", "Dumbbell"),
    ("Front Raise",             "Shoulders", "Dumbbell"),
    ("Cable Lateral Raise",     "Shoulders", "Cable"),
    ("Face Pull",               "Shoulders", "Cable"),
    ("Arnold Press",            "Shoulders", "Dumbbell"),

    # Arms
    ("Barbell Curl",            "Arms",      "Barbell"),
    ("Dumbbell Curl",           "Arms",      "Dumbbell"),
    ("Hammer Curl",             "Arms",      "Dumbbell"),
    ("Preacher Curl",           "Arms",      "Barbell"),
    ("Cable Curl",              "Arms",      "Cable"),
    ("Tricep Pushdown",         "Arms",      "Cable"),
    ("Skull Crusher",           "Arms",      "Barbell"),
    ("Overhead Tricep Extension","Arms",     "Dumbbell"),
    ("Tricep Dip",              "Arms",      "Bodyweight"),

    # Legs
    ("Barbell Squat",           "Legs",      "Barbell"),
    ("Front Squat",             "Legs",      "Barbell"),
    ("Hack Squat",              "Legs",      "Machine"),
    ("Leg Press",               "Legs",      "Machine"),
    ("Lunges",                  "Legs",      "Dumbbell"),
    ("Bulgarian Split Squat",   "Legs",      "Dumbbell"),
    ("Leg Extension",           "Legs",      "Machine"),
    ("Leg Curl",                "Legs",      "Machine"),
    ("Calf Raise",              "Legs",      "Machine"),
    ("Goblet Squat",            "Legs",      "Dumbbell"),

    # Core
    ("Plank",                   "Core",      "Bodyweight"),
    ("Crunch",                  "Core",      "Bodyweight"),
    ("Hanging Leg Raise",       "Core",      "Bodyweight"),
    ("Cable Crunch",            "Core",      "Cable"),
    ("Ab Wheel Rollout",        "Core",      "Other"),
    ("Russian Twist",           "Core",      "Bodyweight"),
    ("Side Plank",              "Core",      "Bodyweight"),
]

db = SessionLocal()

existing = db.query(Exercise).filter(Exercise.is_default == True).count()
if existing > 0:
    print(f"Already have {existing} default exercises. Skipping.")
    db.close()
    exit(0)

now = datetime.now(timezone.utc)
added = 0
for name, muscle_group, equipment in EXERCISES:
    ex = Exercise(
        id=str(uuid.uuid4()),
        user_id=None,
        name=name,
        muscle_group=muscle_group,
        equipment=equipment,
        is_default=True,
        created_at=now,
        updated_at=now,
    )
    db.add(ex)
    added += 1

db.commit()
db.close()
print(f"Seeded {added} default exercises.")
