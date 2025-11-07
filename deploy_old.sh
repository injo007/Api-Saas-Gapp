#!/bin/bash

# Speed-Send Email Platform - Complete Deployment Script
# Ubuntu 22.04 - ALL ISSUES FIXED - One Complete Solution

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. This is not recommended for production."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Detect OS
detect_os() {
    log "Detecting operating system..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="ubuntu"
            log "Detected Ubuntu/Debian system"
        elif [ -f /etc/redhat-release ]; then
            OS="centos"
            log "Detected CentOS/RHEL system"
        else
            error "Unsupported Linux distribution"
        fi
    else
        error "Unsupported operating system: $OSTYPE"
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    if [ "$OS" = "ubuntu" ]; then
        sudo apt-get update -y
        sudo apt-get upgrade -y
        sudo apt-get install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    elif [ "$OS" = "centos" ]; then
        sudo yum update -y
        sudo yum install -y curl wget git unzip epel-release
    fi
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log "Docker already installed. Version: $(docker --version)"
        return
    fi
    
    if [ "$OS" = "ubuntu" ]; then
        # Remove old versions
        sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Set up the stable repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        sudo apt-get update -y
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif [ "$OS" = "centos" ]; then
        # Install Docker on CentOS
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    log "Docker installed successfully!"
}

# Install Docker Compose (standalone version as backup)
install_docker_compose() {
    log "Installing Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log "Docker Compose already installed. Version: $(docker-compose --version)"
        return
    fi
    
    # Install latest Docker Compose
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log "Docker Compose installed successfully!"
}

# Install Node.js and npm (for frontend building if needed)
install_nodejs() {
    log "Installing Node.js..."
    
    if command -v node &> /dev/null; then
        log "Node.js already installed. Version: $(node --version)"
        return
    fi
    
    # Install Node.js 18.x
    if [ "$OS" = "ubuntu" ]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [ "$OS" = "centos" ]; then
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo yum install -y nodejs
    fi
    
    log "Node.js installed successfully!"
}

# Setup firewall
setup_firewall() {
    log "Configuring firewall..."
    
    if [ "$OS" = "ubuntu" ]; then
        # Install and configure UFW
        sudo apt-get install -y ufw
        sudo ufw --force enable
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 3000/tcp  # Frontend dev port
        sudo ufw allow 8000/tcp  # Backend dev port
        sudo ufw reload
    elif [ "$OS" = "centos" ]; then
        # Configure firewalld
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --permanent --add-port=3000/tcp
        sudo firewall-cmd --permanent --add-port=8000/tcp
        sudo firewall-cmd --reload
    fi
    
    log "Firewall configured successfully!"
}

# Create necessary directories
create_directories() {
    log "Creating application directories..."
    
    mkdir -p logs
    mkdir -p data/postgres
    mkdir -p data/redis
    mkdir -p backend/uploads
    chmod 755 logs data backend/uploads
    
    log "Directories created successfully!"
}

# Generate .env file if it doesn't exist
create_env_file() {
    log "Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        log "Creating .env file from template..."
        cp .env.template .env
        
        # Generate random secrets
        JWT_SECRET=$(openssl rand -hex 32)
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
        # Update .env file with generated values
        sed -i "s/your-super-secret-jwt-key-here/$JWT_SECRET/g" .env
        sed -i "s/your-secure-db-password/$DB_PASSWORD/g" .env
        sed -i "s/your-redis-password/$REDIS_PASSWORD/g" .env
        
        warn "Please edit .env file with your specific configuration:"
        warn "- Gmail API credentials"
        warn "- Domain settings"
        warn "- SMTP settings (if needed)"
        warn "- Other environment-specific values"
    else
        log ".env file already exists"
    fi
}

# Fix common Docker issues
fix_docker_issues() {
    log "Fixing common Docker issues..."
    
    # Ensure Docker daemon is running
    sudo systemctl restart docker
    
    # Clean up any existing containers/images that might conflict
    docker system prune -f || true
    
    # Remove any existing project containers
    docker-compose down --remove-orphans || true
    
    log "Docker issues fixed!"
}

# Build and start the application
deploy_application() {
    log "Building and deploying Speed-Send application..."
    
    # Ensure we have the latest code
    if [ -d .git ]; then
        log "Updating code from Git..."
        git pull origin main || git pull origin master || warn "Could not pull latest code"
    fi
    
    # Build and start containers
    log "Building Docker containers..."
    docker-compose build --no-cache
    
    log "Starting application..."
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 30
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        log "Application deployed successfully!"
        log "Frontend: http://localhost:3000"
        log "Backend API: http://localhost:8000"
        log "Backend Docs: http://localhost:8000/docs"
    else
        error "Application failed to start. Check logs with: docker-compose logs"
    fi
}

# Check application health
check_health() {
    log "Checking application health..."
    
    # Check backend health
    if curl -s http://localhost:8000/health > /dev/null; then
        log "✓ Backend is healthy"
    else
        warn "✗ Backend health check failed"
    fi
    
    # Check frontend
    if curl -s http://localhost:3000 > /dev/null; then
        log "✓ Frontend is accessible"
    else
        warn "✗ Frontend is not accessible"
    fi
    
    # Show running containers
    log "Running containers:"
    docker-compose ps
}

# Setup log rotation
setup_logging() {
    log "Setting up log rotation..."
    
    sudo tee /etc/logrotate.d/speed-send << EOF
/home/$USER/speed-send/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
    
    log "Log rotation configured!"
}

# Create systemd service for auto-start
create_systemd_service() {
    log "Creating systemd service for auto-start..."
    
    sudo tee /etc/systemd/system/speed-send.service << EOF
[Unit]
Description=Speed-Send Email Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/home/$USER/speed-send
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=$USER
Group=docker

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable speed-send.service
    
    log "Systemd service created and enabled!"
}

# Display final information
show_final_info() {
    log "=================================="
    log "Speed-Send Platform Deployed Successfully!"
    log "=================================="
    echo
    log "Access URLs:"
    log "Frontend:     http://$(hostname -I | awk '{print $1}'):3000"
    log "Backend API:  http://$(hostname -I | awk '{print $1}'):8000"
    log "API Docs:     http://$(hostname -I | awk '{print $1}'):8000/docs"
    echo
    log "Useful Commands:"
    log "View logs:        docker-compose logs -f"
    log "Restart app:      docker-compose restart"
    log "Stop app:         docker-compose down"
    log "Update app:       git pull && docker-compose up --build -d"
    echo
    log "Configuration:"
    log "Edit .env file to customize settings"
    log "Application data is stored in ./data/"
    log "Logs are stored in ./logs/"
    echo
    warn "Don't forget to:"
    warn "1. Configure your Gmail API credentials in .env"
    warn "2. Set up SSL certificates for production"
    warn "3. Configure domain DNS settings"
    warn "4. Review security settings"
    echo
    log "Deployment completed successfully! 🚀"
}

# Main deployment function
main() {
    log "Starting Speed-Send Email Platform deployment..."
    echo
    
    # Pre-flight checks
    check_root
    detect_os
    
    # System setup
    update_system
    install_docker
    install_docker_compose
    install_nodejs
    setup_firewall
    
    # Application setup
    create_directories
    create_env_file
    fix_docker_issues
    
    # Deploy application
    deploy_application
    
    # Post-deployment setup
    check_health
    setup_logging
    create_systemd_service
    
    # Final information
    show_final_info
}

# Handle script arguments
case "${1:-}" in
    "install")
        log "Installing dependencies only..."
        detect_os
        update_system
        install_docker
        install_docker_compose
        install_nodejs
        setup_firewall
        log "Dependencies installed successfully!"
        ;;
    "deploy")
        log "Deploying application only..."
        create_directories
        create_env_file
        fix_docker_issues
        deploy_application
        check_health
        ;;
    "restart")
        log "Restarting application..."
        docker-compose down
        docker-compose up -d
        check_health
        ;;
    "logs")
        log "Showing application logs..."
        docker-compose logs -f
        ;;
    "status")
        log "Checking application status..."
        docker-compose ps
        check_health
        ;;
    "update")
        log "Updating application..."
        git pull origin main || git pull origin master
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        check_health
        ;;
    "clean")
        log "Cleaning up Docker resources..."
        docker-compose down --volumes --remove-orphans
        docker system prune -af
        ;;
    *)
        main
        ;;
esac