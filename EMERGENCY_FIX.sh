#!/bin/bash

echo "🚨 EMERGENCY FIX: Rebuilding backend with working API structure"
echo "=============================================================="

# Stop all services
echo "Stopping all services..."
docker compose down

# Remove problematic backend image
echo "Removing old backend image..."
docker rmi $(docker images -q "*backend*" "*speedsend*backend*" 2>/dev/null) 2>/dev/null || true

# Create a simple working API router first
echo "Creating working API router..."
cat > backend/api/v1/api.py << 'EOF'
from fastapi import APIRouter
from api.v1.endpoints import health, accounts, campaigns

api_router = APIRouter()

# Include working routers only
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(accounts.router, prefix="/accounts", tags=["accounts"]) 
api_router.include_router(campaigns.router, prefix="/campaigns", tags=["campaigns"])
EOF

echo "Rebuilding backend with basic working structure..."
docker compose build --no-cache backend

echo "Starting services..."
docker compose up -d db redis
sleep 10
docker compose up -d backend
sleep 15
docker compose up -d frontend celery_worker celery_beat

echo "Waiting for services to stabilize..."
sleep 20

echo "Testing basic endpoints..."
curl http://localhost:8000/api/v1/health
echo ""
curl http://localhost:8000/api/v1/accounts
echo ""

echo ""
echo "✅ Basic backend should now be working!"
echo "📝 You can access:"
echo "   Frontend: http://localhost:3000"
echo "   Backend:  http://localhost:8000"
echo "   API Docs: http://localhost:8000/docs"
echo ""
echo "🔧 To add the advanced features back after confirming this works:"
echo "   1. Test basic functionality first"
echo "   2. Then we can add analytics, data management modules one by one"