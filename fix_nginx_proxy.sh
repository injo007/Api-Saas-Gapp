#!/bin/bash

echo "🔧 Fixing Nginx Proxy Configuration for API Calls"
echo "================================================"

# Create proper nginx.conf that fixes the 307 redirect issue
cat > nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    # Serve static files
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    # Proxy ALL /api requests to backend (prevents 307 redirects)
    location /api {
        proxy_pass http://backend:8000/api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers
        proxy_set_header Access-Control-Allow-Origin *;
        proxy_set_header Access-Control-Allow-Methods 'GET, POST, OPTIONS, PUT, DELETE';
        proxy_set_header Access-Control-Allow-Headers 'Origin, Content-Type, Accept, Authorization';
    }

    # Direct health check
    location /health {
        proxy_pass http://backend:8000/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

echo "✅ Created proper nginx.conf"

# Stop and rebuild frontend with correct nginx config
echo "Stopping frontend..."
docker compose stop frontend

echo "Removing frontend container and image..."
docker compose rm -f frontend
docker rmi $(docker images -q "*frontend*") 2>/dev/null || true

echo "Rebuilding frontend with correct nginx config..."
docker compose build --no-cache frontend

echo "Starting frontend..."
docker compose up -d frontend

echo "Waiting for frontend to start..."
sleep 15

# Test the endpoints
echo ""
echo "🧪 Testing API endpoints..."
echo "=========================="

echo -n "Direct backend health: "
curl -s http://localhost:8000/health >/dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "Frontend proxy health: "
curl -s http://localhost:3000/health >/dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "Frontend proxy API health: "
curl -s http://localhost:3000/api/v1/health >/dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "Frontend proxy accounts: "
curl -s http://localhost:3000/api/v1/accounts >/dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "Frontend proxy campaigns: "
curl -s http://localhost:3000/api/v1/campaigns >/dev/null && echo "✅ OK" || echo "❌ FAIL"

echo ""
echo "🔗 Test URLs:"
echo "Frontend: http://localhost:3000"
echo "Direct API: http://localhost:8000/api/v1/health"
echo "Proxied API: http://localhost:3000/api/v1/health"

echo ""
echo "✅ Nginx proxy fix completed!"
echo "The 307 redirect issue should be resolved."