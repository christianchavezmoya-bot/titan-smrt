import time
import uuid
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
from .logging import app_logger
from .config import settings


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Log all incoming requests with timing and correlation IDs."""
    
    async def dispatch(self, request: Request, call_next):
        # Generate correlation ID
        correlation_id = str(uuid.uuid4())
        request.state.correlation_id = correlation_id
        
        # Log request
        start_time = time.time()
        method = request.method
        path = request.url.path
        client_ip = request.client.host if request.client else "unknown"
        
        app_logger.info(
            f"Request started - {method} {path} - IP: {client_ip} - Correlation ID: {correlation_id}"
        )
        
        # Process request
        try:
            response = await call_next(request)
            
            # Calculate duration
            process_time = time.time() - start_time
            
            # Add custom headers
            response.headers["X-Correlation-ID"] = correlation_id
            response.headers["X-Process-Time"] = str(process_time)
            
            # Log response
            app_logger.info(
                f"Request completed - {method} {path} - Status: {response.status_code} - "
                f"Duration: {process_time:.3f}s - Correlation ID: {correlation_id}"
            )
            
            return response
            
        except Exception as e:
            # Log error
            process_time = time.time() - start_time
            app_logger.error(
                f"Request failed - {method} {path} - Error: {str(e)} - "
                f"Duration: {process_time:.3f}s - Correlation ID: {correlation_id}"
            )
            raise


class ErrorHandlingMiddleware(BaseHTTPMiddleware):
    """Centralized error handling for the application."""
    
    async def dispatch(self, request: Request, call_next):
        try:
            return await call_next(request)
            
        except HTTPException as http_exc:
            correlation_id = getattr(request.state, 'correlation_id', 'unknown')
            app_logger.warning(
                f"HTTP Exception - {http_exc.status_code} - {http_exc.detail} - "
                f"Correlation ID: {correlation_id}"
            )
            return JSONResponse(
                status_code=http_exc.status_code,
                content={
                    "error": http_exc.detail,
                    "correlation_id": correlation_id,
                    "status": http_exc.status_code,
                }
            )
            
        except ValueError as val_exc:
            correlation_id = getattr(request.state, 'correlation_id', 'unknown')
            app_logger.warning(
                f"Validation Error - {str(val_exc)} - Correlation ID: {correlation_id}"
            )
            return JSONResponse(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                content={
                    "error": "Validation failed",
                    "detail": str(val_exc),
                    "correlation_id": correlation_id,
                }
            )
            
        except Exception as exc:
            correlation_id = getattr(request.state, 'correlation_id', 'unknown')
            app_logger.error(
                f"Unhandled Exception - {str(exc)} - Correlation ID: {correlation_id}",
                exc_info=True
            )
            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "error": "Internal server error",
                    "correlation_id": correlation_id,
                }
            )


class CORSMiddleware(BaseHTTPMiddleware):
    """Custom CORS middleware with configurable origins."""
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.allowed_origins = settings.BACKEND_CORS_ORIGINS
    
    async def dispatch(self, request: Request, call_next):
        origin = request.headers.get("origin")
        
        if origin in self.allowed_origins:
            # This will be handled by the response
            pass
        
        response = await call_next(request)
        
        if origin in self.allowed_origins:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        
        return response
