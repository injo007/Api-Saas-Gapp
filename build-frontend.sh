#!/bin/bash

# Build frontend for production
echo "Building frontend for production..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "npm is not installed. Please install npm first."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build the project
echo "Building the project..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Frontend build completed successfully!"
    echo "Built files are in the 'dist' directory"
    ls -la dist/ 2>/dev/null || echo "dist directory not found"
else
    echo "❌ Frontend build failed!"
    exit 1
fi