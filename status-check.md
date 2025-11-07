# Speed-Send Status Check Guide

## Quick Status Commands (Run on your CentOS server):

### 1. Check Container Status
```bash
docker ps
```
**Expected:** You should see containers like:
- speedsend_frontend
- speedsend_backend  
- speedsend_db
- speedsend_redis
- speedsend_celery_worker

### 2. Test Frontend Access
```bash
curl -I http://localhost:3000
```
**Expected:** HTTP/1.1 200 OK

### 3. Test Backend API
```bash
curl http://localhost:8000/health
```
**Expected:** {"status": "healthy"}

### 4. Check Service Logs
```bash
# Frontend logs
docker logs speedsend_frontend

# Backend logs  
docker logs speedsend_backend
```

### 5. Test in Browser
Open: `http://YOUR_SERVER_IP:3000`

## If You See Issues:

### Blank Page Fix:
```bash
# Run the immediate fix we created
./immediate-fix.sh
```

### Backend Errors:
```bash  
# Run the backend dependency fix
./quick-fix.sh
```

### Complete Reset:
```bash
# Run the complete deployment fix
./deploy-final.sh
```

## Expected Working State:

✅ **Frontend (port 3000):** Speed-Send interface with dashboard  
✅ **Backend (port 8000):** API responding with health status  
✅ **API Docs (port 8000/docs):** Swagger documentation  
✅ **Database:** PostgreSQL ready for campaign data  
✅ **Redis:** Task queue ready for email processing  

## Troubleshooting:

**If frontend shows blank page:**
- Check browser console for JavaScript errors (F12)
- Verify containers are running: `docker ps`
- Run: `./immediate-fix.sh`

**If backend fails:**
- Check for email-validator error in logs
- Run: `./quick-fix.sh`

**If services won't start:**
- Check Docker resources: `docker system df`
- Clean and rebuild: `./deploy-final.sh clean && ./deploy-final.sh`