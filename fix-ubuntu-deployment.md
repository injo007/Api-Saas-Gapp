# Ubuntu Deployment Fix

## Issues Fixed:

1. ✅ **Docker build context**: Fixed Dockerfile to copy from correct paths
2. ✅ **Poetry commands**: Removed `poetry run` from all services  
3. ✅ **Build context**: Already set correctly in docker-compose.yml

## Commands to run on Ubuntu server:

```bash
# Stop current deployment
docker-compose down

# Clear Docker cache to ensure fresh build
docker system prune -af

# Force rebuild with no cache
docker-compose build --no-cache

# Start deployment
./deploy.sh --reinstall
```

## What was wrong:

- Dockerfile was trying to copy `pyproject.toml` from wrong path
- Docker-compose still had `poetry run` commands
- Build context was correct but cached layers had old commands

## Fixed files:
- ✅ backend/Dockerfile - Fixed COPY paths
- ✅ docker-compose.yml - Removed `poetry run` from commands

The deployment should now work correctly on Ubuntu!