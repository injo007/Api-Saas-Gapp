#!/bin/bash

# Speed-Send Deployment Script for Ubuntu 22.04+
# Fixes frontend uuid dependency and ensures proper installation

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Fix package.json to include uuid dependency
fix_package_json() {
    log "Fixing package.json dependencies..."
    
    # Backup original package.json
    cp package.json package.json.backup
    
    # Update package.json with uuid dependency
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
    
    log "package.json updated with uuid dependency"
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

# Create optimized Dockerfile.frontend
create_frontend_dockerfile() {
    log "Creating optimized frontend Dockerfile..."
    
    cat > Dockerfile.frontend << 'EOF'
# Frontend Dockerfile - Optimized for uuid dependency
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git python3 make g++

# Copy package files first for better caching
COPY package.json ./

# Clear npm cache and install dependencies
RUN npm cache clean --force
RUN npm install --legacy-peer-deps --no-audit --no-fund

# Copy TypeScript configuration
COPY tsconfig.json ./
COPY vite.config.ts ./

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
    
    log "Frontend Dockerfile created"
}

# Create .dockerignore for optimized builds
create_dockerignore() {
    log "Creating .dockerignore..."
    
    cat > .dockerignore << 'EOF'
# Node modules
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

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

# Temporary files
tmp_*
EOF
    
    log ".dockerignore created"
}

# Build and start services
start_services() {
    log "Building and starting services..."
    
    # Start database and Redis first
    log "Starting database and Redis..."
    docker-compose up -d db redis
    
    # Wait for services to be ready
    log "Waiting for database to be ready..."
    sleep 15
    
    # Build and start backend
    log "Building and starting backend..."
    docker-compose up -d backend
    
    # Wait for backend
    sleep 20
    
    # Build and start workers
    log "Starting Celery workers..."
    docker-compose up -d celery_worker celery_beat
    
    # Build and start frontend
    log "Building and starting frontend..."
    docker-compose up -d frontend
    
    # Wait for all services
    log "Waiting for all services to stabilize..."
    sleep 30
}

# Show deployment status
show_deployment_status() {
    log "Checking deployment status..."
    
    echo "Container Status:"
    docker-compose ps
    
    echo -e "\nService Health Checks:"
    
    # Check database
    if docker-compose exec -T db pg_isready -U speedsend_user -d speedsend_db >/dev/null 2>&1; then
        log "✅ Database is ready"
    else
        warn "❌ Database is not ready"
    fi
    
    # Check Redis
    if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
        log "✅ Redis is ready"
    else
        warn "❌ Redis is not ready"
    fi
    
    # Check backend
    sleep 5
    if curl -f http://localhost:8000/health >/dev/null 2>&1; then
        log "✅ Backend API is ready"
    else
        warn "❌ Backend API is not ready"
    fi
    
    # Check frontend
    if curl -f http://localhost:3000 >/dev/null 2>&1; then
        log "✅ Frontend is ready"
    else
        warn "❌ Frontend is not ready"
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
    docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo
    warn "⚠️  Configure Gmail API credentials in .env file!"
    echo
    log "Useful Commands:"
    log "View logs:   docker-compose logs -f"
    log "Restart:     docker-compose restart"
    log "Stop:        docker-compose down"
    echo
    log "If you encounter issues, check logs:"
    log "Frontend logs: docker-compose logs frontend"
    log "Backend logs:  docker-compose logs backend"
}

# Main deployment function
main() {
    log "Starting Speed-Send deployment..."
    
    check_root
    check_ubuntu_version
    install_system_dependencies
    install_docker
    install_docker_compose
    install_nodejs
    
    # Fix frontend dependencies
    fix_package_json
    create_frontend_dockerfile
    create_dockerignore
    
    setup_environment
    cleanup_old_deployment
    start_services
    show_deployment_status
    show_final_summary
}

# Handle command line arguments
case "${1:-install}" in
    "install"|"")
        main
        ;;
    "fix-frontend")
        log "Fixing frontend build and API routing issues..."
        fix_package_json
        create_frontend_dockerfile
        create_dockerignore
        
        # Stop and remove frontend container
        docker compose stop frontend || docker-compose stop frontend || true
        docker compose rm -f frontend || docker-compose rm -f frontend || true
        
        # Remove old frontend images
        docker rmi $(docker images -q "*frontend*" 2>/dev/null) || true
        docker rmi $(docker images -q speedsend_frontend 2>/dev/null) || true
        
        # Rebuild and start frontend with proper API routing
        docker compose build --no-cache frontend || docker-compose build --no-cache frontend
        docker compose up -d frontend || docker-compose up -d frontend
        
        log "Frontend fix completed! API routing should now work."
        ;;
    "reinstall")
        log "Reinstalling Speed-Send..."
        cleanup_old_deployment
        main
        ;;
    "clean")
        log "Clean installation..."
        docker-compose down --volumes --remove-orphans || true
        docker system prune -af || true
        main
        ;;
    "help"|"--help"|"-h")
        echo "Speed-Send Deployment Script"
        echo "Usage: ./deploy.sh [command]"
        echo ""
        echo "Commands:"
        echo "  install       - Fresh installation (default)"
        echo "  fix-frontend  - Fix frontend uuid dependency issue"
        echo "  reinstall     - Reinstall application"
        echo "  clean         - Clean installation (removes all data)"
        echo "  help          - Show this help"
        ;;
    *)
        error "Unknown command: $1"
        echo "Use './deploy.sh help' for available commands"
        exit 1
        ;;
esac