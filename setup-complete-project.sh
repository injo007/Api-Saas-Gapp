#!/bin/bash

echo "🚀 Setting up complete Speed-Send project structure..."

# Create all required directories
echo "📁 Creating directory structure..."
mkdir -p backend/{core,utils,api/v1/endpoints,alembic/versions}
mkdir -p components/{ui,views,layout,icons}
mkdir -p services
mkdir -p contexts
mkdir -p uploads

# Check if main files exist, if not, show what's missing
echo ""
echo "🔍 Checking required files..."

REQUIRED_FILES=(
    "docker-compose.yml"
    "deploy.sh" 
    ".env.template"
    "backend/pyproject.toml"
    "backend/Dockerfile"
    "backend/main.py"
    "package.json"
    "App.tsx"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
        echo "❌ Missing: $file"
    else
        echo "✅ Found: $file"
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo ""
    echo "❌ Missing ${#MISSING_FILES[@]} required files!"
    echo ""
    echo "📋 Missing files:"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    echo ""
    echo "💡 Solution: Make sure you have downloaded the complete project"
    echo "   All files should be in the same directory as this script"
    echo ""
    echo "🔧 Quick fix commands:"
    echo "   # If using git:"
    echo "   git pull"
    echo ""
    echo "   # Or re-download the complete project files"
    echo ""
    exit 1
else
    echo ""
    echo "✅ All required files found!"
fi

# Fix file permissions
echo "🔧 Setting correct permissions..."
chmod +x deploy.sh 2>/dev/null || echo "⚠️ deploy.sh not found"
chmod +x verify-project-structure.sh 2>/dev/null || echo "⚠️ verify-project-structure.sh not found"
chmod 755 uploads

# Verify Docker setup
echo ""
echo "🐳 Checking Docker setup..."
if command -v docker &> /dev/null; then
    echo "✅ Docker is installed: $(docker --version)"
else
    echo "❌ Docker not installed!"
    echo "Run: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
    exit 1
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo "✅ Docker Compose is available"
else
    echo "❌ Docker Compose not available!"
    exit 1
fi

# Test docker-compose file
echo ""
echo "📋 Validating docker-compose.yml..."
if docker-compose config --quiet 2>/dev/null; then
    echo "✅ docker-compose.yml is valid"
else
    echo "❌ docker-compose.yml has errors"
    docker-compose config
    exit 1
fi

# Check if .env exists, create if not
if [ ! -f .env ]; then
    if [ -f .env.template ]; then
        echo "📝 Creating .env from template..."
        cp .env.template .env
        echo "✅ .env created"
    else
        echo "❌ .env.template not found!"
        exit 1
    fi
else
    echo "✅ .env file exists"
fi

echo ""
echo "🎉 Project structure setup complete!"
echo ""
echo "🚀 Ready to deploy! Run:"
echo "   ./deploy.sh"
echo ""
echo "🔍 Current directory structure:"
find . -type d -name ".*" -prune -o -type d -print | head -20