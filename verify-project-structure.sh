#!/bin/bash

echo "🔍 Verifying Speed-Send project structure..."

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo "✅ $1"
    else
        echo "❌ $1 - MISSING!"
        MISSING_FILES=true
    fi
}

# Function to check if directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo "✅ $1/"
    else
        echo "❌ $1/ - MISSING!"
        MISSING_DIRS=true
    fi
}

MISSING_FILES=false
MISSING_DIRS=false

echo ""
echo "📁 Checking project structure..."

# Root files
check_file "deploy.sh"
check_file "docker-compose.yml"
check_file ".env.template"
check_file "package.json"
check_file "tsconfig.json"
check_file "vite.config.ts"
check_file "index.html"
check_file "index.tsx"
check_file "App.tsx"
check_file "types.ts"
check_file "nginx.conf"

# Backend directory and files
check_dir "backend"
check_file "backend/pyproject.toml"
check_file "backend/Dockerfile"
check_file "backend/main.py"
check_file "backend/models.py"
check_file "backend/schemas.py"
check_file "backend/crud.py"
check_file "backend/database.py"
check_file "backend/tasks.py"

# Backend subdirectories
check_dir "backend/core"
check_file "backend/core/config.py"
check_dir "backend/utils"
check_file "backend/utils/encryption.py"
check_file "backend/utils/gmail_service.py"
check_file "backend/utils/campaign_optimizer.py"
check_file "backend/utils/ultra_fast_sender.py"

# API directories
check_dir "backend/api"
check_dir "backend/api/v1"
check_file "backend/api/v1/api.py"
check_dir "backend/api/v1/endpoints"
check_file "backend/api/v1/endpoints/health.py"
check_file "backend/api/v1/endpoints/accounts.py"
check_file "backend/api/v1/endpoints/campaigns.py"

# Alembic
check_dir "backend/alembic"
check_file "backend/alembic.ini"
check_file "backend/alembic/env.py"
check_dir "backend/alembic/versions"

# Frontend components
check_dir "components"
check_dir "components/ui"
check_dir "components/views"
check_dir "components/layout"
check_dir "components/icons"
check_dir "services"
check_file "services/api.ts"
check_dir "contexts"

echo ""
if [ "$MISSING_FILES" = true ] || [ "$MISSING_DIRS" = true ]; then
    echo "❌ Missing files/directories found!"
    echo ""
    echo "🔧 To fix missing files, run:"
    echo "   git pull  # if using git"
    echo "   # or re-download the complete project"
    echo ""
else
    echo "✅ All required files and directories are present!"
    echo ""
fi

echo "📋 Current directory contents:"
ls -la

echo ""
echo "🔍 Backend directory contents:"
ls -la backend/ 2>/dev/null || echo "❌ backend/ directory not found!"

echo ""
echo "📄 Docker Compose validation:"
if command -v docker-compose &> /dev/null; then
    docker-compose config --quiet && echo "✅ docker-compose.yml is valid" || echo "❌ docker-compose.yml has errors"
else
    echo "⚠️ docker-compose not installed"
fi