# Titan FastAPI Backend

Production-ready FastAPI backend for the Titan fitness tracking application.

## Features

- RESTful API with comprehensive endpoints
- JWT authentication with secure password hashing
- PostgreSQL database with Alembic migrations
- Offline-first sync support
- AI-powered workout insights
- Nutrition tracking
- Exercise and routine management
- Comprehensive error handling and logging
- Docker containerization
- CORS support for cross-origin requests

## Quick Start

### Using Docker (Recommended)

```bash
# Copy environment file
cp .env.example .env

# Edit .env with your configuration
nano .env

# Start services
docker-compose up -d

# Run database migrations
docker-compose exec api alembic upgrade head

# View logs
docker-compose logs -f api
```

### Manual Installation

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set up PostgreSQL database
createdb titan_db

# Configure environment
cp .env.example .env
# Edit .env with your database credentials

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API Documentation

Once the server is running, access the interactive API documentation:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Environment Variables

See `.env.example` for all available configuration options.

Key variables:
- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY`: JWT signing key (change in production!)
- `DEBUG`: Enable/disable debug mode
- `BACKEND_CORS_ORIGINS`: Allowed CORS origins

## Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "Description of changes"

# Apply migrations
alembic upgrade head

# Rollback one migration
alembic downgrade -1

# View migration history
alembic history
```

## Testing

```bash
# Run tests (when implemented)
pytest

# Run with coverage
pytest --cov=app --cov-report=html
```

## Production Deployment

### Docker Deployment

```bash
# Build production image
docker build -t titan-api:latest .

# Run with production environment
docker run -d \
  -p 8000:8000 \
  --env-file .env.production \
  titan-api:latest
```

### Manual Deployment

1. Set up PostgreSQL database
2. Configure environment variables for production
3. Run migrations: `alembic upgrade head`
4. Start with gunicorn:
```bash
gunicorn app.main:app \
  -w 4 \
  -k uvicorn.workers.UvicornWorker \
  -b 0.0.0.0:8000
```

## Monitoring

Logs are written to:
- Console output (Docker logs)
- `logs/titan.log` (general logs)
- `logs/errors.log` (error logs)

## Health Checks

- Root endpoint: `GET /`
- Health check: `GET /v1/health`

## Security Notes

- Always use strong `SECRET_KEY` in production
- Enable HTTPS in production
- Use environment-specific CORS origins
- Keep dependencies updated
- Regular database backups recommended

## Support

For issues or questions, please refer to the main project documentation.
