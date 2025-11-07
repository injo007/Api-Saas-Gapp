#!/bin/bash

echo "🔧 Fixing API routing issues..."

# Restart the backend service to apply API router fixes
echo "Restarting backend service..."
docker compose restart backend || docker-compose restart backend

echo "Waiting for backend to stabilize..."
sleep 15

echo "Testing API endpoints..."

# Test health endpoint
if curl -f http://localhost:8000/api/v1/health >/dev/null 2>&1; then
    echo "✅ Health endpoint: WORKING"
else
    echo "❌ Health endpoint: NOT WORKING"
fi

# Test accounts endpoint
if curl -f http://localhost:8000/api/v1/accounts >/dev/null 2>&1; then
    echo "✅ Accounts endpoint: WORKING"
else
    echo "❌ Accounts endpoint: NOT WORKING"
fi

# Test campaigns endpoint
if curl -f http://localhost:8000/api/v1/campaigns >/dev/null 2>&1; then
    echo "✅ Campaigns endpoint: WORKING"
else
    echo "❌ Campaigns endpoint: NOT WORKING"
fi

# Test analytics endpoint
if curl -f http://localhost:8000/api/v1/analytics >/dev/null 2>&1; then
    echo "✅ Analytics endpoint: WORKING"
else
    echo "❌ Analytics endpoint: NOT WORKING"
fi

echo ""
echo "If endpoints are still not working, try full rebuild:"
echo "docker compose down"
echo "docker compose build --no-cache backend"
echo "docker compose up -d"

echo ""
echo "Check backend logs:"
echo "docker compose logs backend"