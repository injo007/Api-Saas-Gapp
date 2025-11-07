#!/bin/bash

# Quick fix script for the current email-validator error

echo "🔧 Quick Fix: Resolving email-validator dependency issue..."

# Stop containers
echo "Stopping containers..."
docker-compose down

# Clean Docker cache
echo "Cleaning Docker cache..."
docker system prune -f

# Fix the backend container by installing missing dependency
echo "Fixing backend container..."
docker-compose exec backend pip install email-validator pydantic[email] || true

# Rebuild and restart
echo "Rebuilding backend..."
docker-compose build --no-cache backend

echo "Starting services..."
docker-compose up -d

echo "Waiting for services to start..."
sleep 30

echo "Checking status..."
docker-compose ps

echo "Testing backend..."
curl -s http://localhost:8000/health && echo "✓ Backend is working!" || echo "✗ Backend still has issues"

echo "Testing frontend..."
curl -s http://localhost:3000 >/dev/null && echo "✓ Frontend is accessible!" || echo "✗ Frontend not accessible"

echo ""
echo "🎉 Quick fix completed!"
echo "Frontend: http://localhost:3000"
echo "Backend:  http://localhost:8000"
echo ""
echo "If issues persist, run: ./deploy-final.sh"