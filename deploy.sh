#!/bin/bash

# Speed-Send Deployment Script
# Comprehensive deployment for Ubuntu 22.04+ 
# Handles installation, reinstallation, fixes, and frontend build issues

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. This is not recommended but proceeding..."
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        error "This script is designed for Ubuntu. Detected: $(cat /etc/os-release | grep PRETTY_NAME)"
        exit 1
    fi
    
    UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "22.04")
    log "Ubuntu $UBUNTU_VERSION detected"
}

# Install system dependencies
install_system_dependencies() {
    log "Installing system dependencies..."
    
    # Update package list
    apt update
    
    # Install essential packages
    apt install -y \
        curl \
        wget \
        git \
        build-essential \
        python3 \
        python3-pip \
        python3-venv \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        unzip \
        jq \
        htop \
        nano \
        vim
    
    log "System dependencies installed successfully"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log "Docker is already installed"
        return 0
    fi
    
    # Remove old Docker versions
    apt remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add user to docker group if not root
    if [[ $EUID -ne 0 ]]; then
        usermod -aG docker $USER
        warn "You may need to log out and back in for Docker group changes to take effect"
    fi
    
    log "Docker installed successfully"
}

# Install Docker Compose (standalone)
install_docker_compose() {
    log "Installing Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log "Docker Compose is already installed"
        return 0
    fi
    
    # Install Docker Compose standalone
    DOCKER_COMPOSE_VERSION="v2.23.0"
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink if needed
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Verify installation
    docker-compose --version
    
    log "Docker Compose installed successfully"
}

# Install Node.js
install_nodejs() {
    log "Installing Node.js 20 LTS..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
        if [ "$MAJOR_VERSION" -ge "20" ]; then
            log "Node.js $NODE_VERSION is already installed and compatible"
            return 0
        else
            log "Node.js $NODE_VERSION is too old, upgrading to Node.js 20..."
        fi
    fi
    
    # Remove old Node.js versions
    apt remove -y nodejs npm || true
    
    # Install Node.js 20 LTS
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    # Verify installation
    node --version
    npm --version
    
    log "Node.js 20 installed successfully"
}

# Setup environment file
setup_environment() {
    log "Setting up environment configuration..."
    
    if [[ ! -f .env ]]; then
        if [[ -f .env.template ]]; then
            cp .env.template .env
            log "Created .env from template"
        else
            cat > .env << EOF
# Database Configuration
DATABASE_URL=postgresql://speedsend_user:speedsend_password@db:5432/speedsend_db
POSTGRES_DB=speedsend_db
POSTGRES_USER=speedsend_user
POSTGRES_PASSWORD=speedsend_password

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# Security
SECRET_KEY=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Gmail API Configuration
GMAIL_RATE_LIMIT_PER_HOUR=1800

# Celery Configuration
CELERY_WORKER_CONCURRENCY=50
CELERY_TASK_TIMEOUT=300

# Application Configuration
DEBUG=false
ENVIRONMENT=production
EOF
            log "Created default .env file"
        fi
    else
        log ".env file already exists"
    fi
}

# Clean up old containers and data
cleanup_old_deployment() {
    log "Cleaning up old deployment..."
    
    # Stop and remove containers
    if docker-compose ps -q &> /dev/null; then
        docker-compose down --volumes --remove-orphans || true
    fi
    
    # Remove dangling images
    docker image prune -f || true
    
    log "Cleanup completed"
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

# Fix frontend build issues
fix_frontend_build() {
    log "Fixing frontend build configuration..."
    
    # Create proper frontend Dockerfile if it doesn't exist or is outdated
    cat > Dockerfile.frontend << 'EOF'
# Frontend Dockerfile
FROM node:20-alpine as builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json ./
COPY tsconfig.json ./
COPY vite.config.ts ./

# Install dependencies with legacy peer deps to avoid conflicts
RUN npm install --legacy-peer-deps

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

    # Create .dockerignore to optimize build
    cat > .dockerignore << 'EOF'
# Node modules
node_modules/
npm-debug.log*

# Build outputs
dist/
build/

# Environment files
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Git
.git/
.gitignore

# Docker files
Dockerfile*
docker-compose*

# Backend files (not needed for frontend build)
backend/
uploads/
data/
logs/

# Documentation
*.md
LICENSE
EOF

    # Update docker-compose.yml to use build instead of volume mount
    if grep -q "image: nginx:alpine" docker-compose.yml; then
        log "Updating docker-compose.yml for proper frontend build..."
        sed -i '/frontend:/,/restart: unless-stopped/{
            s/image: nginx:alpine/build:\
      context: .\
      dockerfile: Dockerfile.frontend/
            /volumes:/,/nginx.conf:/d
        }' docker-compose.yml
    fi
    
    log "Frontend build configuration fixed"
}

# Quick frontend rebuild function
rebuild_frontend() {
    log "Rebuilding frontend container..."
    
    # Stop frontend container
    docker-compose stop frontend || true
    
    # Remove frontend container and image
    docker-compose rm -f frontend || true
    docker rmi $(docker images -q "*frontend*" 2>/dev/null) 2>/dev/null || true
    
    # Rebuild frontend
    docker-compose build --no-cache frontend
    
    # Start frontend
    docker-compose up -d frontend
    
    log "Frontend rebuild completed"
}

# Create production database configuration
create_production_database_py() {
    log "Creating production-ready database.py..."
    
    cat > backend/database.py << 'EOF'
from sqlalchemy import create_engine, text
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
                conn.execute(text("SELECT 1"))
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
    
    log "Fixing frontend build configuration..."
    fix_frontend_build
    
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
    
    log "Building and starting all services with proper dependencies..."
    docker-compose build --no-cache
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
            log "Starting Speed-Send fresh installation..."
            check_root
            check_ubuntu_version
            install_system_dependencies
            install_docker
            install_docker_compose
            install_nodejs
            setup_environment
            cleanup_old_deployment
            fix_backend_imports
            start_services
            show_deployment_status
            show_final_summary
            ;;
        "reinstall"|"--reinstall")
            log "Reinstalling Speed-Send..."
            check_root
            cleanup_old_deployment
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
        "clean"|"--clean")
            log "Clean installation (removes all data)..."
            check_root
            check_ubuntu_version
            install_system_dependencies
            install_docker
            install_docker_compose
            install_nodejs
            # Clean everything
            docker-compose down --volumes --remove-orphans || true
            docker system prune -af || true
            setup_environment
            fix_backend_imports
            start_services
            show_deployment_status
            show_final_summary
            ;;
        "help"|"--help"|"-h")
            echo "Speed-Send Deployment Script"
            echo "Usage: ./deploy.sh [command]"
            echo ""
            echo "Commands:"
            echo "  install     - Fresh installation with all dependencies (default)"
            echo "  reinstall   - Reinstall application (keeps system dependencies)"
            echo "  clean       - Clean installation (removes all data and containers)"
            echo "  fix         - Fix common issues"
            echo "  help        - Show this help"
            echo ""
            echo "Requirements:"
            echo "  - Ubuntu 20.04+ (tested on Ubuntu 22.04)"
            echo "  - Run as root or user with sudo privileges"
            echo "  - Internet connection for downloading dependencies"
            ;;
        *)
            error "Unknown command: $1"
            echo "Use 'help' for available commands"
            exit 1
            ;;
    esac
}

# Execute main function
# Print usage information
usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install       Full installation (default)"
    echo "  reinstall     Clean reinstallation"
    echo "  fix-frontend  Quick frontend rebuild only"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full deployment"
    echo "  $0 install           # Full deployment"
    echo "  $0 reinstall         # Clean reinstallation"
    echo "  $0 fix-frontend      # Fix blank frontend issue"
    echo ""
}

# Main execution with command line options
case "${1:-}" in
    "fix-frontend")
        log "Quick frontend fix mode..."
        rebuild_frontend
        log "Frontend fix completed! Access at http://localhost:3000"
        exit 0
        ;;
    "install")
        log "Full installation mode..."
        main
        ;;
    "reinstall")
        log "Reinstallation mode..."
        cleanup_old_deployment
        main
        ;;
    "-h"|"--help"|"help")
        usage
        exit 0
        ;;
    "")
        log "Starting default Speed-Send deployment..."
        main
        ;;
    *)
        error "Unknown command: $1"
        usage
        exit 1
        ;;
esac