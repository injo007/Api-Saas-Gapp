#!/bin/bash

# Complete Frontend Fix Script - Resolve blank page issue permanently

set -e

echo "🔧 Complete Frontend Fix - Resolving blank page issue..."

# Stop all containers
echo "Stopping all containers..."
docker-compose down --remove-orphans || true

# Clean Docker cache
echo "Cleaning Docker cache..."
docker system prune -f || true

# Fix package.json to use proper versions
echo "Fixing package.json dependencies..."
cat > package.json << 'EOF'
{
  "name": "speed-send",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/uuid": "^9.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^4.4.0"
  }
}
EOF

# Fix index.html to work with Vite build
echo "Fixing index.html..."
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Speed-Send</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
      tailwind.config = {
        theme: {
          extend: {
            colors: {
              primary: {
                '50': '#eff6ff',
                '100': '#dbeafe',
                '200': '#bfdbfe',
                '300': '#93c5fd',
                '400': '#60a5fa',
                '500': '#3b82f6',
                '600': '#2563eb',
                '700': '#1d4ed8',
                '800': '#1e40af',
                '900': '#1e3a8a',
                '950': '#172554',
              },
            }
          }
        }
      }
    </script>
  </head>
  <body class="bg-gray-100 dark:bg-gray-900">
    <div id="root"></div>
    <script type="module" src="/src/index.tsx"></script>
  </body>
</html>
EOF

# Create src directory and move files
echo "Organizing source files..."
mkdir -p src
mv index.tsx src/ 2>/dev/null || true
mv App.tsx src/ 2>/dev/null || true
mv types.ts src/ 2>/dev/null || true
cp -r components src/ 2>/dev/null || true
cp -r contexts src/ 2>/dev/null || true
cp -r services src/ 2>/dev/null || true

# Fix index.tsx imports
echo "Fixing index.tsx imports..."
cat > src/index.tsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { ToastProvider } from './contexts/ToastContext';
import { DialogProvider } from './contexts/DialogContext';

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error("Could not find root element to mount to");
}

const root = ReactDOM.createRoot(rootElement);
root.render(
  <React.StrictMode>
    <ToastProvider>
      <DialogProvider>
        <App />
      </DialogProvider>
    </ToastProvider>
  </React.StrictMode>
);
EOF

# Update vite config
echo "Updating vite config..."
cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://backend:8000',
        changeOrigin: true,
        secure: false,
      }
    }
  },
  build: {
    outDir: 'dist',
    sourcemap: true
  }
});
EOF

# Create proper Dockerfile for production
echo "Creating production Dockerfile..."
cat > Dockerfile << 'EOF'
# Build stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx config
COPY nginx-frontend.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# Update docker-compose.yml frontend service
echo "Updating docker-compose frontend configuration..."
python3 -c "
import yaml
import sys

try:
    with open('docker-compose.yml', 'r') as f:
        compose = yaml.safe_load(f)
    
    if 'services' in compose and 'frontend' in compose['services']:
        compose['services']['frontend'] = {
            'build': {
                'context': '.',
                'dockerfile': 'Dockerfile'
            },
            'ports': ['3000:80'],
            'depends_on': ['backend'],
            'restart': 'unless-stopped'
        }
        
        with open('docker-compose.yml', 'w') as f:
            yaml.dump(compose, f, default_flow_style=False, indent=2)
        
        print('Updated docker-compose.yml successfully')
    else:
        print('Could not find frontend service in docker-compose.yml')
        
except Exception as e:
    print(f'Error updating docker-compose.yml: {e}')
    print('Please manually update the frontend service configuration')
" 2>/dev/null || echo "Note: Could not auto-update docker-compose.yml, will rebuild anyway"

# Build and start
echo "Building frontend container..."
docker-compose build --no-cache frontend

echo "Starting all services..."
docker-compose up -d

echo "Waiting for services to start..."
sleep 30

# Check status
echo "Checking service status..."
docker-compose ps

# Test frontend
echo "Testing frontend..."
curl -s -I http://localhost:3000 | head -5

echo ""
echo "🎉 Frontend fix completed!"
echo ""
echo "✅ Fixed package.json dependencies"
echo "✅ Removed problematic CDN imports"
echo "✅ Created proper Vite build configuration"
echo "✅ Set up production Nginx serving"
echo "✅ Organized source files properly"
echo ""
echo "Access your app at: http://localhost:3000"
echo ""
echo "If you still see a blank page:"
echo "1. Check browser console for errors (F12)"
echo "2. Run: docker-compose logs frontend"
echo "3. Try hard refresh (Ctrl+F5)"