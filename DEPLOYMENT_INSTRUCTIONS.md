# Speed-Send Deployment Instructions for Ubuntu 22.04

## The Problem (Resolved)
The frontend was showing a blank interface because:
1. Raw TypeScript files were being served instead of compiled JavaScript
2. Node.js version was too old (18) for the Vite plugins (requires 20+)
3. Missing build process in the deployment pipeline

## Solution Implemented
The **deploy.sh** script now includes:
- ✅ Node.js 20 installation (required for Vite)
- ✅ Proper frontend Dockerfile with build process
- ✅ Updated docker-compose.yml configuration
- ✅ Quick frontend fix option

## Quick Fix (For Current Deployment)
If your frontend is already broken, run:
```bash
sudo ./deploy.sh fix-frontend
```

## Full Deployment Commands

### Fresh Installation
```bash
# Make script executable
chmod +x deploy.sh

# Run full deployment (installs everything)
sudo ./deploy.sh
# OR
sudo ./deploy.sh install
```

### Reinstallation (If Already Deployed)
```bash
sudo ./deploy.sh reinstall
```

### Clean Installation (Removes All Data)
```bash
sudo ./deploy.sh clean
```

### Fix Common Issues
```bash
sudo ./deploy.sh fix
```

### Help
```bash
./deploy.sh help
```

## What the Script Does

### 1. System Dependencies
- Updates Ubuntu packages
- Installs Docker and Docker Compose
- Installs Node.js 20 LTS (required for frontend build)
- Installs essential tools

### 2. Frontend Fix
- Creates proper `Dockerfile.frontend` with Node.js 20
- Uses `npm install --legacy-peer-deps` to avoid conflicts
- Updates `docker-compose.yml` to build instead of volume mount
- Creates `.dockerignore` for optimized builds

### 3. Backend Fixes
- Creates production-ready database.py
- Creates production-ready main.py
- Fixes import issues

### 4. Service Management
- Builds all containers with proper dependencies
- Starts services in correct order
- Performs health checks

## Access URLs (After Deployment)
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

## Troubleshooting

### Check Service Status
```bash
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f frontend
docker-compose logs -f backend
```

### Restart Services
```bash
docker-compose restart
```

### Rebuild Frontend Only
```bash
sudo ./deploy.sh fix-frontend
```

## Files Modified/Created by Script
- `Dockerfile.frontend` - Frontend build configuration
- `.dockerignore` - Build optimization
- `docker-compose.yml` - Updated frontend service
- `backend/database.py` - Production database config
- `backend/main.py` - Production API config
- `.env` - Environment configuration (if missing)

## Requirements
- Ubuntu 20.04+ (tested on 22.04)
- Root privileges or sudo access
- Internet connection
- At least 4GB RAM recommended

## Script Features
- ✅ Automatic dependency installation
- ✅ Node.js 20 LTS installation
- ✅ Frontend build process fix
- ✅ Backend optimization
- ✅ Health checks and diagnostics
- ✅ Multiple deployment modes
- ✅ Error handling and logging

The script is now self-contained and handles all installation and fixes in one file.