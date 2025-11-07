#!/bin/bash

echo "🔧 Force rebuilding with clean cache..."

# Stop everything
docker-compose down 2>/dev/null || true

# Remove all Docker cache and images related to this project
echo "🧹 Cleaning Docker cache..."
docker system prune -af
docker builder prune -af

# Remove any existing volumes to start fresh
echo "🗑️ Removing volumes..."
docker volume prune -f

# Verify the Dockerfile has correct commands
echo "✅ Current Dockerfile Poetry command:"
grep -A 3 "poetry install" backend/Dockerfile

# Force rebuild backend with no cache
echo "🏗️ Force rebuilding backend..."
docker-compose build --no-cache --pull backend

# Continue with deployment
echo "🚀 Starting deployment..."
./deploy.sh --reinstall