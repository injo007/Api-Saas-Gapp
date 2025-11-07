#!/bin/bash

# Quick fix for Poetry --no-dev error
echo "🔧 Fixing Poetry command in Dockerfile..."

# Stop current deployment
docker-compose down 2>/dev/null || true

# Fix the Dockerfile CMD line
sed -i 's/CMD \["poetry", "run", "uvicorn"/CMD ["uvicorn"/' backend/Dockerfile

# Rebuild backend only with no cache
echo "🏗️ Rebuilding backend with fixed Poetry command..."
docker-compose build --no-cache backend

echo "✅ Poetry fix applied! Resume deployment with:"
echo "./deploy.sh --fix"