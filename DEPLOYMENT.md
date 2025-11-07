# Speed-Send Platform - Deployment Guide

## 🚀 One-Click Deployment

This platform includes comprehensive deployment scripts that handle everything automatically.

### For Linux/Mac (Recommended)

**Complete installation on fresh server:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**Other deployment options:**
```bash
# Install dependencies only
./deploy.sh install

# Deploy application only (if dependencies already installed)
./deploy.sh deploy

# Restart application
./deploy.sh restart

# View logs
./deploy.sh logs

# Check status
./deploy.sh status

# Update application
./deploy.sh update

# Clean up Docker resources
./deploy.sh clean
```

### For Windows

**Run the Windows deployment script:**
```cmd
deploy.bat
```

## 📋 Prerequisites

### Automatic Installation (Linux/Mac)
The `deploy.sh` script automatically installs:
- Docker & Docker Compose
- Node.js 18.x
- System dependencies
- Firewall configuration
- Security settings

### Manual Prerequisites (Windows)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- Windows 10/11 with WSL2 enabled

## ⚙️ Configuration

### 1. Environment Variables
The deployment script creates a `.env` file from `.env.template`. **You must configure:**

```bash
# Gmail API Configuration (REQUIRED)
GMAIL_CLIENT_ID=your-gmail-client-id
GMAIL_CLIENT_SECRET=your-gmail-client-secret
GMAIL_REDIRECT_URI=http://localhost:8000/auth/gmail/callback

# Domain Configuration
ALLOWED_DOMAINS=your-domain.com,another-domain.com

# Database (Auto-generated during deployment)
POSTGRES_USER=speedsend
POSTGRES_PASSWORD=auto-generated-password
POSTGRES_DB=speedsend

# Security (Auto-generated during deployment)
JWT_SECRET_KEY=auto-generated-secret
```

### 2. Gmail API Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Gmail API
4. Create credentials (OAuth 2.0 Client ID)
5. Add authorized redirect URIs: `http://your-domain:8000/auth/gmail/callback`
6. Copy Client ID and Secret to `.env` file

### 3. Domain Configuration
- Update DNS to point to your server IP
- Configure SSL certificates for production
- Update `ALLOWED_DOMAINS` in `.env`

## 🌐 Access Points

After deployment, access your platform at:

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Admin Interface**: http://localhost:3000/admin

## 📊 Monitoring & Logs

### View Application Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f celery_worker
docker-compose logs -f frontend
```

### Check Service Status
```bash
# Using deployment script
./deploy.sh status

# Direct Docker commands
docker-compose ps
docker-compose top
```

### Monitor Performance
```bash
# Container resource usage
docker stats

# Database performance
docker-compose exec db psql -U speedsend -d speedsend -c "SELECT * FROM pg_stat_activity;"
```

## 🔧 Maintenance

### Update Application
```bash
# Automatic update
./deploy.sh update

# Manual update
git pull origin main
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Backup Data
```bash
# Database backup
docker-compose exec db pg_dump -U speedsend speedsend > backup_$(date +%Y%m%d).sql

# Full data backup
tar -czf speedsend_backup_$(date +%Y%m%d).tar.gz data/ logs/ .env
```

### Restore Data
```bash
# Restore database
docker-compose exec -T db psql -U speedsend speedsend < backup_20231201.sql

# Restore files
tar -xzf speedsend_backup_20231201.tar.gz
```

## 🛡️ Security

### Production Security Checklist
- [ ] Configure SSL certificates
- [ ] Update default passwords
- [ ] Enable firewall rules
- [ ] Configure backup strategy
- [ ] Set up monitoring alerts
- [ ] Review Gmail API security
- [ ] Enable audit logging

### SSL Setup (Production)
```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 🚨 Troubleshooting

### Common Issues

**1. Docker build fails**
```bash
# Clean Docker cache
./deploy.sh clean
./deploy.sh
```

**2. Permission errors**
```bash
# Fix file permissions
sudo chown -R $USER:$USER .
chmod +x deploy.sh
```

**3. Port conflicts**
```bash
# Check port usage
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :8000

# Stop conflicting services
sudo systemctl stop apache2  # If using Apache
sudo systemctl stop nginx    # If using Nginx
```

**4. Gmail API errors**
- Verify Client ID and Secret in `.env`
- Check redirect URI configuration
- Ensure Gmail API is enabled
- Verify domain authorization

**5. Database connection issues**
```bash
# Check database logs
docker-compose logs db

# Connect to database manually
docker-compose exec db psql -U speedsend speedsend
```

### Getting Help

**View detailed logs:**
```bash
./deploy.sh logs
```

**Check system resources:**
```bash
df -h          # Disk space
free -h        # Memory usage
docker system df  # Docker space usage
```

**Contact Support:**
- Check logs first: `./deploy.sh logs`
- Include error messages
- Specify your OS and Docker version
- Provide `.env` configuration (remove sensitive data)

## 🎯 Performance Tuning

### For High Volume (1M+ emails/day)
```bash
# Edit .env file
CELERY_WORKER_CONCURRENCY=8
POSTGRES_MAX_CONNECTIONS=200
REDIS_MAXMEMORY=2gb

# Restart with new settings
./deploy.sh restart
```

### Database Optimization
```sql
-- Connect to database
docker-compose exec db psql -U speedsend speedsend

-- Add indexes for better performance
CREATE INDEX idx_campaigns_status ON campaigns(status);
CREATE INDEX idx_emails_campaign_id ON emails(campaign_id);
CREATE INDEX idx_emails_status ON emails(status);
```

## 📈 Scaling

### Horizontal Scaling
```bash
# Scale Celery workers
docker-compose up -d --scale celery_worker=4

# Scale across multiple servers
# Deploy on multiple servers and use shared Redis/PostgreSQL
```

---

**🎉 Your Speed-Send platform is ready!** 

Start sending high-volume email campaigns with enterprise-grade reliability and performance.