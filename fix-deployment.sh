#!/bin/bash

# Speed-Send Deployment Fix Script
# This script fixes common deployment issues and ensures clean setup

set -e  # Exit on any error

echo "🚀 Starting Speed-Send Deployment Fix..."

# Function to generate random keys
generate_key() {
    openssl rand -hex 32
}

# Step 1: Clean up any existing containers and volumes
echo "🧹 Cleaning up existing containers..."
docker-compose down --volumes --remove-orphans 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Step 2: Remove any dangling images
echo "🗑️ Removing dangling images..."
docker image prune -f 2>/dev/null || true

# Step 3: Setup environment file
echo "⚙️ Setting up environment file..."
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.template .env
    
    # Generate secure keys
    SECRET_KEY=$(generate_key)
    ENCRYPTION_KEY=$(generate_key)
    
    # Update .env with generated keys
    sed -i "s/your_secret_key_here_change_this_in_production/$SECRET_KEY/" .env
    sed -i "s/your_encryption_key_here_change_this_in_production/$ENCRYPTION_KEY/" .env
    
    echo "✅ Environment file created with secure keys"
else
    echo "✅ Environment file already exists"
fi

# Step 4: Create necessary directories
echo "📁 Creating required directories..."
mkdir -p uploads
mkdir -p backend/uploads
chmod 755 uploads
chmod 755 backend/uploads

# Step 5: Clean rebuild backend image
echo "🔨 Building backend image..."
docker-compose build --no-cache backend

# Step 6: Start services in correct order
echo "🚀 Starting services..."
docker-compose up -d db redis

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
sleep 10

# Start backend services
docker-compose up -d backend celery_worker celery_beat

# Wait for backend to be ready
echo "⏳ Waiting for backend to be ready..."
sleep 15

# Start frontend
docker-compose up -d frontend

# Step 7: Run database migrations
echo "🗃️ Running database migrations..."
docker-compose exec -T backend alembic upgrade head

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "🌐 Application URLs:"
echo "   Frontend: http://localhost:3000"
echo "   Backend API: http://localhost:8000"
echo "   API Docs: http://localhost:8000/docs"
echo ""
echo "📊 To check service status:"
echo "   docker-compose ps"
echo ""
echo "📋 To view logs:"
echo "   docker-compose logs -f [service_name]"
echo ""