#!/bin/bash

# Quick deployment script - minimal output
set -e

echo "Starting deployment..."

# Clean up
docker-compose down --volumes --remove-orphans 2>/dev/null || true

# Setup .env if needed
if [ ! -f .env ]; then
    cp .env.template .env
    SECRET_KEY=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    sed -i "s/your_secret_key_here_change_this_in_production/$SECRET_KEY/" .env
    sed -i "s/your_encryption_key_here_change_this_in_production/$ENCRYPTION_KEY/" .env
fi

# Create directories
mkdir -p uploads backend/uploads
chmod 755 uploads backend/uploads

# Deploy
docker-compose build --no-cache backend
docker-compose up -d

# Wait and migrate
sleep 20
docker-compose exec -T backend alembic upgrade head

echo "✅ Deployed! Frontend: http://localhost:3000 | Backend: http://localhost:8000"