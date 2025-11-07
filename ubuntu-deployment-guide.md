# Speed-Send Ubuntu 22.04 Deployment Guide

## Prerequisites Installation

### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Docker
```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install dependencies
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### 3. Install Docker Compose (if not installed with Docker)
```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 4. Verify Installation
```bash
docker --version
docker-compose --version
```

## Manual Deployment Steps

### 1. Clone/Upload the Speed-Send Project
```bash
# If using git
git clone <your-repo-url> speed-send
cd speed-send

# OR upload the files manually to a directory called speed-send
```

### 2. Create Environment File
```bash
cp .env.template .env
```

### 3. Generate Security Keys
```bash
# Generate SECRET_KEY
export SECRET_KEY=$(openssl rand -hex 32)
sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" .env

# Generate ENCRYPTION_KEY
export ENCRYPTION_KEY=$(openssl rand -base64 32)
sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
```

### 4. Update Database Password
```bash
# Generate a secure password
export DB_PASSWORD=$(openssl rand -base64 32)

# Update .env file
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASSWORD/" .env
sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://speedsend_user:$DB_PASSWORD@db:5432/speedsend_db|" .env
```

### 5. Create Required Directories
```bash
mkdir -p uploads
chmod 755 uploads
```

### 6. Start Database and Redis First
```bash
docker-compose up -d db redis
```

### 7. Wait for Database to be Ready
```bash
# Wait for PostgreSQL to be ready
while ! docker-compose exec -T db pg_isready -U speedsend_user -d speedsend_db; do
    echo "Waiting for PostgreSQL..."
    sleep 2
done
```

### 8. Build and Start Backend
```bash
docker-compose build backend
docker-compose up -d backend
```

### 9. Run Database Migrations
```bash
# Wait for backend to be ready
sleep 10

# Run migrations
docker-compose exec -T backend poetry run alembic upgrade head
```

### 10. Start Celery Workers
```bash
docker-compose up -d celery_worker celery_beat
```

### 11. Build and Start Frontend
```bash
docker-compose build frontend
docker-compose up -d frontend
```

## Troubleshooting Common Issues

### Issue 1: Permission Denied on deploy.sh
```bash
chmod +x deploy.sh
```

### Issue 2: Docker Permission Denied
```bash
sudo usermod -aG docker $USER
newgrp docker
# OR run with sudo
sudo docker-compose up -d
```

### Issue 3: Port Already in Use
```bash
# Check what's using the ports
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :8000

# Kill processes if needed
sudo fuser -k 3000/tcp
sudo fuser -k 8000/tcp
```

### Issue 4: Database Connection Issues
```bash
# Check database logs
docker-compose logs db

# Reset database
docker-compose down
docker volume rm speed-send_postgres_data
docker-compose up -d db
```

### Issue 5: Backend Build Issues
```bash
# Clean build
docker-compose down
docker system prune -a
docker-compose build --no-cache backend
```

## Verification Steps

### 1. Check All Services
```bash
docker-compose ps
```

### 2. Check Service Logs
```bash
docker-compose logs backend
docker-compose logs frontend
docker-compose logs celery_worker
```

### 3. Test API Health
```bash
curl http://localhost:8000/api/v1/health
```

### 4. Test Frontend
```bash
curl http://localhost:3000
```

## Environment Configuration

### Required Environment Variables
Make sure your `.env` file has these configured:

```env
# Database
POSTGRES_USER=speedsend_user
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=speedsend_db
DATABASE_URL=postgresql://speedsend_user:your_secure_password_here@db:5432/speedsend_db

# Redis
REDIS_URL=redis://redis:6379/0

# Security
SECRET_KEY=your_generated_secret_key
ENCRYPTION_KEY=your_generated_encryption_key

# Gmail API
GMAIL_RATE_LIMIT_PER_HOUR=1800

# Celery
CELERY_WORKER_CONCURRENCY=50
CELERY_TASK_TIMEOUT=300

# Application
DEBUG=false
ENVIRONMENT=production
```

## Final Access URLs

- **Frontend (Web UI)**: http://your-server-ip:3000
- **Backend API Docs**: http://your-server-ip:8000/docs
- **Backend API ReDoc**: http://your-server-ip:8000/redoc

## Security Notes for Production

1. **Firewall**: Configure UFW or iptables
2. **SSL**: Use nginx with SSL certificates
3. **Domain**: Configure proper domain names
4. **Backup**: Set up regular database backups
5. **Monitoring**: Implement logging and monitoring