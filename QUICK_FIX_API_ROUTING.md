# 🔧 Quick Fix for API Routing Issues

## Problem
The backend is showing "404 Not Found" for API endpoints because the routing configuration needs to be updated.

## ✅ Solution Applied
I've fixed the API router configuration in `backend/api/v1/api.py` to properly route all endpoints.

## 🚀 Run This on Your Ubuntu Server:

### Option 1: Quick Restart
```bash
# Restart just the backend service
docker compose restart backend

# Wait a moment then test
sleep 15
curl http://localhost:8000/api/v1/health
```

### Option 2: Full Rebuild (if restart doesn't work)
```bash
# Stop all services
docker compose down

# Rebuild backend with fixes
docker compose build --no-cache backend

# Start all services
docker compose up -d

# Wait for services to start
sleep 30

# Test endpoints
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/accounts
curl http://localhost:8000/api/v1/campaigns
```

### Option 3: Use the Fix Script
```bash
chmod +x fix_api_routing.sh
./fix_api_routing.sh
```

## 🔍 What Was Fixed

### Before (Broken):
```python
api_router.include_router(health.router, tags=["health"])  # No prefix
api_router.include_router(accounts.router, prefix="/accounts", tags=["accounts"])
```

### After (Working):
```python
api_router.include_router(health.router, prefix="/health", tags=["health"])  # Fixed prefix
api_router.include_router(accounts.router, prefix="/accounts", tags=["accounts"])
api_router.include_router(campaigns.router, prefix="/campaigns", tags=["campaigns"])
api_router.include_router(analytics.router, prefix="", tags=["analytics"])
```

## 📝 Expected Working Endpoints:
- ✅ `GET /api/v1/health` - Health check
- ✅ `GET /api/v1/accounts` - List accounts  
- ✅ `GET /api/v1/campaigns` - List campaigns
- ✅ `GET /api/v1/analytics` - Analytics data
- ✅ `GET /api/v1/system/stats` - System statistics
- ✅ `POST /api/v1/accounts` - Add account
- ✅ `POST /api/v1/campaigns` - Create campaign

## 🔧 Verify Fix Worked:
```bash
# Test all endpoints
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/accounts  
curl http://localhost:8000/api/v1/campaigns
curl http://localhost:8000/api/v1/analytics
curl http://localhost:8000/api/v1/system/stats

# Check backend logs
docker compose logs backend | tail -20
```

## 🎯 If Still Not Working:
1. Check if backend container is running: `docker compose ps`
2. View backend logs: `docker compose logs backend`
3. Try full rebuild: `docker compose down && docker compose build --no-cache && docker compose up -d`

The API routing should now work correctly with all endpoints accessible! 🚀