#!/bin/bash

echo "Fixing frontend API routing issue..."

# Stop frontend container
echo "Stopping frontend container..."
docker compose stop frontend 2>/dev/null || docker-compose stop frontend 2>/dev/null || true
docker compose rm -f frontend 2>/dev/null || docker-compose rm -f frontend 2>/dev/null || true

# Remove old frontend images
echo "Removing old frontend images..."
docker rmi $(docker images -q "*frontend*" 2>/dev/null) 2>/dev/null || true
docker rmi speedsend_frontend 2>/dev/null || true

# Rebuild frontend with correct nginx config
echo "Rebuilding frontend with API proxy configuration..."
docker compose build --no-cache frontend 2>/dev/null || docker-compose build --no-cache frontend 2>/dev/null

# Start frontend
echo "Starting frontend with API routing..."
docker compose up -d frontend 2>/dev/null || docker-compose up -d frontend 2>/dev/null

echo "Frontend fix completed!"
echo "The app should now be able to connect to the backend API."
echo ""
echo "Frontend URL: http://localhost:3000"
echo "Backend API: http://localhost:8000"
echo ""
echo "Check status with: docker compose ps"