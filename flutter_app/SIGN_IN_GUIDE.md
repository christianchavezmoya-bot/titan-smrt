# Titan Sign-In & API Setup Guide

## 📱 How Sign-In Works

Titan requires a backend API for authentication. The app supports:
- **Email/Password Registration & Login**
- **JWT Token-based Authentication**

---

## 🚀 Quick Start: Run the Existing FastAPI Backend

The project includes a complete FastAPI backend. Here's how to run it:

### Option 1: Run FastAPI Locally (Recommended for Development)

```bash
# Navigate to FastAPI service
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/fastapi_service

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run database migrations
alembic upgrade head

# Start the server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`

### Option 2: Run with Docker

```bash
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/fastapi_service
docker-compose up -d
```

---

## 🔧 Configure the App to Use Your API

### Step 1: Find Your Mac's IP Address

```bash
ipconfig getifaddr en0
# Example output: 10.7.15.96
```

### Step 2: Update the API URL in main.dart

Edit `flutter_app/lib/main.dart`:

```dart
// Change this line:
final authController = AuthController(AuthService('http://10.7.15.96:8000'));

// To your Mac's IP address:
final authController = AuthController(AuthService('http://YOUR_MAC_IP:8000'));
```

Or for iOS simulator, you can use localhost:
```dart
final authController = AuthController(AuthService('http://localhost:8000'));
```

---

## 📝 Sign-In Process

### First Time: Register

1. Open the app on your iPhone
2. Tap **"Need an account? Register"**
3. Enter:
   - **Email**: Your email address
   - **Username**: A display name
   - **Password**: Your password
4. Tap **"Create account"**

### After Registration: Sign In

1. Enter your **Email** and **Password**
2. Tap **"Sign in"**
3. You'll be logged in and see the main app

---

## 🧪 Test API Connection

The app has a built-in API test button:

1. On the sign-in screen, tap **"Test API"**
2. If successful, you'll see "API reachable"
3. If it fails, check:
   - Is the FastAPI server running?
   - Is the URL correct?
   - Are you on the same WiFi network?

---

## 🔍 Troubleshooting

### "API failed" Error

1. **Check server is running:**
   ```bash
   curl http://localhost:8000/v1/health
   # Should return: {"status": "ok"}
   ```

2. **Check firewall:**
   - System Settings → Network → Firewall
   - Make sure Python or port 8000 is allowed

3. **Check IP address:**
   - Make sure the URL in `main.dart` matches your Mac's IP
   - Your iPhone and Mac must be on the same WiFi network

### "Unable to authenticate" Error

1. **Check the server logs:**
   ```bash
   # In the FastAPI terminal, you'll see error messages
   ```

2. **Try registering first:**
   - Make sure you've created an account before signing in

### Connection Timeout on Real iPhone

For a physical iPhone, you MUST use your Mac's IP address (not localhost):

```dart
// CORRECT for physical iPhone:
AuthService('http://10.7.15.96:8000')  // Your Mac's IP

// WRONG for physical iPhone:
AuthService('http://localhost:8000')  // This won't work
```

---

## 🗄️ Check Registered Users

```bash
# Connect to the database
cd fastapi_service
sqlite3 titan.db

# List all users
SELECT id, email, username FROM users;
```

---

## 📊 API Endpoints

The FastAPI backend provides:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/health` | GET | Health check |
| `/v1/auth/register` | POST | Create account |
| `/v1/auth/login` | POST | Sign in |
| `/v1/profile` | GET | Get user profile |
| `/v1/workouts` | GET/POST | Workout CRUD |
| `/v1/exercises` | GET | Exercise library |

### Example: Register via curl

```bash
curl -X POST http://localhost:8000/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","username":"testuser","password":"password123"}'
```

### Example: Login via curl

```bash
curl -X POST http://localhost:8000/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## ✅ Quick Checklist

Before running the app:

- [ ] FastAPI server is running (`uvicorn app.main:app --host 0.0.0.0 --port 8000`)
- [ ] Database is migrated (`alembic upgrade head`)
- [ ] IP address in `main.dart` is correct
- [ ] iPhone and Mac are on same WiFi
- [ ] Test API button shows "API reachable"

---

## 🎉 You're Ready!

Once everything is set up:

1. Run the FastAPI server
2. Launch the Flutter app on your iPhone
3. Tap "Test API" to verify connection
4. Register a new account
5. Sign in and start using Titan!