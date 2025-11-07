# SpeedSend Troubleshooting Guide

## 🔧 Common Issues & Solutions

### 1. Frontend Shows "Failed to load" Errors

**Symptoms**: Infinite "Failed to load campaigns/accounts" popups

**Solutions**:
```bash
# Check if backend is running
curl http://localhost:8000/health

# If backend is down, restart it
docker compose restart backend

# Check backend logs
docker compose logs backend

# If API routing issues, rebuild frontend
docker compose stop frontend
docker compose rm -f frontend
docker compose build --no-cache frontend
docker compose up -d frontend
```

### 2. Blank Interface When Adding Accounts

**Symptoms**: Interface goes blank after clicking "Add Account"

**Solutions**:
```bash
# Check frontend logs for JavaScript errors
docker compose logs frontend

# Rebuild frontend with latest fixes
docker compose build --no-cache frontend
docker compose up -d frontend

# Verify JSON file format
# Ensure uploaded file is valid JSON
```

### 3. Docker Build Failures

**Symptoms**: Build errors during container creation

**Solutions**:
```bash
# Clean Docker system
docker system prune -f
docker volume prune -f

# Remove old images
docker rmi $(docker images -q "*speedsend*" 2>/dev/null) || true

# Rebuild with no cache
docker compose build --no-cache

# Check disk space
df -h
```

### 4. Database Connection Issues

**Symptoms**: Backend can't connect to PostgreSQL

**Solutions**:
```bash
# Check if database is running
docker compose ps db

# Restart database
docker compose restart db

# Check database logs
docker compose logs db

# Reset database if corrupted
docker compose down
docker volume rm speedsend_postgres_data
docker compose up -d
```

### 5. Gmail API Authentication Failures

**Symptoms**: "Invalid credentials" errors

**Solutions**:
1. **Verify Service Account JSON**:
   - Ensure JSON file is properly formatted
   - Check that all required fields are present
   - Verify the file isn't corrupted

2. **Check Google Cloud Configuration**:
   - Gmail API is enabled in Google Cloud Console
   - Service account has proper permissions
   - Domain-wide delegation is configured

3. **Test Connection**:
   - Use Test Center → Connection Test
   - Check account admin email matches delegation

### 6. Email Sending Failures

**Symptoms**: Campaigns fail to send emails

**Solutions**:
```bash
# Check Celery workers
docker compose ps celery_worker

# Restart workers
docker compose restart celery_worker celery_beat

# Check worker logs
docker compose logs celery_worker

# Verify Redis connection
docker compose logs redis
```

### 7. Performance Issues

**Symptoms**: Slow loading, timeouts

**Solutions**:
```bash
# Check container resources
docker stats

# Monitor database performance
docker compose exec db psql -U speedsend_user -d speedsend_db -c "SELECT * FROM pg_stat_activity;"

# Increase container limits if needed
# Edit docker-compose.yml to add resource limits
```

### 8. New Views Not Showing

**Symptoms**: Data Management, Analytics, or Test Center not visible

**Solutions**:
```bash
# Clear browser cache
# Hard refresh (Ctrl+F5 or Cmd+Shift+R)

# Rebuild frontend completely
docker compose stop frontend
docker compose rm -f frontend
docker rmi $(docker images -q "*frontend*")
docker compose build --no-cache frontend
docker compose up -d frontend
```

## 🔍 Diagnostic Commands

### Check All Services
```bash
# Service status
docker compose ps

# Service health
curl http://localhost:8000/health
curl http://localhost:3000

# All logs
docker compose logs
```

### Database Diagnostics
```bash
# Connect to database
docker compose exec db psql -U speedsend_user -d speedsend_db

# Check tables
\dt

# Check data counts
SELECT 'accounts' as table_name, COUNT(*) FROM accounts
UNION
SELECT 'campaigns' as table_name, COUNT(*) FROM campaigns
UNION
SELECT 'recipients' as table_name, COUNT(*) FROM recipients;
```

### API Testing
```bash
# Test endpoints
curl http://localhost:8000/api/v1/accounts
curl http://localhost:8000/api/v1/campaigns
curl http://localhost:8000/api/v1/analytics
curl http://localhost:8000/api/v1/system/stats
```

## 🚨 Emergency Recovery

### Complete Reset
```bash
# Stop everything
docker compose down --volumes

# Remove all data
docker volume prune -f
docker system prune -f

# Rebuild and start
docker compose build --no-cache
docker compose up -d

# Wait for services to stabilize
sleep 60

# Verify everything is working
curl http://localhost:8000/health
curl http://localhost:3000
```

### Backup & Restore
```bash
# Backup database
docker compose exec db pg_dump -U speedsend_user speedsend_db > backup.sql

# Restore database
docker compose exec -T db psql -U speedsend_user speedsend_db < backup.sql
```

## 📝 Log Analysis

### Important Log Patterns
- **Frontend**: JavaScript errors, API call failures
- **Backend**: Database connection errors, API endpoint errors
- **Database**: Connection issues, query performance
- **Workers**: Email sending failures, task queue issues

### Log Commands
```bash
# Follow logs in real-time
docker compose logs -f frontend
docker compose logs -f backend
docker compose logs -f celery_worker

# Search for errors
docker compose logs backend 2>&1 | grep -i error
docker compose logs frontend 2>&1 | grep -i error
```

## 🔧 Performance Optimization

### If System is Slow
1. **Check Resources**:
   ```bash
   docker stats
   free -h
   df -h
   ```

2. **Optimize Database**:
   ```sql
   VACUUM ANALYZE;
   REINDEX DATABASE speedsend_db;
   ```

3. **Clear Browser Cache**: Hard refresh browser

4. **Restart Services**:
   ```bash
   docker compose restart
   ```

## 📞 Getting Help

### Before Asking for Help
1. Check this troubleshooting guide
2. Check service logs: `docker compose logs [service]`
3. Verify all services are running: `docker compose ps`
4. Test API endpoints manually with curl
5. Try the emergency recovery steps

### Useful Information to Provide
- Output of `docker compose ps`
- Relevant log snippets
- Steps to reproduce the issue
- Browser console errors (F12 → Console)
- System specifications (RAM, CPU, disk space)

---

**Most issues can be resolved by rebuilding the frontend container or restarting services!** 🚀