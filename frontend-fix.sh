#!/bin/bash

# Frontend Fix Script - Resolve blank page issue

echo "🔧 Fixing frontend blank page issue..."

# Check frontend container logs
echo "Checking frontend container status..."
docker ps | grep frontend || echo "Frontend container not running!"

# Check frontend logs
echo "Frontend logs:"
docker logs speedsend_frontend 2>&1 | tail -20 || echo "Could not get frontend logs"

# Check if frontend is actually running
echo "Testing frontend directly..."
curl -v http://localhost:3000 2>&1 | head -20

# Check nginx configuration
echo "Checking nginx..."
docker logs speedsend_nginx 2>&1 | tail -10 || echo "Could not get nginx logs"

# Test if we can access the app directly
echo "Testing if React app loads..."
docker exec speedsend_frontend ls -la /app/ 2>/dev/null || echo "Cannot access frontend container"

# Check if the build was successful
echo "Checking if frontend built correctly..."
docker exec speedsend_frontend ls -la /app/dist/ 2>/dev/null || echo "No dist folder found"

# Restart frontend services
echo "Restarting frontend services..."
docker-compose restart frontend nginx

echo "Waiting for restart..."
sleep 15

# Test again
echo "Testing after restart..."
curl -s http://localhost:3000 | head -10 || echo "Still not accessible"

echo "Frontend fix script completed!"
echo "Check: http://localhost:3000"