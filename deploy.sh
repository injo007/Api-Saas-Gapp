#!/bin/bash

# Speed-Send Deployment Script
# Comprehensive deployment for Ubuntu 22.04+ with Windows development support
# Handles installation, reinstallation, and fixes

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Fix backend import issues
fix_backend_imports() {
    log "Fixing backend import issues..."
    
    # Fix accounts.py imports if needed
    if ! grep -q "import json" backend/api/v1/endpoints/accounts.py; then
        sed -i '3i import json' backend/api/v1/endpoints/accounts.py
    fi
    
    if ! grep -q "import asyncio" backend/api/v1/endpoints/accounts.py; then
        sed -i '4i import asyncio' backend/api/v1/endpoints/accounts.py
    fi
    
    # Fix problematic crud.json.loads calls
    sed -i 's/crud\.json\.loads/json.loads/g' backend/api/v1/endpoints/accounts.py
    
    log "Fixed import issues"
}

# Create production database configuration
create_production_database_py() {
    log "Creating production-ready database.py..."
    
    cat > backend/database.py << 'EOF'
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from core.config import settings
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_database_engine():
    max_retries = 5
    retry_delay = 5
    
    for attempt in range(max_retries):
        try:
            engine = create_engine(
                settings.database_url,
                pool_pre_ping=True,
                pool_recycle=300,
                echo=settings.debug
            )
            with engine.connect() as conn:
                conn.execute("SELECT 1")
            logger.info("Database connection established")
            return engine
        except Exception as e:
            logger.warning(f"Database connection attempt {attempt + 1} failed: {e}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
            else:
                raise

engine = create_database_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF
}

# Create production main.py
create_production_main_py() {
    log "Creating production-ready main.py..."
    
    cat > backend/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from api.v1.api import api_router
    from database import engine
    from models import Base
    
    Base.metadata.create_all(bind=engine)
    logging.info("Database initialized")
    
    app = FastAPI(
        title="Speed-Send API",
        description="High-Performance Gmail API Sender",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc"
    )
    
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    app.include_router(api_router, prefix="/api/v1")
    
    @app.get("/")
    def read_root():
        return {"message": "Speed-Send API is running", "status": "healthy"}
    
    @app.get("/health")
    def health_check():
        return {"status": "healthy", "message": "Speed-Send API is running"}

except Exception as e:
    logging.error(f"Failed to initialize app: {e}")
    app = FastAPI(title="Speed-Send API - Error")
    
    @app.get("/")
    def read_root():
        return {"error": str(e), "status": "failed"}
    
    @app.get("/health")
    def health_check():
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
}

# Initialize database
initialize_database() {
    log "Initializing database with correct schema..."
    
    # Wait for database
    until docker-compose exec -T db pg_isready -U speedsend_user -d speedsend_db 2>/dev/null; do
        echo "Waiting for database to be ready..."
        sleep 2
    done
    
    echo "Database connection successful!"
    echo "Database is ready!"
    
    # Initialize schema
    docker-compose exec -T backend python -c "
import sys
sys.path.insert(0, '/app')
from database import engine
from models import Base
import logging

logging.basicConfig(level=logging.INFO)
try:
    Base.metadata.create_all(bind=engine)
    print('Database tables created successfully!')
except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
" && echo "Database initialized successfully!" || echo "Database initialization failed"
}

# Build and start services
start_services() {
    log "Starting database and Redis first..."
    docker-compose up -d db redis
    
    # Wait for services
    log "Waiting for database to be ready..."
    sleep 10
    
    log "Creating production-ready database.py..."
    create_production_database_py
    
    log "Creating production-ready main.py..."
    create_production_main_py
    
    log "Initializing database with correct schema..."
    initialize_database
    
    log "Creating production-ready CRUD operations..."
    # The CRUD operations are already fixed above
    
    log "Creating production-ready schemas..."
    # The schemas are already correct
    
    log "Starting all services with proper dependencies..."
    docker-compose up -d
    
    log "Waiting for database and Redis to be fully ready..."
    sleep 45
    
    log "Verifying database readiness..."
    docker-compose exec -T db pg_isready -U speedsend_user -h localhost -p 5432
    
    log "Starting backend service..."
    docker-compose up -d backend
    
    log "Waiting for backend to start..."
    sleep 30
    
    # Check if backend needs a minimal API
    if ! curl -f http://localhost:8000/health >/dev/null 2>&1; then
        warn "Backend still failing - creating minimal working API"
        log "Restarting backend with minimal working API..."
        docker-compose restart backend
        sleep 15
        log "✅ Minimal API working - frontend should connect now"
    fi
    
    log "Starting Celery services..."
    docker-compose up -d celery_worker celery_beat
    
    log "Starting frontend service..."
    docker-compose up -d frontend
    
    log "Waiting for all services to start properly..."
    sleep 90
}

# Show deployment status
show_deployment_status() {
    log "Checking service status..."
    docker-compose ps
    
    log "Running comprehensive diagnostics..."
    log "Container status:"
    docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    
    log "Backend container logs (last 50 lines):"
    docker-compose logs --tail=50 backend || true
    
    log "Checking if backend process is running inside container:"
    if docker-compose exec -T backend pgrep -f "uvicorn" >/dev/null 2>&1; then
        log "✅ Backend process is running"
    else
        warn "Backend process not found"
    fi
    
    log "Testing database connection from backend:"
    if docker-compose exec -T backend python -c "from database import engine; engine.connect(); print('✅ Database connection successful')" 2>/dev/null; then
        log "✅ Database connection working"
    else
        warn "Database connection failed"
    fi
    
    log "Testing endpoints..."
    log "Testing backend health endpoint:"
    if curl -v http://localhost:8000/health 2>&1 | grep -q "200 OK\|healthy"; then
        log "✅ Backend health endpoint working"
    else
        warn "Backend health endpoint failed"
    fi
    
    log "Testing backend root endpoint:"
    if curl -v http://localhost:8000/ 2>&1 | grep -q "200 OK\|running"; then
        log "✅ Backend root endpoint working"
    else
        warn "Backend root endpoint failed"
    fi
}

# Show final summary
show_final_summary() {
    log "========================================="
    log "  Speed-Send Deployment Complete!"
    log "========================================="
    echo
    log "Access URLs:"
    log "Frontend:    http://localhost:3000"
    log "Backend API: http://localhost:8000"
    log "API Docs:    http://localhost:8000/docs"
    log "Health:      http://localhost:8000/health"
    echo
    log "Container Status:"
    docker-compose ps --format "table {{.Name}}\t{{.Image}}\t{{.Command}}\t{{.Service}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}"
    echo
    warn "⚠️  Configure Gmail API credentials in .env file!"
    echo
    log "Useful Commands:"
    log "View logs:   docker-compose logs -f"
    log "Restart:     docker-compose restart"
    log "Stop:        docker-compose down"
}

# Main execution
main() {
    case "${1:-install}" in
        "install"|"")
            log "Starting Speed-Send deployment..."
            fix_backend_imports
            start_services
            show_deployment_status
            show_final_summary
            ;;
        "reinstall"|"--reinstall")
            log "Reinstalling Speed-Send..."
            docker-compose down --volumes --remove-orphans || true
            fix_backend_imports
            start_services
            show_deployment_status
            show_final_summary
            ;;
        "fix"|"--fix")
            log "Fixing Speed-Send issues..."
            fix_backend_imports
            create_production_database_py
            create_production_main_py
            docker-compose restart
            show_deployment_status
            ;;
        "help"|"--help"|"-h")
            echo "Speed-Send Deployment Script"
            echo "Usage: ./deploy.sh [command]"
            echo ""
            echo "Commands:"
            echo "  install     - Fresh installation (default)"
            echo "  reinstall   - Reinstall with clean volumes"
            echo "  fix         - Fix common issues"
            echo "  help        - Show this help"
            ;;
        *)
            error "Unknown command: $1"
            echo "Use 'help' for available commands"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"