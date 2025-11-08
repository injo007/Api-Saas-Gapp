# 🚀 Speed-Send Emergency Deployment Guide

## Issues Identified & Solutions

### 🔍 **Main Problems**
1. **Missing Environment Configuration** - No `.env` file
2. **Database Connection Issues** - PostgreSQL not properly configured
3. **Account Management Failures** - CRUD operations lack error handling
4. **Frontend API Communication** - Network errors not handled properly
5. **Docker/Container Issues** - Services not running properly

---

## 🛠️ **Immediate Fixes Applied**

### 1. Environment Configuration ✅
- Created `.env` file with production-ready settings
- Generated secure encryption keys
- Configured database connection strings

### 2. Backend Fixes ✅
- Enhanced CRUD operations with proper error handling
- Fixed account deletion with cascade handling
- Improved database connection management
- Added transaction rollback on errors

### 3. Frontend Fixes ✅
- Updated API service with comprehensive error handling
- Enhanced AccountsView component with better UX
- Added proper loading states and error messages
- Improved network error detection

---

## 📋 **Deployment Instructions for Ubuntu Server 22**

### Step 1: Prepare Environment
```bash
# Make sure you're in the project directory
cd /path/to/your/speed-send-project

# Make scripts executable
chmod +x tmp_rovodev_ubuntu_fix.sh
chmod +x deploy.sh

# Run the emergency fix
./tmp_rovodev_ubuntu_fix.sh
```

### Step 2: Verify Services
```bash
# Check if all services are running
sudo docker-compose ps

# Expected output should show:
# - speedsend_db (running, healthy)
# - speedsend_redis (running, healthy)  
# - speedsend_backend (running)
# - speedsend_frontend (running)
# - speedsend_celery_worker (running)
# - speedsend_celery_beat (running)
```

### Step 3: Test the Application
```bash
# Test API health
python3 tmp_rovodev_test_api.py

# Check logs if there are issues
sudo docker-compose logs backend
sudo docker-compose logs frontend
```

### Step 4: Access the Application
- **Frontend**: http://your-server-ip:3000
- **Backend API**: http://your-server-ip:8000/docs
- **Health Check**: http://your-server-ip:8000/api/v1/health

---

## 🔧 **Manual Troubleshooting**

### If Docker is not installed:
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes
```

### If Database Connection Fails:
```bash
# Reset everything and rebuild
sudo docker-compose down -v
sudo docker-compose up --build -d

# Wait for services to start
sleep 60

# Run migrations
sudo docker-compose exec backend alembic upgrade head
```

### If Frontend Can't Connect to Backend:
```bash
# Check if backend is accessible
curl http://localhost:8000/api/v1/health

# If not working, check backend logs
sudo docker-compose logs backend

# Restart services
sudo docker-compose restart backend frontend
```

---

## 📊 **Testing Account Operations**

### Test Account Creation:
1. Open frontend at http://your-server-ip:3000
2. Navigate to "Accounts" page
3. Click "Add Account"
4. Fill in details and upload service account JSON
5. Check for success message

### Test Account Deletion:
1. Find an existing account
2. Click the trash icon
3. Confirm deletion
4. Verify account is removed from list

### Test User Retrieval:
1. Click "Users" button on any account
2. Should show list of Google Workspace users
3. If empty, click "Sync" button

---

## 🐛 **Common Error Solutions**

### "Failed to load accounts"
- **Cause**: Backend not running or database connection failed
- **Fix**: Check `sudo docker-compose ps` and restart services

### "Network error: Unable to connect to server"
- **Cause**: Frontend can't reach backend
- **Fix**: Ensure backend is running on port 8000

### "Invalid credentials" when adding accounts
- **Cause**: Service account JSON is invalid or lacks permissions
- **Fix**: Verify Google Workspace domain-wide delegation setup

### Database connection errors
- **Cause**: PostgreSQL not ready or wrong credentials
- **Fix**: Check `.env` file and restart database service

---

## 🔍 **Monitoring & Logs**

### Real-time Logs:
```bash
# Follow all logs
sudo docker-compose logs -f

# Specific service logs
sudo docker-compose logs -f backend
sudo docker-compose logs -f frontend
sudo docker-compose logs -f db
```

### Health Checks:
```bash
# API health
curl http://localhost:8000/api/v1/health

# Database health
sudo docker-compose exec db pg_isready -U speedsend_user -d speedsend_db

# Redis health
sudo docker-compose exec redis redis-cli ping
```

---

## 🚨 **Emergency Recovery**

If everything fails:

```bash
# Complete reset
sudo docker-compose down -v
sudo docker system prune -af

# Remove all containers and images
sudo docker container prune -f
sudo docker image prune -af

# Restart from scratch
sudo docker-compose up --build -d

# Wait and test
sleep 120
python3 tmp_rovodev_test_api.py
```

---

## ✅ **Success Indicators**

Your application is working correctly when:

1. **All Docker containers are running** ✅
2. **API health check returns 200** ✅
3. **Frontend loads without errors** ✅
4. **Can create accounts successfully** ✅
5. **Can retrieve and display users** ✅
6. **Can delete accounts without errors** ✅
7. **No JavaScript errors in browser console** ✅

## 📞 **Next Steps**

Once basic functionality is working:

1. **Set up SSL/HTTPS** for production
2. **Configure firewall** to restrict access
3. **Set up backups** for database
4. **Monitor logs** for errors
5. **Test email sending functionality**

---

*This guide addresses the critical issues preventing account management operations. Follow the steps in order for best results.*