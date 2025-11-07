# Quick Fix Commands for Ubuntu Server

Run these commands on your Ubuntu server to fix the frontend build:

## Step 1: Stop and clean frontend
```bash
cd ~/Api-Saas-Gapp
docker-compose stop frontend
docker-compose rm -f frontend
docker rmi $(docker images | grep frontend | awk '{print $3}') 2>/dev/null || true
```

## Step 2: Create simple Dockerfile.frontend
```bash
cat > Dockerfile.frontend << 'EOF'
# Simple Frontend Dockerfile
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package.json ./
COPY tsconfig.json ./
COPY vite.config.ts ./

# Install dependencies
RUN npm install --force

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
```

## Step 3: Rebuild and start
```bash
docker-compose build --no-cache frontend
docker-compose up -d frontend
```

## Step 4: Check status
```bash
docker-compose ps
docker-compose logs frontend
```

## Alternative: Skip frontend for now
If frontend still fails, you can access the backend API directly:

```bash
# Start only backend services
docker-compose up -d backend db redis celery_worker celery_beat
```

Then access:
- Backend API: http://your-server-ip:8000
- API Docs: http://your-server-ip:8000/docs

## If all else fails - Manual build
```bash
# Install dependencies locally
npm install --force

# Build locally  
npm run build

# Copy to nginx
sudo cp -r dist/* /var/www/html/
```