#!/bin/bash

# Quick fix for frontend build issues
echo "Stopping frontend container..."
docker-compose stop frontend || true

echo "Removing frontend container and images..."
docker-compose rm -f frontend || true
docker rmi $(docker images | grep frontend | awk '{print $3}') 2>/dev/null || true

echo "Creating simplified package.json with stable versions..."
cat > package.json << 'EOF'
{
  "name": "speed-send",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^4.4.0"
  }
}
EOF

echo "Rebuilding frontend with new configuration..."
docker-compose build --no-cache frontend

echo "Starting frontend..."
docker-compose up -d frontend

echo "Checking status..."
sleep 5
docker-compose ps frontend