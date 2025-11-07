#!/bin/bash

# Recovery script for failed Speed-Send installation
# This script handles installation issues and completes the setup

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check system resources
check_system() {
    log "Checking system resources..."
    
    # Check memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$MEMORY_GB" -lt 2 ]; then
        warn "Low memory detected: ${MEMORY_GB}GB. Recommended: 2GB+"
        warn "This may cause installation failures."
    fi
    
    # Check disk space
    DISK_SPACE=$(df -h . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "${DISK_SPACE%.*}" -lt 5 ]; then
        warn "Low disk space: ${DISK_SPACE}GB available. Recommended: 5GB+"
    fi
    
    log "Memory: ${MEMORY_GB}GB, Disk: ${DISK_SPACE}GB"
}

# Install Docker on CentOS/RHEL with memory optimization
install_docker_centos() {
    log "Installing Docker on CentOS/RHEL (optimized)..."
    
    # Clean up any failed installations
    sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc || true
    
    # Install required packages one by one to avoid memory issues
    log "Installing yum-utils..."
    sudo yum install -y yum-utils
    
    log "Adding Docker repository..."
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    log "Installing Docker CE (this may take a few minutes)..."
    # Install with reduced parallelism to avoid memory issues
    sudo yum install -y docker-ce docker-ce-cli containerd.io --nobest --skip-broken
    
    # Start Docker
    log "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    log "Docker installation completed!"
}

# Install Docker Compose manually
install_docker_compose_manual() {
    log "Installing Docker Compose manually..."
    
    # Get latest version
    COMPOSE_VERSION="v2.23.0"  # Fixed version to avoid API issues
    
    # Download and install
    sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for docker-compose command
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log "Docker Compose installed successfully!"
}

# Lightweight setup without heavy dependencies
minimal_setup() {
    log "Setting up minimal environment..."
    
    # Create necessary directories
    mkdir -p logs data/postgres data/redis backend/uploads
    chmod 755 logs data backend/uploads
    
    # Create .env if missing
    if [ ! -f .env ]; then
        cp .env.template .env
        
        # Generate secrets
        JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "fallback-jwt-secret-$(date +%s)")
        DB_PASSWORD=$(openssl rand -base64 32 2>/dev/null | tr -d "=+/" | cut -c1-25 || echo "dbpass$(date +%s)")
        REDIS_PASSWORD=$(openssl rand -base64 32 2>/dev/null | tr -d "=+/" | cut -c1-25 || echo "redispass$(date +%s)")
        
        sed -i "s/your-super-secret-jwt-key-here/$JWT_SECRET/g" .env
        sed -i "s/your-secure-db-password/$DB_PASSWORD/g" .env
        sed -i "s/your-redis-password/$REDIS_PASSWORD/g" .env
        
        log ".env file created with generated secrets"
    fi
}

# Test Docker installation
test_docker() {
    log "Testing Docker installation..."
    
    if command -v docker &> /dev/null; then
        log "Docker version: $(docker --version)"
        
        # Test Docker daemon
        if sudo docker run --rm hello-world &> /dev/null; then
            log "✓ Docker is working correctly"
        else
            warn "✗ Docker daemon may not be running properly"
            sudo systemctl restart docker
            sleep 5
        fi
    else
        error "Docker installation failed"
        return 1
    fi
    
    if command -v docker-compose &> /dev/null; then
        log "Docker Compose version: $(docker-compose --version)"
    else
        error "Docker Compose installation failed"
        return 1
    fi
}

# Deploy with memory optimization
deploy_optimized() {
    log "Deploying Speed-Send with optimizations..."
    
    # Clean up first
    sudo docker system prune -f || true
    
    # Build with reduced memory usage
    log "Building containers (optimized for low memory)..."
    
    # Build backend first
    log "Building backend container..."
    sudo docker-compose build --no-cache backend
    
    # Build frontend
    log "Building frontend container..."
    sudo docker-compose build --no-cache frontend
    
    # Start database and Redis first
    log "Starting database services..."
    sudo docker-compose up -d db redis
    
    # Wait for database
    sleep 30
    
    # Start backend
    log "Starting backend service..."
    sudo docker-compose up -d backend
    
    # Start Celery worker
    log "Starting Celery worker..."
    sudo docker-compose up -d celery_worker
    
    # Start frontend and nginx
    log "Starting frontend services..."
    sudo docker-compose up -d frontend nginx
    
    log "Deployment completed!"
}

# Check if services are running
check_services() {
    log "Checking service status..."
    
    sleep 10  # Wait for services to start
    
    # Check if containers are running
    if sudo docker-compose ps | grep -q "Up"; then
        log "✓ Some services are running"
        sudo docker-compose ps
    else
        warn "✗ No services appear to be running"
        log "Checking logs..."
        sudo docker-compose logs --tail=20
    fi
    
    # Check specific endpoints
    log "Testing endpoints..."
    
    # Backend health check
    if curl -s --connect-timeout 5 http://localhost:8000/health > /dev/null 2>&1; then
        log "✓ Backend is responding"
    else
        warn "✗ Backend not responding on port 8000"
    fi
    
    # Frontend check
    if curl -s --connect-timeout 5 http://localhost:3000 > /dev/null 2>&1; then
        log "✓ Frontend is responding"
    else
        warn "✗ Frontend not responding on port 3000"
    fi
}

# Main recovery process
main() {
    log "Starting Speed-Send installation recovery..."
    
    check_system
    
    # Install Docker if missing
    if ! command -v docker &> /dev/null; then
        install_docker_centos
    else
        log "Docker already installed"
    fi
    
    # Install Docker Compose if missing
    if ! command -v docker-compose &> /dev/null; then
        install_docker_compose_manual
    else
        log "Docker Compose already installed"
    fi
    
    test_docker
    minimal_setup
    deploy_optimized
    check_services
    
    log "=================================="
    log "Recovery completed!"
    log "=================================="
    log "Frontend: http://$(hostname -I | awk '{print $1}'):3000"
    log "Backend:  http://$(hostname -I | awk '{print $1}'):8000"
    log "API Docs: http://$(hostname -I | awk '{print $1}'):8000/docs"
    log "=================================="
    
    if sudo docker-compose ps | grep -q "Up"; then
        log "✓ Application is running successfully!"
    else
        warn "Some services may not be running. Check logs:"
        warn "sudo docker-compose logs -f"
    fi
}

# Handle arguments
case "${1:-}" in
    "docker")
        install_docker_centos
        install_docker_compose_manual
        test_docker
        ;;
    "deploy")
        deploy_optimized
        check_services
        ;;
    "check")
        check_services
        ;;
    *)
        main
        ;;
esac