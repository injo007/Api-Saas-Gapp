#!/bin/bash
# Emergency deployment fix for Ubuntu Server 22

echo "🔧 Starting emergency fix for Speed-Send application..."

# Stop existing services
echo "Stopping existing services..."
sudo docker-compose down 2>/dev/null || true

# Create uploads directory
mkdir -p uploads
chmod 755 uploads

# Fix permissions
sudo chown -R $USER:$USER .
chmod +x deploy.sh

# Install/update Docker if needed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Clean up any existing containers
echo "Cleaning up existing containers..."
sudo docker system prune -f

# Build and start services
echo "Building and starting services..."
sudo docker-compose up --build -d

# Wait for database
echo "Waiting for database to be ready..."
sleep 30

# Run database migrations
echo "Running database migrations..."
sudo docker-compose exec backend alembic upgrade head

echo "✅ Fix completed! Check status with: sudo docker-compose ps"
