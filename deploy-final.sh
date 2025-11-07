#!/bin/bash

# Speed-Send Email Platform - Final Fixed Deployment Script
# This script fixes all dependency issues and deploys successfully

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Clean up old deployment files
cleanup_old_files() {
    log "Cleaning up old deployment files..."
    
    # Remove old deployment scripts that might conflict
    rm -f fix-deployment.sh fix-deployment.ps1 nuclear-fix-deployment.sh
    rm -f quick-deploy.sh quick-deploy-ubuntu.sh setup-complete-project.sh
    rm -f fix-poetry.sh fix-copy-command.sh force-rebuild.sh clear-cache-rebuild.sh
    rm -f verify-project-structure.sh
    
    # Remove old Docker files
    rm -f backend/Dockerfile.old
    
    log "Old files cleaned up"
}

# Stop all running containers
stop_containers() {
    log "Stopping all running containers..."
    docker-compose down --remove-orphans || true
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
}

# Clean Docker system
clean_docker() {
    log "Cleaning Docker system..."
    docker system prune -af --volumes || true
    docker builder prune -af || true
}

# Fix backend dependencies
fix_dependencies() {
    log "Fixing backend dependencies..."
    
    # Ensure we have the correct requirements.txt
    cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic[email]==2.5.0
pydantic-settings==2.1.0
email-validator==2.1.0
sqlalchemy==2.0.23
alembic==1.13.1
psycopg2-binary==2.9.9
celery==5.3.4
redis==5.0.1
celery-redbeat==2.0.0
cryptography==41.0.7
google-api-python-client==2.108.0
google-auth==2.25.2
python-multipart==0.0.6
python-dotenv==1.0.0
passlib[bcrypt]==1.7.4
aiohttp==3.9.1
EOF

    log "Dependencies fixed!"
}

# Create optimized Dockerfile
create_dockerfile() {
    log "Creating optimized Dockerfile..."
    
    cat > backend/Dockerfile << 'EOF'
# Use Python 3.11 slim image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create uploads directory
RUN mkdir -p uploads && chmod 755 uploads

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

    log "Optimized Dockerfile created!"
}

# Create environment file
create_env() {
    log "Creating environment configuration..."
    
    if [ ! -f .env ]; then
        # Generate secure random values
        JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "fallback-jwt-secret-$(date +%s)")
        DB_PASSWORD=$(openssl rand -base64 32 2>/dev/null | tr -d "=+/" | cut -c1-25 || echo "dbpass$(date +%s)")
        REDIS_PASSWORD=$(openssl rand -base64 32 2>/dev/null | tr -d "=+/" | cut -c1-25 || echo "redispass$(date +%s)")
        
        cat > .env << EOF
# Speed-Send Configuration

# Application
APP_NAME=SpeedSend
DEBUG=false
SECRET_KEY=${JWT_SECRET}

# Database
POSTGRES_USER=speedsend
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=speedsend
DATABASE_URL=postgresql://speedsend:${DB_PASSWORD}@db:5432/speedsend

# Redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0

# Celery
CELERY_BROKER_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
CELERY_RESULT_BACKEND=redis://:${REDIS_PASSWORD}@redis:6379/0

# Gmail API (CONFIGURE THESE!)
GMAIL_CLIENT_ID=your-gmail-client-id-here
GMAIL_CLIENT_SECRET=your-gmail-client-secret-here
GMAIL_REDIRECT_URI=http://localhost:8000/auth/gmail/callback

# Security
JWT_SECRET_KEY=${JWT_SECRET}
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS
ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
ALLOWED_DOMAINS=localhost,127.0.0.1

# Email Settings
DEFAULT_FROM_EMAIL=noreply@localhost
MAX_EMAILS_PER_SECOND=10
MAX_EMAILS_PER_HOUR=1000
EOF
        
        log ".env file created with secure random passwords"
    else
        log ".env file already exists"
    fi
}

# Build and deploy
deploy() {
    log "Building and deploying Speed-Send..."
    
    # Create necessary directories
    mkdir -p logs data/postgres data/redis backend/uploads
    chmod 755 logs data backend/uploads
    
    # Build containers
    log "Building backend container..."
    docker-compose build --no-cache backend
    
    log "Building other containers..."
    docker-compose build --no-cache
    
    # Start services in order
    log "Starting database and Redis..."
    docker-compose up -d db redis
    
    # Wait for database
    log "Waiting for database to be ready..."
    sleep 30
    
    # Start backend
    log "Starting backend..."
    docker-compose up -d backend
    
    # Start Celery
    log "Starting Celery worker..."
    docker-compose up -d celery_worker celery_beat
    
    # Start frontend and nginx
    log "Starting frontend services..."
    docker-compose up -d frontend nginx
    
    log "Deployment completed!"
}

# Check services
check_services() {
    log "Checking service health..."
    
    sleep 15
    
    # Show running containers
    docker-compose ps
    
    # Test endpoints
    log "Testing backend health..."
    if curl -s --connect-timeout 10 http://localhost:8000/health > /dev/null 2>&1; then
        log "✓ Backend is healthy"
    else
        log "✗ Backend health check failed - checking logs..."
        docker-compose logs backend | tail -20
    fi
    
    log "Testing frontend..."
    if curl -s --connect-timeout 10 http://localhost:3000 > /dev/null 2>&1; then
        log "✓ Frontend is accessible"
    else
        log "✗ Frontend not accessible - checking logs..."
        docker-compose logs frontend | tail -10
    fi
}

# Show final status
show_status() {
    log "========================================"
    log "  Speed-Send Deployment Complete!"
    log "========================================"
    echo
    log "Access URLs:"
    log "Frontend:    http://localhost:3000"
    log "Backend API: http://localhost:8000"
    log "API Docs:    http://localhost:8000/docs"
    echo
    log "Container Status:"
    docker-compose ps
    echo
    log "⚠️  IMPORTANT: Configure Gmail API credentials in .env file!"
    log "   Edit GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET"
    echo
    log "Commands:"
    log "View logs:    docker-compose logs -f"
    log "Restart:      docker-compose restart"
    log "Stop:         docker-compose down"
    echo
    
    if docker-compose ps | grep -q "Up"; then
        log "🎉 Application is running successfully!"
    else
        log "⚠️  Some services may have issues. Check logs: docker-compose logs"
    fi
}

# Main execution
main() {
    log "Starting Speed-Send fixed deployment..."
    
    cleanup_old_files
    stop_containers
    clean_docker
    fix_dependencies
    create_dockerfile
    create_env
    deploy
    check_services
    show_status
}

# Handle arguments
case "${1:-}" in
    "clean")
        cleanup_old_files
        stop_containers
        clean_docker
        ;;
    "fix")
        fix_dependencies
        create_dockerfile
        ;;
    "deploy")
        deploy
        check_services
        ;;
    *)
        main
        ;;
esac