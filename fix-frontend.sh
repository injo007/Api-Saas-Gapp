#!/bin/bash

echo "================================"
echo "  Speed-Send Frontend Fix"
echo "================================"
echo

# Stop the frontend container
echo "Stopping frontend container..."
docker-compose stop frontend

# Remove the frontend container and image
echo "Removing old frontend container and image..."
docker-compose rm -f frontend
docker rmi $(docker images -q speedsend_frontend 2>/dev/null) 2>/dev/null || true

# Rebuild the frontend
echo "Rebuilding frontend with proper build process..."
docker-compose build --no-cache frontend

# Start the frontend
echo "Starting frontend container..."
docker-compose up -d frontend

# Wait a moment for startup
echo "Waiting for frontend to start..."
sleep 10

# Check status
echo "Checking container status..."
docker-compose ps frontend

echo
echo "Frontend fix completed!"
echo "Access your application at: http://localhost:3000"
echo
echo "If you still see issues, check the logs with:"
echo "docker-compose logs frontend"