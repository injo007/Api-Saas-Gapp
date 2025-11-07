#!/bin/bash

# Speed-Send Email Platform - Complete Fixed Deployment
# Ubuntu 22.04 - Fixes: Missing frontend, backend health, dependencies

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Clean up all old deployment files
cleanup_old_files() {
    log "Cleaning up old deployment files..."
    rm -f fix-installation.sh fix-deployment.sh nuclear-fix-deployment.sh
    rm -f quick-deploy.sh quick-deploy-ubuntu.sh setup-complete-project.sh  
    rm -f fix-poetry.sh fix-copy-command.sh force-rebuild.sh clear-cache-rebuild.sh
    rm -f verify-project-structure.sh frontend-fix.sh quick-fix.sh immediate-fix.sh
    rm -f complete-frontend-fix.sh deploy-final.sh check-status.sh status-check.md
    rm -f deploy.bat DEPLOYMENT.md nginx-frontend.conf
    rm -f backend/Dockerfile.old docker-compose-frontend-fix.yml docker-compose-backup.yml
    rm -f Dockerfile nginx-frontend.conf
    log "Old files cleaned up"
}

# Detect OS and install dependencies
install_dependencies() {
    log "Installing dependencies for Ubuntu 22.04..."
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl start docker
        systemctl enable docker
        usermod -aG docker $USER
    fi
    
    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..."
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Install Node.js
    if ! command -v node &> /dev/null; then
        log "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
}

# Fix all configuration issues
fix_all_configurations() {
    log "Fixing all configurations..."
    
    # Fix backend requirements
    log "Fixing backend requirements.txt..."
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

    # Fix backend health endpoint
    log "Fixing backend health endpoint..."
    cat > backend/api/v1/endpoints/health.py << 'EOF'
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "healthy", "message": "Speed-Send API is running"}

@router.get("/")
def root():
    return {"message": "Speed-Send API", "status": "healthy"}
EOF

    # Update main.py to include health route at root
    log "Updating main.py..."
    if ! grep -q "app.get.*health" backend/main.py; then
        cat >> backend/main.py << 'EOF'

# Add root health endpoint
@app.get("/health")
def health_check():
    return {"status": "healthy", "message": "Speed-Send API is running"}

@app.get("/")
def root():
    return {"message": "Speed-Send API", "status": "healthy"}
EOF
    fi

    # Create package.json for frontend
    log "Creating package.json..."
    cat > package.json << 'EOF'
{
  "name": "speed-send",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/uuid": "^9.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^4.4.0"
  }
}
EOF

    # Fix docker-compose.yml
    log "Creating fixed docker-compose.yml..."
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: speedsend_db
    volumes:
      - postgres_data:/var/lib/postgresql/data/
    environment:
      - POSTGRES_USER=speedsend
      - POSTGRES_PASSWORD=speedsend123
      - POSTGRES_DB=speedsend
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U speedsend -d speedsend"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: speedsend_redis
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  backend:
    build: ./backend
    container_name: speedsend_backend
    environment:
      - DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
      - ./uploads:/app/uploads
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    restart: unless-stopped

  celery_worker:
    build: ./backend
    container_name: speedsend_celery_worker
    environment:
      - DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    volumes:
      - ./backend:/app
      - ./uploads:/app/uploads
    depends_on:
      backend:
        condition: service_started
    command: celery -A tasks.celery_app worker -l info -c 4
    restart: unless-stopped

  celery_beat:
    build: ./backend
    container_name: speedsend_celery_beat
    environment:
      - DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    volumes:
      - ./backend:/app
    depends_on:
      backend:
        condition: service_started
    command: celery -A tasks.celery_app beat -l info --pidfile=/tmp/celerybeat.pid --scheduler=redbeat.RedBeatScheduler
    restart: unless-stopped
  
  frontend:
    image: node:18-alpine
    container_name: speedsend_frontend
    ports:
      - "3000:3000"
    volumes:
      - ./:/app
      - /app/node_modules
    working_dir: /app
    environment:
      - NODE_ENV=development
    depends_on:
      - backend
    command: sh -c "npm install && npm run dev -- --host 0.0.0.0"
    restart: unless-stopped

volumes:
  postgres_data:
EOF

    # Create .env file
    if [ ! -f .env ]; then
        log "Creating .env file..."
        cat > .env << 'EOF'
# Database
POSTGRES_USER=speedsend
POSTGRES_PASSWORD=speedsend123
POSTGRES_DB=speedsend
DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend

# Redis
REDIS_URL=redis://redis:6379/0

# Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
CELERY_WORKER_CONCURRENCY=4

# Gmail API (CONFIGURE THESE!)
GMAIL_CLIENT_ID=your-gmail-client-id-here
GMAIL_CLIENT_SECRET=your-gmail-client-secret-here

# Security
JWT_SECRET_KEY=your-super-secret-jwt-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
EOF
    fi
}

# Deploy application
deploy_application() {
    log "Deploying Speed-Send application..."
    
    # Stop and clean
    docker-compose down --remove-orphans || true
    docker system prune -f || true
    
    # Create directories
    mkdir -p logs uploads backend/uploads
    chmod 755 logs uploads backend/uploads
    
    # Build and start
    log "Building containers..."
    docker-compose build --no-cache
    
    log "Starting services..."
    docker-compose up -d
    
    # Wait and check
    log "Waiting for services to start..."
    sleep 60
    
    log "Checking service status..."
    docker-compose ps
    
    # Test endpoints
    log "Testing endpoints..."
    
    # Test backend
    if curl -s --connect-timeout 10 http://localhost:8000/health > /dev/null; then
        log "✅ Backend health check passed"
    else
        warn "❌ Backend health check failed"
        docker logs speedsend_backend | tail -10
    fi
    
    # Test frontend
    if curl -s --connect-timeout 10 http://localhost:3000 > /dev/null; then
        log "✅ Frontend is accessible"
    else
        warn "❌ Frontend not accessible"
        docker logs speedsend_frontend | tail -10
    fi
}

# Show final status
show_status() {
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
    docker-compose ps
    echo
    warn "⚠️  Configure Gmail API credentials in .env file!"
    echo
    log "Useful Commands:"
    log "View logs:   docker-compose logs -f"
    log "Restart:     docker-compose restart"
    log "Stop:        docker-compose down"
    echo
}

# Main execution
main() {
    log "Starting Speed-Send fixed deployment for Ubuntu 22.04..."
    
    cleanup_old_files
    install_dependencies
    fix_all_configurations
    deploy_application
    show_status
}

# Handle arguments
case "${1:-}" in
    "clean")
        cleanup_old_files
        docker-compose down --remove-orphans
        docker system prune -f
        ;;
    "config")
        fix_all_configurations
        ;;
    "deploy")
        deploy_application
        ;;
    *)
        main
        ;;
esac