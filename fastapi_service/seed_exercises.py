"""
Run from fastapi_service directory:
  .venv/bin/python seed_exercises.py
"""
import uuid
from datetime import datetime, timezone
from app.core.database import SessionLocal, engine
from app.core.database import Base

Base.metadata.create_all(bind=engine)

EXERCISES = [
    # ── Chest ──────────────────────────────────────────────────────────────
    ("Barbell Bench Press",          "Chest",     "Barbell"),
    ("Dumbbell Bench Press",         "Chest",     "Dumbbell"),
    ("Incline Barbell Bench Press",  "Chest",     "Barbell"),
    ("Incline Dumbbell Press",       "Chest",     "Dumbbell"),
    ("Decline Bench Press",          "Chest",     "Barbell"),
    ("Close-Grip Bench Press",       "Chest",     "Barbell"),
    ("Cable Fly",                    "Chest",     "Cable"),
    ("Low Cable Fly",                "Chest",     "Cable"),
    ("High Cable Fly",               "Chest",     "Cable"),
    ("Dumbbell Fly",                 "Chest",     "Dumbbell"),
    ("Incline Dumbbell Fly",         "Chest",     "Dumbbell"),
    ("Pec Deck",                     "Chest",     "Machine"),
    ("Machine Chest Press",          "Chest",     "Machine"),
    ("Smith Machine Bench Press",    "Chest",     "Machine"),
    ("Push Up",                      "Chest",     "Bodyweight"),
    ("Wide Push Up",                 "Chest",     "Bodyweight"),
    ("Diamond Push Up",              "Chest",     "Bodyweight"),
    ("Chest Dip",                    "Chest",     "Bodyweight"),
    ("Landmine Press",               "Chest",     "Barbell"),

    # ── Back ───────────────────────────────────────────────────────────────
    ("Pull Up",                      "Back",      "Bodyweight"),
    ("Chin Up",                      "Back",      "Bodyweight"),
    ("Neutral-Grip Pull Up",         "Back",      "Bodyweight"),
    ("Weighted Pull Up",             "Back",      "Bodyweight"),
    ("Barbell Row",                  "Back",      "Barbell"),
    ("Pendlay Row",                  "Back",      "Barbell"),
    ("T-Bar Row",                    "Back",      "Barbell"),
    ("Dumbbell Row",                 "Back",      "Dumbbell"),
    ("Chest-Supported Row",          "Back",      "Dumbbell"),
    ("Lat Pulldown",                 "Back",      "Cable"),
    ("Wide-Grip Lat Pulldown",       "Back",      "Cable"),
    ("Close-Grip Lat Pulldown",      "Back",      "Cable"),
    ("Seated Cable Row",             "Back",      "Cable"),
    ("Single-Arm Cable Row",         "Back",      "Cable"),
    ("Straight-Arm Pulldown",        "Back",      "Cable"),
    ("Machine Row",                  "Back",      "Machine"),
    ("Deadlift",                     "Back",      "Barbell"),
    ("Romanian Deadlift",            "Back",      "Barbell"),
    ("Sumo Deadlift",                "Back",      "Barbell"),
    ("Rack Pull",                    "Back",      "Barbell"),
    ("Good Morning",                 "Back",      "Barbell"),
    ("Hyperextension",               "Back",      "Bodyweight"),
    ("Inverted Row",                 "Back",      "Bodyweight"),

    # ── Shoulders ──────────────────────────────────────────────────────────
    ("Barbell Overhead Press",       "Shoulders", "Barbell"),
    ("Seated Barbell Press",         "Shoulders", "Barbell"),
    ("Dumbbell Shoulder Press",      "Shoulders", "Dumbbell"),
    ("Seated Dumbbell Press",        "Shoulders", "Dumbbell"),
    ("Arnold Press",                 "Shoulders", "Dumbbell"),
    ("Lateral Raise",                "Shoulders", "Dumbbell"),
    ("Cable Lateral Raise",          "Shoulders", "Cable"),
    ("Front Raise",                  "Shoulders", "Dumbbell"),
    ("Barbell Front Raise",          "Shoulders", "Barbell"),
    ("Face Pull",                    "Shoulders", "Cable"),
    ("Reverse Fly",                  "Shoulders", "Dumbbell"),
    ("Reverse Pec Deck",             "Shoulders", "Machine"),
    ("Machine Shoulder Press",       "Shoulders", "Machine"),
    ("Smith Machine Overhead Press", "Shoulders", "Machine"),
    ("Upright Row",                  "Shoulders", "Barbell"),
    ("Shrug",                        "Shoulders", "Barbell"),
    ("Dumbbell Shrug",               "Shoulders", "Dumbbell"),

    # ── Arms — Biceps ──────────────────────────────────────────────────────
    ("Barbell Curl",                 "Arms",      "Barbell"),
    ("EZ-Bar Curl",                  "Arms",      "Barbell"),
    ("Dumbbell Curl",                "Arms",      "Dumbbell"),
    ("Alternating Dumbbell Curl",    "Arms",      "Dumbbell"),
    ("Hammer Curl",                  "Arms",      "Dumbbell"),
    ("Incline Dumbbell Curl",        "Arms",      "Dumbbell"),
    ("Concentration Curl",           "Arms",      "Dumbbell"),
    ("Preacher Curl",                "Arms",      "Barbell"),
    ("EZ-Bar Preacher Curl",         "Arms",      "Barbell"),
    ("Cable Curl",                   "Arms",      "Cable"),
    ("High Cable Curl",              "Arms",      "Cable"),
    ("Machine Curl",                 "Arms",      "Machine"),

    # ── Arms — Triceps ─────────────────────────────────────────────────────
    ("Tricep Pushdown",              "Arms",      "Cable"),
    ("Rope Pushdown",                "Arms",      "Cable"),
    ("Overhead Cable Tricep Extension", "Arms",   "Cable"),
    ("Skull Crusher",                "Arms",      "Barbell"),
    ("EZ-Bar Skull Crusher",         "Arms",      "Barbell"),
    ("Overhead Dumbbell Extension",  "Arms",      "Dumbbell"),
    ("Dumbbell Kickback",            "Arms",      "Dumbbell"),
    ("Tricep Dip",                   "Arms",      "Bodyweight"),
    ("Bench Dip",                    "Arms",      "Bodyweight"),
    ("Close-Grip Push Up",           "Arms",      "Bodyweight"),
    ("Machine Tricep Extension",     "Arms",      "Machine"),

    # ── Legs — Quads ───────────────────────────────────────────────────────
    ("Barbell Squat",                "Legs",      "Barbell"),
    ("Front Squat",                  "Legs",      "Barbell"),
    ("Low Bar Squat",                "Legs",      "Barbell"),
    ("Pause Squat",                  "Legs",      "Barbell"),
    ("Hack Squat",                   "Legs",      "Machine"),
    ("Smith Machine Squat",          "Legs",      "Machine"),
    ("Leg Press",                    "Legs",      "Machine"),
    ("Single-Leg Press",             "Legs",      "Machine"),
    ("Leg Extension",                "Legs",      "Machine"),
    ("Goblet Squat",                 "Legs",      "Dumbbell"),
    ("Dumbbell Squat",               "Legs",      "Dumbbell"),
    ("Bulgarian Split Squat",        "Legs",      "Dumbbell"),
    ("Lunges",                       "Legs",      "Dumbbell"),
    ("Walking Lunges",               "Legs",      "Dumbbell"),
    ("Reverse Lunge",                "Legs",      "Dumbbell"),
    ("Step Up",                      "Legs",      "Dumbbell"),
    ("Sissy Squat",                  "Legs",      "Bodyweight"),

    # ── Legs — Hamstrings / Glutes ─────────────────────────────────────────
    ("Romanian Deadlift",            "Legs",      "Barbell"),
    ("Stiff-Leg Deadlift",           "Legs",      "Barbell"),
    ("Leg Curl",                     "Legs",      "Machine"),
    ("Seated Leg Curl",              "Legs",      "Machine"),
    ("Nordic Curl",                  "Legs",      "Bodyweight"),
    ("Hip Thrust",                   "Legs",      "Barbell"),
    ("Glute Bridge",                 "Legs",      "Bodyweight"),
    ("Cable Kickback",               "Legs",      "Cable"),
    ("Sumo Squat",                   "Legs",      "Dumbbell"),

    # ── Legs — Calves ──────────────────────────────────────────────────────
    ("Standing Calf Raise",          "Legs",      "Machine"),
    ("Seated Calf Raise",            "Legs",      "Machine"),
    ("Leg Press Calf Raise",         "Legs",      "Machine"),
    ("Single-Leg Calf Raise",        "Legs",      "Bodyweight"),

    # ── Core ───────────────────────────────────────────────────────────────
    ("Plank",                        "Core",      "Bodyweight"),
    ("Side Plank",                   "Core",      "Bodyweight"),
    ("Crunch",                       "Core",      "Bodyweight"),
    ("Sit Up",                       "Core",      "Bodyweight"),
    ("Decline Sit Up",               "Core",      "Bodyweight"),
    ("Leg Raise",                    "Core",      "Bodyweight"),
    ("Hanging Leg Raise",            "Core",      "Bodyweight"),
    ("Hanging Knee Raise",           "Core",      "Bodyweight"),
    ("Toes to Bar",                  "Core",      "Bodyweight"),
    ("Cable Crunch",                 "Core",      "Cable"),
    ("Pallof Press",                 "Core",      "Cable"),
    ("Ab Wheel Rollout",             "Core",      "Other"),
    ("Dragon Flag",                  "Core",      "Bodyweight"),
    ("Russian Twist",                "Core",      "Bodyweight"),
    ("Weighted Russian Twist",       "Core",      "Other"),
    ("Bicycle Crunch",               "Core",      "Bodyweight"),
    ("Dead Bug",                     "Core",      "Bodyweight"),
    ("Hollow Body Hold",             "Core",      "Bodyweight"),
    ("V-Up",                         "Core",      "Bodyweight"),
    ("Mountain Climber",             "Core",      "Bodyweight"),

    # ── Cardio ─────────────────────────────────────────────────────────────
    ("Treadmill Run",                "Cardio",    "Machine"),
    ("Stationary Bike",              "Cardio",    "Machine"),
    ("Rowing Machine",               "Cardio",    "Machine"),
    ("Elliptical",                   "Cardio",    "Machine"),
    ("Stair Climber",                "Cardio",    "Machine"),
    ("Jump Rope",                    "Cardio",    "Other"),
    ("Burpee",                       "Cardio",    "Bodyweight"),
    ("Box Jump",                     "Cardio",    "Bodyweight"),
    ("Jumping Jack",                 "Cardio",    "Bodyweight"),
    ("Battle Ropes",                 "Cardio",    "Other"),

    # ── Full Body / Olympic ────────────────────────────────────────────────
    ("Barbell Clean",                "Full Body", "Barbell"),
    ("Power Clean",                  "Full Body", "Barbell"),
    ("Hang Clean",                   "Full Body", "Barbell"),
    ("Barbell Snatch",               "Full Body", "Barbell"),
    ("Thruster",                     "Full Body", "Barbell"),
    ("Kettlebell Swing",             "Full Body", "Other"),
    ("Turkish Get-Up",               "Full Body", "Other"),
    ("Farmer's Carry",               "Full Body", "Dumbbell"),
    ("Sled Push",                    "Full Body", "Other"),
    ("Wall Ball",                    "Full Body", "Other"),
]

from app.models.exercise import Exercise

db = SessionLocal()

existing_names = {ex.name for ex in db.query(Exercise.name).filter(Exercise.is_default == True).all()}
now = datetime.now(timezone.utc)
added = 0

for name, muscle_group, equipment in EXERCISES:
    if name in existing_names:
        continue
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
total = db.query(Exercise).filter(Exercise.is_default == True).count()
db.close()
print(f"Added {added} new exercises. Total default exercises: {total}.")
