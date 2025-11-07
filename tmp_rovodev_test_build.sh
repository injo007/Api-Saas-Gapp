#!/bin/bash

# Quick test to verify the uuid dependency fix
echo "Testing frontend build with uuid dependency fix..."

# Install dependencies
echo "Installing dependencies..."
npm install

# Try to build
echo "Running build..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Build successful! UUID dependency issue is fixed."
else
    echo "❌ Build failed. Please check the error messages above."
fi