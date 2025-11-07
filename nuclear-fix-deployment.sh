#!/bin/bash

echo "🚀 Nuclear Fix for Docker Build Issues"
echo "======================================"

# Stop everything
echo "🛑 Stopping all containers..."
docker-compose down --remove-orphans 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Complete Docker cleanup
echo "🧹 Complete Docker cleanup..."
docker system prune -af --volumes
docker builder prune -af
docker image prune -af
docker network prune -f
docker volume prune -f

# Remove any cached build contexts
echo "🗑️ Removing build contexts..."
docker builder rm --all-inactive 2>/dev/null || true

# Show current Dockerfile content
echo "📄 Current Dockerfile COPY commands:"
echo "=================================="
grep -n "COPY" backend/Dockerfile

echo ""
echo "🔧 Expected COPY command should be:"
echo "COPY . /app/"
echo ""

# Force rebuild with absolute no cache
echo "🏗️ Force rebuilding with zero cache..."
echo "=================================="
DOCKER_BUILDKIT=1 docker-compose build --no-cache --pull --force-rm backend

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Backend build successful!"
    echo "🚀 Starting deployment..."
    ./deploy.sh --reinstall
else
    echo ""
    echo "❌ Build failed. Let's check the issue..."
    echo ""
    echo "🔍 Debugging information:"
    echo "========================"
    echo "Current directory contents:"
    ls -la
    echo ""
    echo "Backend directory contents:"
    ls -la backend/
    echo ""
    echo "Docker version:"
    docker --version
    echo ""
    echo "Docker Compose version:"
    docker-compose --version || docker compose version
fi