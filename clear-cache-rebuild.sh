#!/bin/bash

echo "🔧 Clearing Docker cache and forcing complete rebuild..."

# Stop everything
docker-compose down 2>/dev/null || true

# Remove ALL Docker cache and build layers
echo "🧹 Removing all Docker cache..."
docker system prune -af --volumes
docker builder prune -af

# Remove any dangling images
docker image prune -af

# Verify the current Dockerfile content
echo "📝 Current Dockerfile COPY commands:"
grep -n "COPY" backend/Dockerfile

# Force rebuild ALL services with no cache and pull latest base images
echo "🏗️ Force rebuilding ALL images with no cache..."
docker-compose build --no-cache --pull

echo "✅ Complete rebuild finished. Ready to deploy!"
echo "Run: ./deploy.sh --reinstall"