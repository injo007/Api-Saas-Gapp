#!/bin/bash

# Speed-Send Deployment Script
# This script sets up the environment and deploys the Speed-Send application

set -e  # Exit on any error

echo "🚀 Starting Speed-Send deployment..."

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create .env file from template if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.template .env
    echo "✅ .env file created"
fi

# Generate SECRET_KEY if it's still the default
SECRET_KEY=$(grep "^SECRET_KEY=" .env | cut -d '=' -f2)
if [ "$SECRET_KEY" = "your_secret_key_here_change_this_in_production" ] || [ -z "$SECRET_KEY" ]; then
    echo "🔑 Generating SECRET_KEY..."
    NEW_SECRET_KEY=$(openssl rand -hex 32)
    sed -i "s/SECRET_KEY=.*/SECRET_KEY=$NEW_SECRET_KEY/" .env
    echo "✅ SECRET_KEY generated"
fi

# Generate ENCRYPTION_KEY if it's still the default
ENCRYPTION_KEY=$(grep "^ENCRYPTION_KEY=" .env | cut -d '=' -f2)
if [ "$ENCRYPTION_KEY" = "your_encryption_key_here_change_this_in_production" ] || [ -z "$ENCRYPTION_KEY" ]; then
    echo "🔐 Generating ENCRYPTION_KEY..."
    NEW_ENCRYPTION_KEY=$(openssl rand -base64 32)
    sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$NEW_ENCRYPTION_KEY/" .env
    echo "✅ ENCRYPTION_KEY generated"
fi

# Check if PostgreSQL password is still default
POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2)
if [ "$POSTGRES_PASSWORD" = "your_secure_password_here" ]; then
    echo "⚠️  WARNING: PostgreSQL password is still the default value."
    echo "Please edit the .env file and set a secure password for POSTGRES_PASSWORD"
    echo "Also update the DATABASE_URL to match the new password."
    echo ""
    read -p "Do you want to edit the .env file now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    else
        echo "⚠️  Please remember to update the PostgreSQL password before using the application!"
    fi
fi

# Create uploads directory for backend
echo "📁 Creating uploads directory..."
mkdir -p uploads
chmod 755 uploads

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down --remove-orphans || true

# Build and start services
echo "🏗️  Building Docker images..."
docker-compose build

echo "🚀 Starting database and Redis..."
docker-compose up -d db redis

echo "⏳ Waiting for database and Redis to be healthy..."
# Wait for database to be ready
while ! docker-compose exec -T db pg_isready -U $(grep "^POSTGRES_USER=" .env | cut -d '=' -f2) -d $(grep "^POSTGRES_DB=" .env | cut -d '=' -f2) &> /dev/null; do
    echo "⏳ Waiting for PostgreSQL..."
    sleep 2
done

# Wait for Redis to be ready
while ! docker-compose exec -T redis redis-cli ping &> /dev/null; do
    echo "⏳ Waiting for Redis..."
    sleep 2
done

echo "✅ Database and Redis are ready!"

echo "🚀 Starting backend services..."
docker-compose up -d backend celery_worker celery_beat

echo "⏳ Waiting for backend to be ready..."
sleep 10

echo "🔄 Running database migrations..."
docker-compose exec -T backend poetry run alembic upgrade head

echo "🚀 Starting frontend..."
docker-compose up -d frontend

echo ""
echo "🎉 Speed-Send deployment completed successfully!"
echo ""
echo "📱 Application URLs:"
echo "   Frontend (Web UI): http://localhost:3000"
echo "   Backend API Docs:  http://localhost:8000/docs"
echo "   Backend API ReDoc: http://localhost:8000/redoc"
echo ""
echo "📊 To view logs:"
echo "   All services:      docker-compose logs -f"
echo "   Backend only:      docker-compose logs -f backend"
echo "   Frontend only:     docker-compose logs -f frontend"
echo "   Celery worker:     docker-compose logs -f celery_worker"
echo ""
echo "🛑 To stop the application:"
echo "   docker-compose down"
echo ""
echo "📋 Next steps:"
echo "1. Open http://localhost:3000 in your browser"
echo "2. Go to the Accounts page to add your Google Workspace service account"
echo "3. Create and send your first campaign!"
echo ""
echo "⚠️  Remember to:"
echo "   - Configure your Google Cloud Project with Gmail API enabled"
echo "   - Set up Domain-Wide Delegation for your service account"
echo "   - Use the admin email from your Google Workspace domain"
echo ""