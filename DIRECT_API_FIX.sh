#!/bin/bash

echo "🔧 DIRECT API FIX - Rebuilding main.py and API structure"
echo "========================================================"

# Stop all services
echo "Stopping all services..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null

# Fix main.py to ensure proper API inclusion
echo "Fixing main.py..."
cat > backend/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# Database and core imports
from database import engine, Base
from api.v1.api import api_router

# Create database tables
def create_tables():
    Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    create_tables()
    yield
    # Shutdown - nothing to do

# Create FastAPI application
app = FastAPI(
    title="SpeedSend API",
    description="Email management platform with Gmail integration",
    version="2.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix="/api/v1")

# Root endpoint
@app.get("/")
def read_root():
    return {"message": "SpeedSend API v2.0", "status": "operational"}

# Health endpoint at root level
@app.get("/health")
def health_check():
    return {"status": "healthy", "version": "2.0.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Create a minimal working API router
echo "Creating minimal API router..."
cat > backend/api/v1/api.py << 'EOF'
from fastapi import APIRouter

api_router = APIRouter()

# Import and include endpoints individually to avoid import errors
try:
    from api.v1.endpoints.health import router as health_router
    api_router.include_router(health_router, prefix="/health", tags=["health"])
    print("✅ Health router included")
except Exception as e:
    print(f"❌ Failed to include health router: {e}")

try:
    from api.v1.endpoints.accounts import router as accounts_router
    api_router.include_router(accounts_router, prefix="/accounts", tags=["accounts"])
    print("✅ Accounts router included")
except Exception as e:
    print(f"❌ Failed to include accounts router: {e}")

try:
    from api.v1.endpoints.campaigns import router as campaigns_router
    api_router.include_router(campaigns_router, prefix="/campaigns", tags=["campaigns"])
    print("✅ Campaigns router included")
except Exception as e:
    print(f"❌ Failed to include campaigns router: {e}")

# Add a simple test endpoint
@api_router.get("/test")
def test_endpoint():
    return {"message": "API router is working", "status": "success"}
EOF

# Remove all backend images and containers
echo "Removing old backend images..."
docker rmi $(docker images -q "*backend*" 2>/dev/null) 2>/dev/null || true
docker rmi $(docker images -q "*speedsend*" 2>/dev/null) 2>/dev/null || true

# Clean up any stopped containers
docker container prune -f 2>/dev/null || true

# Rebuild backend
echo "Rebuilding backend from scratch..."
docker compose build --no-cache backend 2>/dev/null || docker-compose build --no-cache backend 2>/dev/null

# Start database first
echo "Starting database..."
docker compose up -d db redis 2>/dev/null || docker-compose up -d db redis 2>/dev/null
sleep 10

# Start backend
echo "Starting backend..."
docker compose up -d backend 2>/dev/null || docker-compose up -d backend 2>/dev/null
sleep 20

# Start other services
echo "Starting other services..."
docker compose up -d frontend celery_worker celery_beat 2>/dev/null || docker-compose up -d frontend celery_worker celery_beat 2>/dev/null
sleep 10

# Test endpoints
echo ""
echo "🧪 Testing API endpoints..."
echo "============================"

# Test root endpoint
echo -n "Root endpoint: "
if curl -s http://localhost:8000/ | grep -q "SpeedSend"; then
    echo "✅ WORKING"
else
    echo "❌ NOT WORKING"
fi

# Test health endpoint (both locations)
echo -n "Health endpoint (/health): "
if curl -s http://localhost:8000/health | grep -q "healthy"; then
    echo "✅ WORKING"
else
    echo "❌ NOT WORKING"
fi

echo -n "Health endpoint (/api/v1/health): "
if curl -s http://localhost:8000/api/v1/health | grep -q "healthy"; then
    echo "✅ WORKING"
else
    echo "❌ NOT WORKING"
fi

# Test API router test endpoint
echo -n "API test endpoint: "
if curl -s http://localhost:8000/api/v1/test | grep -q "working"; then
    echo "✅ WORKING"
else
    echo "❌ NOT WORKING"
fi

# Test main endpoints
echo -n "Accounts endpoint: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/accounts | grep -q "200"; then
    echo "✅ WORKING"
else
    echo "❌ NOT WORKING"
fi

echo -n "Campaigns endpoint: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/campaigns | grep -q "200"; then
    echo "✅ WORKING"
else
    echo "❌ NOT WORKING"
fi

# Show container status
echo ""
echo "📊 Container Status:"
docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null

echo ""
echo "🔗 Access URLs:"
echo "Frontend: http://localhost:3000"
echo "Backend API: http://localhost:8000"
echo "API Test: http://localhost:8000/api/v1/test"
echo "Health Check: http://localhost:8000/health"
echo "API Docs: http://localhost:8000/docs"

echo ""
echo "📋 Check backend logs if issues persist:"
echo "docker compose logs backend"
echo ""
echo "✅ Direct API fix completed!"