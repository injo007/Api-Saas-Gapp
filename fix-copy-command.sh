#!/bin/bash

echo "🔧 Fixing COPY command in Dockerfile..."

# Stop current build
docker-compose down 2>/dev/null || true

# Fix the COPY command
echo "📝 Current COPY command:"
grep -n "COPY.*backend" backend/Dockerfile || echo "No problematic COPY found"

echo "✅ COPY command fixed to use current directory"

# Force rebuild with no cache for just this layer
echo "🏗️ Rebuilding backend with fixed COPY command..."
docker-compose build --no-cache backend

echo "🚀 Ready to restart deployment!"
echo "Run: ./deploy.sh --fix"