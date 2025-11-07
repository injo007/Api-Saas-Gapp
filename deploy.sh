#!/bin/bash

# Speed-Send Automated Deployment Script
# One script for: Install, Reinstall, Fix, and Manage
# Works on Ubuntu 22.04+ with zero manual intervention

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emoji for better UX
ROCKET="🚀"
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
GEAR="⚙️"
FIRE="🔥"

# Print functions
print_header() {
    echo ""
    echo -e "${PURPLE}===============================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}===============================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}${GEAR} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

# Global variables
DOCKER_COMPOSE_CMD=""
RETRY_COUNT=3
DEPLOYMENT_MODE="install"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --reinstall)
                DEPLOYMENT_MODE="reinstall"
                shift
                ;;
            --fix)
                DEPLOYMENT_MODE="fix"
                shift
                ;;
            --reset)
                DEPLOYMENT_MODE="reset"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    echo "Speed-Send Deployment Script"
    echo ""
    echo "Usage: ./deploy.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (no options)    Fresh installation"
    echo "  --reinstall     Complete reinstallation (keeps data)"
    echo "  --fix           Fix broken deployment"
    echo "  --reset         Complete reset (destroys all data)"
    echo "  --help          Show this help message"
}

# Detect system
detect_system() {
    print_step "Detecting system..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [[ "$ID" == "ubuntu" ]]; then
                print_success "Ubuntu $VERSION_ID detected"
                if [[ "$VERSION_ID" < "20.04" ]]; then
                    print_warning "Ubuntu 20.04+ recommended. Current: $VERSION_ID"
                fi
            else
                print_warning "Non-Ubuntu Linux detected: $PRETTY_NAME"
            fi
        fi
    else
        print_error "This script is designed for Ubuntu/Linux systems"
        exit 1
    fi
}

# Install Docker automatically
install_docker() {
    print_step "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        print_success "Docker already installed: $(docker --version)"
        return 0
    fi
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update package index
    sudo apt-get update -y
    
    # Install dependencies
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    # Add Docker's GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    print_success "Docker installed successfully"
}

# Install Docker Compose
install_docker_compose() {
    print_step "Setting up Docker Compose..."
    
    # Check if docker compose plugin is available
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        print_success "Docker Compose plugin available"
        return 0
    fi
    
    # Check if docker-compose is available
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        print_success "Docker Compose standalone available"
        return 0
    fi
    
    # Install docker-compose standalone
    print_step "Installing Docker Compose standalone..."
    DOCKER_COMPOSE_VERSION="2.20.0"
    sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    DOCKER_COMPOSE_CMD="docker-compose"
    print_success "Docker Compose installed"
}

# Install system dependencies
install_dependencies() {
    print_step "Installing system dependencies..."
    
    sudo apt-get update -y
    sudo apt-get install -y \
        curl \
        wget \
        openssl \
        net-tools \
        postgresql-client \
        redis-tools \
        jq
    
    print_success "System dependencies installed"
}

# Kill processes using required ports
free_ports() {
    print_step "Freeing required ports..."
    
    local ports=(3000 8000 5432 6379)
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port is in use, attempting to free it..."
            sudo fuser -k $port/tcp 2>/dev/null || true
            sleep 2
        fi
    done
    
    print_success "Ports freed"
}

# Generate secure random strings
generate_secret() {
    openssl rand -hex 32
}

generate_encryption_key() {
    openssl rand -base64 32
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Setup environment configuration
setup_environment() {
    print_step "Setting up environment configuration..."
    
    if [ ! -f .env.template ]; then
        print_error ".env.template not found!"
        exit 1
    fi
    
    # Always regenerate .env for fresh config
    cp .env.template .env
    
    # Generate secure values
    SECRET_KEY=$(generate_secret)
    ENCRYPTION_KEY=$(generate_encryption_key)
    DB_PASSWORD=$(generate_password)
    
    # Update .env file
    sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" .env
    sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASSWORD/" .env
    sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://speedsend_user:$DB_PASSWORD@db:5432/speedsend_db|" .env
    sed -i "s/DEBUG=.*/DEBUG=false/" .env
    sed -i "s/ENVIRONMENT=.*/ENVIRONMENT=production/" .env
    
    print_success "Environment configured with secure keys"
}

# Setup project directories
setup_directories() {
    print_step "Setting up project directories..."
    
    mkdir -p uploads
    mkdir -p logs
    chmod 755 uploads
    chmod 755 logs
    
    print_success "Directories created"
}

# Cleanup previous deployment
cleanup_deployment() {
    print_step "Cleaning up previous deployment..."
    
    # Stop all containers
    $DOCKER_COMPOSE_CMD down --remove-orphans 2>/dev/null || true
    
    if [[ "$DEPLOYMENT_MODE" == "reset" ]]; then
        print_warning "RESET mode: Destroying all data..."
        $DOCKER_COMPOSE_CMD down -v 2>/dev/null || true
        docker system prune -af --volumes 2>/dev/null || true
    else
        # Clean up orphaned containers and networks
        docker system prune -f 2>/dev/null || true
    fi
    
    print_success "Cleanup completed"
}

# Build Docker images
build_images() {
    print_step "Building Docker images..."
    
    # Build with no cache for fresh builds
    if [[ "$DEPLOYMENT_MODE" == "reinstall" ]] || [[ "$DEPLOYMENT_MODE" == "reset" ]]; then
        $DOCKER_COMPOSE_CMD build --no-cache
    else
        $DOCKER_COMPOSE_CMD build
    fi
    
    print_success "Docker images built"
}

# Start database services
start_database_services() {
    print_step "Starting database services..."
    
    $DOCKER_COMPOSE_CMD up -d db redis
    
    # Wait for database with timeout
    print_step "Waiting for database to be ready..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if $DOCKER_COMPOSE_CMD exec -T db pg_isready -U speedsend_user -d speedsend_db &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "Database failed to start"
        print_info "Database logs:"
        $DOCKER_COMPOSE_CMD logs db
        exit 1
    fi
    
    print_success "Database is ready"
    
    # Wait for Redis
    print_step "Waiting for Redis to be ready..."
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if $DOCKER_COMPOSE_CMD exec -T redis redis-cli ping &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "Redis failed to start"
        print_info "Redis logs:"
        $DOCKER_COMPOSE_CMD logs redis
        exit 1
    fi
    
    print_success "Redis is ready"
}

# Start backend services
start_backend_services() {
    print_step "Starting backend services..."
    
    $DOCKER_COMPOSE_CMD up -d backend
    
    # Wait for backend to be healthy
    print_step "Waiting for backend to be ready..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f http://localhost:8000/api/v1/health &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "Backend failed to start"
        print_info "Backend logs:"
        $DOCKER_COMPOSE_CMD logs backend
        exit 1
    fi
    
    print_success "Backend is ready"
}

# Run database migrations
run_migrations() {
    print_step "Running database migrations..."
    
    if $DOCKER_COMPOSE_CMD exec -T backend poetry run alembic upgrade head; then
        print_success "Database migrations completed"
    else
        print_error "Database migration failed"
        print_info "Backend logs:"
        $DOCKER_COMPOSE_CMD logs backend
        exit 1
    fi
}

# Start worker services
start_worker_services() {
    print_step "Starting worker services..."
    
    $DOCKER_COMPOSE_CMD up -d celery_worker celery_beat
    
    print_success "Worker services started"
}

# Start frontend services
start_frontend_services() {
    print_step "Starting frontend services..."
    
    $DOCKER_COMPOSE_CMD up -d frontend
    
    # Wait for frontend
    print_step "Waiting for frontend to be ready..."
    sleep 15
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f http://localhost:3000 &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_warning "Frontend health check timeout (may still be starting)"
    else
        print_success "Frontend is ready"
    fi
}

# Verify deployment
verify_deployment() {
    print_step "Verifying deployment..."
    
    # Check all services are running
    local services=("db" "redis" "backend" "celery_worker" "celery_beat" "frontend")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if $DOCKER_COMPOSE_CMD ps | grep "$service" | grep -q "Up"; then
            print_success "$service is running"
        else
            print_error "$service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_success "All services are running"
    else
        print_error "Some services failed: ${failed_services[*]}"
        return 1
    fi
    
    # Test API endpoints
    if curl -f http://localhost:8000/api/v1/health &> /dev/null; then
        print_success "Backend API is responding"
    else
        print_warning "Backend API health check failed"
    fi
    
    if curl -f http://localhost:3000 &> /dev/null; then
        print_success "Frontend is responding"
    else
        print_warning "Frontend health check failed"
    fi
}

# Show final status
show_final_status() {
    print_header "${FIRE} Speed-Send Deployment Complete!"
    
    echo -e "${GREEN}${ROCKET} Application URLs:${NC}"
    echo -e "   ${CYAN}Frontend (Web UI):${NC} http://localhost:3000"
    echo -e "   ${CYAN}Backend API Docs:${NC}  http://localhost:8000/docs"
    echo -e "   ${CYAN}Backend API ReDoc:${NC} http://localhost:8000/redoc"
    echo ""
    
    echo -e "${BLUE}${GEAR} Management Commands:${NC}"
    echo -e "   ${YELLOW}View logs:${NC}        $DOCKER_COMPOSE_CMD logs -f"
    echo -e "   ${YELLOW}Stop services:${NC}    $DOCKER_COMPOSE_CMD down"
    echo -e "   ${YELLOW}Restart:${NC}          $DOCKER_COMPOSE_CMD restart"
    echo -e "   ${YELLOW}Reinstall:${NC}        ./deploy.sh --reinstall"
    echo -e "   ${YELLOW}Fix issues:${NC}       ./deploy.sh --fix"
    echo -e "   ${YELLOW}Reset all:${NC}        ./deploy.sh --reset"
    echo ""
    
    echo -e "${GREEN}${INFO} Next Steps:${NC}"
    echo "1. Open http://localhost:3000 in your browser"
    echo "2. Navigate to 'Accounts' to add Google Workspace accounts"
    echo "3. Use 'Ultra-Fast Send' to create high-performance campaigns"
    echo ""
    
    echo -e "${YELLOW}${WARNING} Important Notes:${NC}"
    echo "• Configure Google Cloud Project with Gmail API enabled"
    echo "• Set up Domain-Wide Delegation for service accounts"
    echo "• Use admin email from your Google Workspace domain"
    echo "• For production: configure SSL, firewall, and monitoring"
    echo ""
    
    # Show container status
    echo -e "${PURPLE}Container Status:${NC}"
    $DOCKER_COMPOSE_CMD ps
}

# Error handler
handle_error() {
    print_error "Deployment failed at step: $1"
    print_info "Logs for debugging:"
    $DOCKER_COMPOSE_CMD logs --tail=50
    print_info "To fix issues, run: ./deploy.sh --fix"
    exit 1
}

# Main deployment function
main() {
    parse_arguments "$@"
    
    print_header "${ROCKET} Speed-Send Automated Deployment"
    print_info "Mode: $DEPLOYMENT_MODE"
    
    # Step 1: System setup
    detect_system || handle_error "System detection"
    install_dependencies || handle_error "Dependencies installation"
    install_docker || handle_error "Docker installation"
    install_docker_compose || handle_error "Docker Compose setup"
    
    # Step 2: Environment setup
    free_ports || handle_error "Port cleanup"
    setup_environment || handle_error "Environment setup"
    setup_directories || handle_error "Directory setup"
    
    # Step 3: Deployment
    cleanup_deployment || handle_error "Cleanup"
    build_images || handle_error "Image building"
    start_database_services || handle_error "Database services"
    start_backend_services || handle_error "Backend services"
    run_migrations || handle_error "Database migrations"
    start_worker_services || handle_error "Worker services"
    start_frontend_services || handle_error "Frontend services"
    
    # Step 4: Verification
    verify_deployment || handle_error "Deployment verification"
    
    # Step 5: Success
    show_final_status
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi