# Titan SMRT - Production Deployment Guide

Complete guide for deploying Titan SMRT to production environments.

## Table of Contents

1. [Backend Deployment](#backend-deployment)
2. [Flutter App Deployment](#flutter-app-deployment)
3. [Database Setup](#database-setup)
4. [Environment Configuration](#environment-configuration)
5. [Monitoring & Logging](#monitoring--logging)
6. [Security Checklist](#security-checklist)
7. [Troubleshooting](#troubleshooting)

---

## Backend Deployment

### Prerequisites

- Docker and Docker Compose installed
- PostgreSQL database (or use Docker)
- Domain name configured
- SSL certificate (recommended)

### Quick Deploy with Docker

```bash
# Clone repository
git clone <your-repo-url>
cd titan-smrt/fastapi_service

# Configure environment
cp .env.example .env
nano .env  # Update with production values

# Build and start
docker-compose up -d --build

# Run migrations
docker-compose exec api alembic upgrade head

# Check health
curl https://your-api-domain.com/v1/health
```

### Manual Deployment

```bash
# Install dependencies
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configure environment
export DATABASE_URL="postgresql://user:password@host:5432/titan_db"
export SECRET_KEY="your-production-secret-key"

# Run migrations
alembic upgrade head

# Start with gunicorn
gunicorn app.main:app \
  -w 4 \
  -k uvicorn.workers.UvicornWorker \
  -b 0.0.0.0:8000 \
  --access-logfile - \
  --error-logfile - \
  --log-level info
```

### Nginx Configuration (Reverse Proxy)

```nginx
server {
    listen 80;
    server_name your-api-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## Flutter App Deployment

### Android Deployment

#### 1. Configure Signing

```bash
# Generate keystore
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Create keystore.properties
cat > android/app/keystore.properties << EOF
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
EOF
```

#### 2. Build Release APK

```bash
cd flutter_app

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Output location
# APK: build/app/outputs/flutter-apk/app-release.apk
# Bundle: build/app/outputs/bundle/release/app-release.aab
```

#### 3. Upload to Google Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Create new application
3. Upload `app-release.aab`
4. Complete store listing:
   - Title: Titan SMRT
   - Short description: Smart fitness tracking with AI-powered coaching
   - Full description: [Use app description]
   - Screenshots: Upload required screenshots
   - Icon: 512x512 PNG
5. Set pricing: Free with in-app purchases
6. Submit for review

### iOS Deployment

#### 1. Configure Signing

```bash
cd flutter_app/ios

# Update bundle identifier
open Runner.xcworkspace
# Change bundle identifier to com.yourcompany.titan

# Configure signing in Xcode
open Runner.xcworkspace
# Project > Signing & Capabilities > Automatically manage signing
```

#### 2. Build Release

```bash
# Build for App Store
flutter build ios --release

# Archive in Xcode
open ios/Runner.xcworkspace
# Product > Archive > Distribute App
```

#### 3. Upload to App Store

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create new app
3. Upload from Xcode or Transporter
4. Complete app information:
   - App name: Titan SMRT
   - Description: Smart fitness tracking with AI-powered coaching
   - Screenshots: Required for all devices
   - App icon: 1024x1024
5. Set pricing and availability
6. Submit for review

---

## Database Setup

### PostgreSQL Production Configuration

```sql
-- Create database and user
CREATE DATABASE titan_db;
CREATE USER titan_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE titan_db TO titan_user;

-- Enable extensions
\c titan_db
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### Backup Strategy

```bash
# Daily backup
0 2 * * * pg_dump -U titan_user titan_db > /backups/titan_$(date +\%Y\%m\%d).sql

# Restore
psql -U titan_user titan_db < /backups/titan_2024_01_01.sql
```

---

## Environment Configuration

### Required Environment Variables

```bash
# API Configuration
API_V1_PREFIX=/v1
PROJECT_NAME=Titan API
VERSION=1.0.0
DEBUG=false

# Security (CRITICAL)
SECRET_KEY=generate-with-openssl-rand-hex-32
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname

# CORS
BACKEND_CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com

# File Upload
MAX_UPLOAD_SIZE=52428800
UPLOAD_DIR=/var/www/uploads

# Logging
LOG_LEVEL=INFO
```

### Generate Secure Secret Key

```bash
# Generate 32-byte hex string
openssl rand -hex 32
```

---

## Monitoring & Logging

### Backend Monitoring

```python
# Health check endpoint
GET /v1/health

# Metrics to monitor:
- Response time (should be < 500ms)
- Error rate (should be < 1%)
- Database connection pool
- Memory usage
- CPU usage
```

### Log Monitoring

```bash
# View real-time logs
docker-compose logs -f api

# View error logs
tail -f logs/errors.log

# Set up log rotation (in Docker)
# Already configured in logging.py
```

### Application Performance Monitoring

Recommended tools:
- **Sentry**: Error tracking and performance
- **Firebase Analytics**: User behavior and crashes
- **New Relic**: Full-stack monitoring

---

## Security Checklist

### Pre-Deployment Security

- [ ] Change `SECRET_KEY` to production value
- [ ] Use HTTPS for all endpoints
- [ ] Configure CORS to production domains only
- [ ] Enable rate limiting
- [ ] Set up database backups
- [ ] Configure firewall rules
- [ ] Enable SSL/TLS
- [ ] Remove debug endpoints
- [ ] Review API permissions
- [ ] Test authentication flow

### API Security

- [ ] JWT tokens expire appropriately
- [ ] Passwords hashed with bcrypt
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (input validation)
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] Request size limits enforced
- [ ] Sensitive data encrypted at rest

### Mobile App Security

- [ ] Code signing configured
- [ ] ProGuard/R8 obfuscation enabled (Android)
- [ ] App Transport Security (iOS)
- [ ] Certificate pinning (optional)
- [ ] Secure storage for sensitive data
- [ ] API keys not hardcoded
- [ ] Root/jailbreak detection (optional)

---

## Troubleshooting

### Common Issues

#### Database Connection Failed

```bash
# Check PostgreSQL status
docker-compose ps postgres

# View logs
docker-compose logs postgres

# Test connection
psql -U titan_user -h localhost -d titan_db
```

#### API Not Responding

```bash
# Check if service is running
curl -I https://your-api.com/v1/health

# Check logs
docker-compose logs api

# Restart service
docker-compose restart api
```

#### Build Failures

```bash
# Clean Flutter build cache
flutter clean

# Update dependencies
flutter pub get

# Check Flutter version
flutter --version

# Verify Android SDK
flutter doctor -v
```

#### Sync Conflicts

```bash
# Check sync status in app
# Review conflict resolution UI
# Force server sync if needed
# Contact support if persistent issues
```

---

## Rollback Procedures

### Backend Rollback

```bash
# Rollback database migration
alembic downgrade -1

# Or rollback to specific version
alembic downgrade <revision-id>

# Revert Docker image
docker-compose down
docker-compose up -d --build
```

### App Rollback

```bash
# Revert to previous version
# Use app store rollback feature
# Or release hotfix version
```

---

## Support & Maintenance

### Regular Maintenance Tasks

- **Weekly**: Review error logs
- **Monthly**: Update dependencies
- **Quarterly**: Security audit
- **As needed**: Database optimization

### Emergency Contacts

- Backend Support: support@titanapp.com
- App Store Support: Through respective store
- Documentation: [Project Wiki/Docs]

---

## Performance Optimization

### Backend Optimization

```python
# Database indexing (in migrations)
# Connection pooling (configured)
# Caching (implement Redis if needed)
# CDN for static files
# Load balancing (multiple instances)
```

### App Optimization

```dart
# Code splitting
# Lazy loading
- Image optimization
- Asset compression
- Minimize bundle size
```

---

## Cost Estimation

### Infrastructure Costs (Monthly)

- **VPS/Cloud Instance**: $20-100
- **Database (Managed)**: $15-50
- **Storage/CDN**: $10-30
- **Domain/SSL**: $10-20
- **Monitoring**: $0-20

**Total**: ~$55-220/month

### App Store Costs

- **Google Play**: $25 one-time fee
- **Apple App Store**: $99/year
- **Revenue share**: 15-30% of IAP revenue

---

## Next Steps After Deployment

1. **Monitor First 24 Hours**: Watch for errors and performance issues
2. **User Feedback Collection**: Set up feedback channels
3. **Analytics Review**: Check user behavior after 1 week
4. **Performance Tuning**: Optimize based on real usage
5. **Feature Planning**: Plan next updates based on feedback

---

## Appendix

### Useful Commands

```bash
# Docker
docker-compose up -d              # Start services
docker-compose down               # Stop services
docker-compose logs -f api         # Follow logs
docker-compose exec api bash      # Enter container

# Database
alembic current                 # Current migration
alembic history                # Migration history
alembic revision --autogenerate  # Create migration

# Flutter
flutter clean                   # Clean build
flutter pub get                 # Get dependencies
flutter build apk --release     # Build APK
flutter doctor                  # Diagnose issues
```

### Contact Information

- **Documentation**: See project README
- **Issues**: GitHub Issues / Project Tracker
- **Support**: support@titanapp.com

---

*Last Updated: 2024-01-01*
*Version: 1.0.0*
