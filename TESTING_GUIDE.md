# Titan Super Fitness App - Testing Guide

This guide covers all testing approaches for the Titan project.

## 📱 Testing the Flutter App

### Prerequisites
```bash
# Install Flutter (if not already installed)
brew install flutter

# Verify installation
flutter doctor

# Navigate to Flutter app
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/flutter_app
```

### Run on Simulator/Emulator

**iOS Simulator:**
```bash
# List available simulators
flutter devices

# Run on iOS simulator
flutter run -d ios

# Or specify a device
flutter run -d "iPhone 15 Pro"
```

**Android Emulator:**
```bash
# Run on Android emulator
flutter run -d android

# Or specify a device
flutter run -d "Pixel_8_API_34"
```

### Run on Physical Device

1. **iOS**: Connect device via USB, trust computer on device
2. **Android**: Enable USB debugging in Developer Options
```bash
flutter run
```

### Hot Reload
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

### Widget Tests
```bash
# Run all widget tests
flutter test

# Run with coverage
flutter test --coverage
```

---

## 🐳 Testing Backend Services (Docker)

### Start All Services
```bash
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/infrastructure/docker-compose

# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### Test Individual Services

**User Auth Service:**
```bash
# Health check
curl http://localhost:8080/health

# Register user
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'

# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

**Tracking Telemetry Service:**
```bash
# Health check
curl http://localhost:8081/health

# Submit telemetry
curl -X POST http://localhost:8081/api/v1/telemetry/batch \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "user_id": "user123",
    "session_id": "session456",
    "metrics": [
      {"type": "heart_rate", "value": 85, "timestamp": "2026-07-04T12:00:00Z"}
    ]
  }'
```

**AI Coach Service:**
```bash
# Health check
curl http://localhost:8083/health

# Calculate recovery score
curl -X POST http://localhost:8083/api/v1/ai/recovery/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user123",
    "hrv": 65.5,
    "resting_hr": 58,
    "sleep_duration": 7.5,
    "sleep_quality": 80,
    "yesterday_strain": 12.5
  }'

# Get AI insights
curl http://localhost:8083/api/v1/ai/insights/user123
```

**Social Community Service:**
```bash
# Health check
curl http://localhost:8082/health

# Get feed
curl -X GET "http://localhost:8082/api/v1/social/feed/user123?limit=20"

# Create post
curl -X POST http://localhost:8082/api/v1/social/posts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "user_id": "user123",
    "content": "Just finished a great workout!",
    "type": "workout_complete"
  }'
```

**Billing Service:**
```bash
# Health check
curl http://localhost:8084/health

# Get available plans
curl http://localhost:8084/api/v1/billing/plans

# Check entitlements
curl http://localhost:8084/api/v1/billing/entitlements/user123
```

---

## 🧪 Unit Testing Services

### Go Services (user-auth, tracking-telemetry)
```bash
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/services/user-auth

# Run tests
go test ./...

# Run with coverage
go test -cover ./...

# Run specific test
go test -run TestRegisterUser ./...
```

### Python Services (ai-coach, billing-subscription)
```bash
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/services/ai-coach

# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests
pytest

# Run with coverage
pytest --cov=app
```

### Node.js Service (social-community)
```bash
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/services/social-community

# Install dependencies
npm install

# Run tests
npm test

# Run with coverage
npm run test:coverage
```

---

## 🔄 End-to-End Testing

### Using the Flutter App with Backend

1. **Start backend services:**
```bash
cd infrastructure/docker-compose
docker-compose up -d
```

2. **Update Flutter API client:**
Edit `flutter_app/lib/services/api_client_v2.dart`:
```dart
static const String baseUrl = 'http://localhost:8000'; // Kong Gateway
// Or directly to service:
// static const String baseUrl = 'http://localhost:8080';
```

3. **Run Flutter app:**
```bash
flutter run
```

---

## 🗄️ Database Testing

### PostgreSQL
```bash
# Connect to PostgreSQL
docker exec -it titan-postgres-main psql -U titan -d titan_main

# List tables
\dt

# Query users
SELECT * FROM users;
```

### TimescaleDB
```bash
# Connect to TimescaleDB
docker exec -it titan-timescaledb psql -U titan -d titan_telemetry

# Query telemetry
SELECT * FROM telemetry ORDER BY timestamp DESC LIMIT 10;
```

### Redis
```bash
# Connect to Redis
docker exec -it titan-redis redis-cli

# Get all keys
KEYS *

# Get specific key
GET user:user123:session
```

---

## 📊 Monitoring & Debugging

### Grafana Dashboards
```bash
# Open Grafana
open http://localhost:3000
# Default: admin/admin
```

### Prometheus Metrics
```bash
# Open Prometheus
open http://localhost:9090
```

### Service Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f user-auth
docker-compose logs -f ai-coach
```

---

## ⚡ Quick Integration Test Script

Create and run this script to test all services:

```bash
#!/bin/bash
# save as test-services.sh

echo "Testing Titan Services..."

# Test User Auth
echo "1. Testing User Auth..."
curl -s http://localhost:8080/health | jq .

# Test Tracking
echo "2. Testing Tracking..."
curl -s http://localhost:8081/health | jq .

# Test AI Coach
echo "3. Testing AI Coach..."
curl -s http://localhost:8083/health | jq .

# Test Social
echo "4. Testing Social..."
curl -s http://localhost:8082/health | jq .

# Test Billing
echo "5. Testing Billing..."
curl -s http://localhost:8084/health | jq .

echo "All services tested!"
```

```bash
chmod +x test-services.sh
./test-services.sh
```

---

## 🐛 Troubleshooting

### Flutter Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Docker Issues
```bash
# Reset everything
docker-compose down -v
docker-compose up -d

# View container logs
docker-compose logs -f --tail=100
```

### Port Conflicts
```bash
# Check what's using a port
lsof -i :8080

# Kill process
kill -9 <PID>