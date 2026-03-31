# Titan SMRT - Complete User Guide

**Comprehensive guide for setting up, testing, and deploying Titan SMRT fitness tracking application**

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Backend Setup](#backend-setup)
3. [App Features Overview](#app-features-overview)
4. [Testing Guide](#testing-guide)
5. [Deployment Options](#deployment-options)
6. [Troubleshooting](#troubleshooting)
7. [Development Guide](#development-guide)

---

## Quick Start

### Prerequisites

- **Computer**: macOS, Windows, or Linux
- **Docker**: Installed and running
- **Flutter SDK**: 3.19.0 or higher
- **Python**: 3.8 or higher (for backend)
- **Git**: For version control (optional but recommended)
- **Xcode**: For iOS development (on macOS)
- **Android Studio**: For Android development (optional)

### Initial Setup

1. **Clone the Repository**
   ```bash
   cd ~/Documents
   git clone <your-repo-url> titan-smrt
   cd titan-smrt
   ```

2. **Verify Project Structure**
   ```
   titan-smrt/
   ├── fastapi_service/      # Backend API
   ├── flutter_app/          # Mobile app
   ├── docs/                 # Documentation
   ├── DEPLOYMENT.md          # Deployment guide
   ├── APP_STORE_SUBMISSION.md # App store guide
   ├── PRIVACY_POLICY.md       # Privacy policy
   └── PRODUCTION_READINESS.md # Readiness checklist
   ```

---

## Backend Setup

### Option 1: Docker (Recommended)

This is the easiest way to get started quickly.

#### Step 1: Start Backend Services

```bash
cd "IOS Developer/Titan/titan-smrt/fastapi_service"

# Start PostgreSQL and API together
docker-compose up -d

# Verify services are running
docker-compose ps

# Check logs
docker-compose logs -f api
```

**What this does:**
- Starts PostgreSQL database on port 5432
- Starts FastAPI backend on port 8000
- Creates database tables automatically
- Runs database migrations

#### Step 2: Access API Documentation

Open your browser and go to:
```
http://localhost:8000/docs
```

This provides interactive API documentation where you can test all endpoints.

#### Step 3: Configure Flutter App

The Flutter app is already configured to connect to `http://192.168.1.102:8000`

**To test locally, change the API URL:**

1. Open [`flutter_app/lib/main.dart`](flutter_app/lib/main.dart:15)
2. Find this line:
   ```dart
   final authController = AuthController(
     AuthService('http://192.168.1.102:8000')
   );
   ```
3. Change to `http://localhost:8000`
4. Save the file
5. Hot reload the app (press `r` in terminal)

#### Step 4: Run Flutter App

```bash
cd "IOS Developer/Titan/titan-smrt/flutter_app"

# Install dependencies
flutter pub get

# Run the app
flutter run
```

**The app will now connect to your local backend!**

### Option 2: Manual Setup (For Development)

If you prefer not to use Docker:

#### Step 1: Install Python Dependencies

```bash
cd "IOS Developer/Titan/titan-smrt/fastapi_service"

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

#### Step 2: Set Up PostgreSQL

```bash
# Install PostgreSQL (macOS)
brew install postgresql
brew services start postgresql

# Or use Docker
docker run -d --name titan-postgres \
  -e POSTGRES_PASSWORD=yourpassword \
  -p 5432:5432 \
  postgres:15-alpine
```

#### Step 3: Configure Database

```bash
# Create database
createdb titan_db

# Create user
psql -d titan_db
CREATE USER titan_user WITH PASSWORD 'yourpassword';
GRANT ALL PRIVILEGES ON DATABASE titan_db TO titan_user;

# Run migrations
cd "IOS Developer/Titan/titan-smrt/fastapi_service"
export DATABASE_URL="postgresql://titan_user:yourpassword@localhost:5432/titan_db"
alembic upgrade head
```

#### Step 4: Start Backend Server

```bash
cd "IOS Developer/Titan/titan-smrt/fastapi_service"

# Run with uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or run with gunicorn (production)
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

---

## App Features Overview

### Core Features

#### 1. Workout Tracking

**Smart Start:**
- Auto-loads today's routine
- One-tap workout initialization
- Predicts exercises based on history

**Set Logging:**
- Weight input (kg/lbs)
- Reps counter
- RPE (Rate of Perceived Exertion) slider
- Rest timer with audio cues
- Auto-rest between sets

**Workout Management:**
- Active workout card with live timer
- Session history
- Volume tracking
- PR detection and celebration

#### 2. Exercise Library

**Default Exercises:**
- 500+ pre-loaded exercises
- Video demonstrations (GIF/MP4)
- Muscle group categorization
- Equipment filtering

**Custom Exercises:**
- Create your own exercises
- Add media (GIF/MP4)
- Set muscle groups and equipment

**Routine Templates:**
- Create workout templates
- Add exercises to routines
- Set default sets and reps
- Reorder exercises

#### 3. Analytics Dashboard

**Performance Metrics:**
- Muscle group heatmaps
- Volume trends over time
- PR leaderboard
- Progress charts

**AI Insights:**
- Plateau detection
- Form analysis (with video upload)
- Progression analysis
- Personalized recommendations

#### 4. Nutrition Tracking

**Daily Logging:**
- Protein (grams)
- Carbs (grams)
- Fats (grams)
- Automatic calorie calculation

**Goal Alignment:**
- Strength training
- Hypertrophy (muscle building)
- Fat loss
- Custom goals

#### 5. User Profile

**Personal Information:**
- Age, gender, height, weight
- Fitness goals
- Activity level

**Settings:**
- Theme selection (dark/light)
- Audio cues on/off
- Haptic feedback on/off
- Data export

#### 6. Subscription & Monetization

**Free Tier:**
- Basic workout logging
- Exercise library access
- Routine templates
- Offline support
- Basic analytics

**Pro Tier ($9.99/month):**
- All Free features
- AI form analysis
- Progression insights
- Hardware integration (Apple Watch, Garmin)
- Advanced analytics
- Priority support

**7-Day Free Trial:**
- No credit card required
- Full Pro access
- Cancel anytime

---

## Testing Guide

### Manual Testing Checklist

#### Backend Testing

- [ ] All API endpoints respond correctly
- [ ] Authentication works (register, login, logout)
- [ ] Workout CRUD operations work
- [ ] Exercise library endpoints work
- [ ] AI insights return valid data
- [ ] Sync handles conflicts properly
- [ ] Error responses are appropriate

#### Mobile App Testing

- [ ] App launches without crashes
- [ ] All screens load correctly
- [ ] Navigation works between all tabs
- [ ] Buttons and gestures respond properly
- [ ] Forms validate input correctly
- [ ] Offline mode functions correctly
- [ ] Sync works in both directions
- [ ] Push notifications (if implemented)
- [ ] Haptic feedback works throughout
- [ ] Timers count down correctly

### Automated Testing

#### Backend Tests

```bash
cd "IOS Developer/Titan/titan-smrt/fastapi_service"

# Run tests (when implemented)
pytest

# Run with coverage
pytest --cov=app --cov-report=html
```

#### Mobile Tests

```bash
cd "IOS Developer/Titan/titan-smrt/flutter_app"

# Run widget tests
flutter test

# Run integration tests
flutter test integration_test

# Run with coverage
flutter test --coverage
```

### Device Testing

**Android:**
- Test on API 21 (minimum)
- Test on latest Android version
- Test on different screen sizes
- Test with different network conditions

**iOS:**
- Test on iOS 12.0 (minimum)
- Test on different iPhone models
- Test on iPad (if supported)
- Test with different network conditions

---

## Deployment Options

### Option 1: Local Development

**For personal testing and development:**

1. **Backend**: Use Docker Compose locally
2. **Mobile**: Run with `flutter run` on connected device
3. **Database**: Local PostgreSQL instance
4. **Network**: Same machine, use localhost

**Pros:**
- Full control over environment
- Easy debugging
- No hosting costs
- Fast iteration

**Cons:**
- Not accessible to others
- Requires your machine to be on
- Not production-ready

### Option 2: Cloud Deployment (Production)

**For public app:**

#### A. VPS/Cloud Instance

**Recommended Providers:**
- DigitalOcean: $5-20/month
- Linode: $5-20/month
- AWS EC2: $10-50/month
- Google Cloud: $10-50/month

**Setup Steps:**

1. **Choose Provider and Create Instance**
   - Select: Ubuntu 22.04 LTS
   - Size: 2GB RAM, 1 vCPU (minimum)
   - Storage: 20GB SSD

2. **Connect to Instance**
   ```bash
   ssh root@your-server-ip
   ```

3. **Install Docker**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   sudo usermod -aG docker
   ```

4. **Clone and Deploy**
   ```bash
   git clone <your-repo-url> titan-smrt
   cd titan-smrt/fastapi_service
   
   # Configure environment
   cp .env.example .env
   nano .env  # Update with production values
   
   # Build and start
   docker-compose up -d --build
   docker-compose exec api alembic upgrade head
   ```

#### B. Managed Database Services

**Recommended Providers:**
- Supabase: Free tier + paid plans
- Neon: Serverless PostgreSQL
- PlanetScale: Managed PostgreSQL
- Railway: Free tier available

**Setup Steps:**

1. **Create Account** on provider's website
2. **Create Project** and get connection string
3. **Update Environment Variables**
   ```bash
   DATABASE_URL=postgresql://user:password@provider-host:5432/dbname
   ```
4. **Run Migrations**
   ```bash
   alembic upgrade head
   ```

#### C. Serverless Functions

**Recommended Providers:**
- Vercel: Free tier available
- Railway: Free tier available
- Fly.io: Free tier available

**Setup Steps:**

1. **Connect Repository** to provider
2. **Configure Environment Variables** in provider dashboard
3. **Deploy** using provider's CLI tool
4. **Update Flutter API URL** to production domain

### Option 3: Hybrid Deployment

**For optimal performance:**

1. **Database**: Managed PostgreSQL service (Supabase, Neon)
2. **Backend**: Serverless functions (Vercel, Railway)
3. **Static Assets**: CDN for images (Cloudflare, AWS S3)
4. **Mobile**: Build and deploy to app stores

**Benefits:**
- Automatic scaling
- No server management
- Global CDN for fast loading
- Cost-effective for small scale

---

## Troubleshooting

### Common Issues

#### Backend Won't Start

**Symptoms:**
- Docker containers won't start
- Port already in use
- Database connection refused

**Solutions:**
```bash
# Check what's using ports
lsof -i :8000

# Kill processes using ports
kill -9 :8000

# Remove Docker containers
docker-compose down

# Start fresh
docker-compose up -d

# Check logs
docker-compose logs api
```

#### Flutter App Won't Connect to Backend

**Symptoms:**
- Connection timeout errors
- 401 Unauthorized errors
- "No internet connection" messages

**Solutions:**

1. **Verify Backend is Running**
   ```bash
   docker-compose ps
   curl http://localhost:8000/v1/health
   ```

2. **Check API URL in Flutter App**
   - Open [`flutter_app/lib/main.dart`](flutter_app/lib/main.dart:15)
   - Verify URL matches backend
   - Try `http://localhost:8000` instead of `http://192.168.1.102:8000`

3. **Check Network**
   - Ensure phone and computer on same network
   - Try using computer IP instead of localhost
   - Disable VPN if enabled

4. **Check Backend Logs**
   ```bash
   docker-compose logs -f api
   ```

#### Database Errors

**Symptoms:**
- Migration failures
- Table doesn't exist
- Permission denied

**Solutions:**
```bash
# Check database connection
docker-compose exec api psql -U titan_user -d titan_db -c "SELECT 1;"

# Run migrations manually
alembic upgrade head

# Check logs
docker-compose logs postgres
```

#### Sync Conflicts

**Symptoms:**
- Data not syncing
- "Conflict detected" messages
- Lost data after sync

**Solutions:**

1. **Check Network Connection**
   - Ensure backend is accessible
   - Check API URL in app settings

2. **Review Conflicts Screen**
   - Go to Profile → Conflict Audit Log
   - Choose which version to keep (local or server)

3. **Force Sync**
   - Pull down to refresh in sync screen
   - This will re-fetch all data from server

#### Build Failures

**Symptoms:**
- Flutter build fails
- Dependencies won't install
- Code analysis errors

**Solutions:**
```bash
# Clean Flutter cache
cd "IOS Developer/Titan/titan-smrt/flutter_app"
flutter clean

# Get dependencies
flutter pub get

# Check Flutter version
flutter doctor

# Upgrade Flutter if needed
flutter upgrade
```

### Getting Help

#### Documentation

- **Backend**: See [`fastapi_service/README.md`](fastapi_service/README.md)
- **Mobile**: See [`flutter_app/README.md`](flutter_app/README.md)
- **Deployment**: See [`DEPLOYMENT.md`](DEPLOYMENT.md)
- **App Store**: See [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md)

#### Support Channels

- **Email**: support@titanapp.com
- **GitHub Issues**: Report bugs at project repository
- **Community**: Check for existing issues and discussions

---

## Development Guide

### Understanding the Architecture

#### Backend Architecture

```
fastapi_service/
├── app/
│   ├── main.py              # FastAPI application entry point
│   ├── api/                 # API route handlers
│   │   ├── auth.py          # Authentication endpoints
│   │   ├── workout.py       # Workout management
│   │   ├── ai.py            # AI insights
│   │   ├── library.py        # Exercise/routine library
│   │   ├── nutrition.py     # Nutrition tracking
│   │   ├── profile.py       # User profile
│   │   └── sync.py          # Data synchronization
│   ├── core/
│   │   ├── config.py        # Configuration settings
│   │   ├── database.py      # Database connection
│   │   ├── security.py       # Password hashing, JWT
│   │   └── logging.py       # Request/error logging
│   ├── models/               # SQLAlchemy models
│   ├── schemas/              # Pydantic schemas
│   └── services/             # Business logic
├── alembic/                 # Database migrations
├── Dockerfile               # Container build
├── docker-compose.yml        # Service orchestration
└── requirements.txt          # Python dependencies
```

#### Mobile App Architecture

```
flutter_app/
├── lib/
│   ├── main.dart             # App entry point
│   ├── app.dart              # Root widget
│   ├── theme.dart            # App theming
│   ├── navigation/           # Navigation structure
│   ├── screens/             # UI screens
│   ├── widgets/             # Reusable components
│   └── services/            # Business logic
├── android/                # Android build files
├── ios/                    # iOS build files
└── pubspec.yaml           # Dependencies
```

### Adding New Features

#### Backend: Adding a New API Endpoint

1. **Create Schema** in [`app/models/`](fastapi_service/app/models/)
   ```python
   from sqlalchemy import Column, String, Float
   from .base import Base
   
   class NewModel(Base):
       __tablename__ = "new_table"
       id = Column(String, primary_key=True)
       name = Column(String)
       value = Column(Float)
   ```

2. **Create Pydantic Schema** in [`app/schemas/`](fastapi_service/app/schemas/)
   ```python
   from pydantic import BaseModel
   
   class NewSchema(BaseModel):
       name: str
       value: float
   ```

3. **Create API Route** in [`app/api/`](fastapi_service/app/api/)
   ```python
   from fastapi import APIRouter, Depends
   from ..core.database import get_db
   from ..core.auth import get_current_user
   
   router = APIRouter(prefix="/new-endpoint")
   
   @router.post("/")
   def create_item(item: NewSchema, db = Depends(get_db), current_user = Depends(get_current_user)):
       # Implementation here
       pass
   ```

4. **Register Router** in [`app/api/router.py`](fastapi_service/app/api/router.py)
   ```python
   from .new_endpoint import router as new_router
   
   api_router.include_router(new_router)
   ```

5. **Create Migration** in [`alembic/versions/`](fastapi_service/alembic/versions/)
   ```bash
   alembic revision --autogenerate -m "Add new table"
   ```

#### Mobile: Adding a New Screen

1. **Create Screen File** in [`lib/screens/`](flutter_app/lib/screens/)
   ```dart
   import 'package:flutter/material.dart';
   import '../widgets/staggered_fade_in.dart';
   
   class NewScreen extends StatelessWidget {
     const NewScreen({super.key});
   
     @override
     Widget build(BuildContext context) {
       return SafeArea(
         child: StaggeredFadeIn(
           child: ListView(
             padding: const EdgeInsets.all(16),
             children: [
               Text('New Screen', style: Theme.of(context).textTheme.headlineLarge),
               // Add your widgets here
             ],
           ),
         ),
       );
     }
   }
   ```

2. **Add Navigation** in [`lib/app.dart`](flutter_app/lib/app.dart)
   ```dart
   // Add to screens list
   '/new-screen': (context) => const NewScreen(),
   ```

3. **Create Service** (if needed) in [`lib/services/`](flutter_app/lib/services/)
   ```dart
   // Add business logic for new screen
   ```

### Code Quality Standards

#### Backend

- **Type Hints**: Use Python type hints
- **Docstrings**: Add docstrings to all functions
- **Error Handling**: Use try/except blocks
- **Validation**: Use Pydantic schemas
- **SQL Injection**: Always use parameterized queries

#### Mobile

- **Dart Analysis**: Run `flutter analyze` before committing
- **Code Formatting**: Run `flutter format` on all files
- **Widget Tests**: Write tests for custom widgets
- **Integration Tests**: Test service layer separately
- **Const Usage**: Use `const` where possible

### Testing Checklist

Before deploying to production:

#### Backend
- [ ] All endpoints tested manually
- [ ] Unit tests written for critical logic
- [ ] Database migrations tested on clean database
- [ ] Error handling verified for all endpoints
- [ ] Authentication flow tested end-to-end
- [ ] Rate limiting tested
- [ ] CORS configuration verified

#### Mobile
- [ ] All screens tested on multiple devices
- [ ] Offline mode tested thoroughly
- [ ] Sync functionality tested with conflicts
- [ ] Performance tested on low-end devices
- [ ] Memory usage acceptable
- [ ] No crashes during testing
- [ ] All user flows tested end-to-end

---

## Quick Reference

### Important Files

| File | Purpose |
|--------|----------|
| [`fastapi_service/app/main.py`](fastapi_service/app/main.py) | Backend entry point |
| [`flutter_app/lib/main.dart`](flutter_app/lib/main.dart) | Mobile app entry point |
| [`fastapi_service/.env.example`](fastapi_service/.env.example) | Environment template |
| [`DEPLOYMENT.md`](DEPLOYMENT.md) | Deployment guide |
| [`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md) | App store submission |

### Environment Variables

| Variable | Description | Default |
|-----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:password@localhost:5432/titan_db` |
| `SECRET_KEY` | JWT signing key | Change in production! |
| `DEBUG` | Debug mode | `false` |
| `API_V1_PREFIX` | API path prefix | `/v1` |

### Common Commands

```bash
# Backend
docker-compose up -d                    # Start all services
docker-compose logs -f api             # Follow API logs
docker-compose exec api bash            # Enter API container
alembic upgrade head                 # Run migrations
alembic downgrade -1                # Rollback one migration

# Mobile
flutter run                            # Run app in debug mode
flutter build apk --release             # Build Android APK
flutter build ios --release             # Build iOS app
flutter test                           # Run tests
flutter doctor                         # Diagnose issues
```

---

## Next Steps

1. **Choose Your Setup**: Decide between Docker (recommended) or manual setup
2. **Follow Quick Start**: Use the step-by-step guide above
3. **Test Thoroughly**: Use the testing checklist
4. **Deploy When Ready**: Follow deployment guide for your chosen option
5. **Monitor Launch**: Track performance and user feedback

---

## Support

**Documentation**: See individual README files in each directory
**Email**: support@titanapp.com
**Issues**: Report bugs at project repository

---

*Last Updated: January 1, 2024*  
*Version: 1.0.0*
