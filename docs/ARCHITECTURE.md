# Titan Architecture Overview

This repo contains two primary components:

- flutter_app: Flutter client for offline-first UX, BLE, camera, and analytics.
- fastapi_service: FastAPI backend for auth, logging, AI analysis, and sync.

The source-of-truth spec lives at docs/TITAN_SPEC.md.

## High-Level Flow

1) Client starts workout and writes to local SQLite.
2) Sync worker batches dirty records and POSTs to /api/v1/sync.
3) Server persists to PostgreSQL and returns conflicts when needed.
4) AI services process workouts and return insights to the client.

## Repo Structure

- docs/
  - TITAN_SPEC.md
  - ARCHITECTURE.md
  - UX_FLOWS.md
  - API_CONTRACTS.md
- flutter_app/
  - lib/
    - main.dart
    - app.dart
    - theme.dart
    - navigation/
    - screens/
    - widgets/
- fastapi_service/
  - app/
    - main.py
    - api/
    - core/
    - models/
    - schemas/
    - services/

