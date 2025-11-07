#!/bin/bash

# Quick Deploy Script for Ubuntu 22.04
# This script handles common issues and provides better error reporting

set -e  # Exit on any error

echo "🚀 Starting Speed-Send deployment on Ubuntu 22.04..."

# Function to print colored output
print_status() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. It's recommended to run as a regular user with sudo access."
fi

# Check system requirements
print_status "Checking system requirements..."

# Check Ubuntu version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$VERSION_ID" != "22.04" ]]; then
        print_warning "This script is optimized for Ubuntu 22.04. You're running $PRETTY_NAME"
    fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first:"
    echo "curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "sudo sh get-docker.sh"
    echo "sudo usermod -aG docker \$USER"
    echo "newgrp docker"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first:"
    echo "sudo curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
    echo "sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

# Use docker compose or docker-compose based on availability
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

print_success "Docker and Docker Compose are installed"

# Check if ports are available
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        print_error "Port $port is already in use. Please free the port or modify docker-compose.yml"
        echo "You can check what's using the port with: sudo netstat -tulpn | grep :$port"
        return 1
    fi
}

print_status "Checking if required ports are available..."
check_port 3000  # Frontend
check_port 8000  # Backend
check_port 5432  # PostgreSQL
check_port 6379  # Redis

print_success "All required ports are available"

# Create .env file from template if it doesn't exist
if [ ! -f .env ]; then
    print_status "Creating .env file from template..."
    cp .env.template .env
    print_success ".env file created"
else
    print_warning ".env file already exists, skipping creation"
fi

# Generate SECRET_KEY if it's still the default
SECRET_KEY=$(grep "^SECRET_KEY=" .env | cut -d '=' -f2)
if [ "$SECRET_KEY" = "your_secret_key_here_change_this_in_production" ] || [ -z "$SECRET_KEY" ]; then
    print_status "Generating SECRET_KEY..."
    NEW_SECRET_KEY=$(openssl rand -hex 32)
    sed -i "s/SECRET_KEY=.*/SECRET_KEY=$NEW_SECRET_KEY/" .env
    print_success "SECRET_KEY generated"
fi

# Generate ENCRYPTION_KEY if it's still the default
ENCRYPTION_KEY=$(grep "^ENCRYPTION_KEY=" .env | cut -d '=' -f2)
if [ "$ENCRYPTION_KEY" = "your_encryption_key_here_change_this_in_production" ] || [ -z "$ENCRYPTION_KEY" ]; then
    print_status "Generating ENCRYPTION_KEY..."
    NEW_ENCRYPTION_KEY=$(openssl rand -base64 32)
    sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$NEW_ENCRYPTION_KEY/" .env
    print_success "ENCRYPTION_KEY generated"
fi

# Check if PostgreSQL password is still default
POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2)
if [ "$POSTGRES_PASSWORD" = "your_secure_password_here" ]; then
    print_warning "PostgreSQL password is still the default value."
    print_status "Generating secure PostgreSQL password..."
    NEW_DB_PASSWORD=$(openssl rand -base64 32)
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$NEW_DB_PASSWORD/" .env
    sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://speedsend_user:$NEW_DB_PASSWORD@db:5432/speedsend_db|" .env
    print_success "PostgreSQL password updated"
fi

# Create uploads directory for backend
print_status "Creating uploads directory..."
mkdir -p uploads
chmod 755 uploads
print_success "Uploads directory created"

# Stop any existing containers
print_status "Stopping existing containers..."
$DOCKER_COMPOSE down --remove-orphans || true
print_success "Existing containers stopped"

# Clean up any orphaned volumes if needed
print_status "Cleaning up Docker system..."
docker system prune -f || true

# Build images
print_status "Building Docker images..."
$DOCKER_COMPOSE build

# Start database and Redis first
print_status "Starting database and Redis..."
$DOCKER_COMPOSE up -d db redis

# Wait for database to be ready
print_status "Waiting for database to be ready..."
max_attempts=60
attempt=0
while ! $DOCKER_COMPOSE exec -T db pg_isready -U speedsend_user -d speedsend_db &> /dev/null; do
    if [ $attempt -ge $max_attempts ]; then
        print_error "Database failed to start within 2 minutes"
        print_status "Database logs:"
        $DOCKER_COMPOSE logs db
        exit 1
    fi
    echo -n "."
    sleep 2
    ((attempt++))
done
echo ""
print_success "Database is ready!"

# Wait for Redis to be ready
print_status "Waiting for Redis to be ready..."
max_attempts=30
attempt=0
while ! $DOCKER_COMPOSE exec -T redis redis-cli ping &> /dev/null; do
    if [ $attempt -ge $max_attempts ]; then
        print_error "Redis failed to start within 1 minute"
        print_status "Redis logs:"
        $DOCKER_COMPOSE logs redis
        exit 1
    fi
    echo -n "."
    sleep 2
    ((attempt++))
done
echo ""
print_success "Redis is ready!"

# Start backend services
print_status "Starting backend services..."
$DOCKER_COMPOSE up -d backend

# Wait for backend to be ready
print_status "Waiting for backend to be ready..."
sleep 15

# Check if backend is healthy
max_attempts=30
attempt=0
while ! curl -f http://localhost:8000/api/v1/health &> /dev/null; do
    if [ $attempt -ge $max_attempts ]; then
        print_error "Backend failed to start properly"
        print_status "Backend logs:"
        $DOCKER_COMPOSE logs backend
        exit 1
    fi
    echo -n "."
    sleep 2
    ((attempt++))
done
echo ""
print_success "Backend is healthy!"

# Run database migrations
print_status "Running database migrations..."
if $DOCKER_COMPOSE exec -T backend poetry run alembic upgrade head; then
    print_success "Database migrations completed"
else
    print_error "Database migration failed"
    print_status "Backend logs:"
    $DOCKER_COMPOSE logs backend
    exit 1
fi

# Start Celery workers
print_status "Starting Celery workers..."
$DOCKER_COMPOSE up -d celery_worker celery_beat

# Start frontend
print_status "Starting frontend..."
$DOCKER_COMPOSE up -d frontend

# Wait for frontend to be ready
print_status "Waiting for frontend to be ready..."
sleep 10

# Verify all services are running
print_status "Verifying all services..."
if ! $DOCKER_COMPOSE ps | grep -q "Up"; then
    print_error "Some services failed to start"
    $DOCKER_COMPOSE ps
    exit 1
fi

# Final health checks
print_status "Performing final health checks..."

# Check backend API
if curl -f http://localhost:8000/api/v1/health &> /dev/null; then
    print_success "Backend API is responding"
else
    print_warning "Backend API health check failed"
fi

# Check frontend
if curl -f http://localhost:3000 &> /dev/null; then
    print_success "Frontend is responding"
else
    print_warning "Frontend health check failed"
fi

# Display final status
echo ""
echo "🎉 Speed-Send deployment completed!"
echo ""
echo "📱 Application URLs:"
echo "   Frontend (Web UI): http://localhost:3000"
echo "   Backend API Docs:  http://localhost:8000/docs"
echo "   Backend API ReDoc: http://localhost:8000/redoc"
echo ""
echo "📊 To view logs:"
echo "   All services:      $DOCKER_COMPOSE logs -f"
echo "   Backend only:      $DOCKER_COMPOSE logs -f backend"
echo "   Frontend only:     $DOCKER_COMPOSE logs -f frontend"
echo "   Celery worker:     $DOCKER_COMPOSE logs -f celery_worker"
echo ""
echo "🛑 To stop the application:"
echo "   $DOCKER_COMPOSE down"
echo ""
echo "📋 Next steps:"
echo "1. Open http://localhost:3000 in your browser"
echo "2. Go to the Accounts page to add your Google Workspace service account"
echo "3. Use the Ultra-Fast Send feature to create and send campaigns!"
echo ""
echo "⚠️  Remember to:"
echo "   - Configure your Google Cloud Project with Gmail API enabled"
echo "   - Set up Domain-Wide Delegation for your service account"
echo "   - Use the admin email from your Google Workspace domain"
echo ""

# Show running containers
print_status "Currently running containers:"
$DOCKER_COMPOSE ps