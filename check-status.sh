#!/bin/bash

# Status Check Script - Verify all services are working

echo "🔍 Checking Speed-Send Platform Status..."
echo "========================================"

# Check if containers are running
echo "📦 Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep speedsend || echo "No speedsend containers found"

echo ""
echo "🌐 Service Connectivity Tests:"

# Test backend
echo -n "Backend (port 8000): "
if curl -s --connect-timeout 5 http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ WORKING"
else
    echo "❌ NOT RESPONDING"
fi

# Test frontend
echo -n "Frontend (port 3000): "
if curl -s --connect-timeout 5 http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ WORKING"
    
    # Check if it's actually serving content
    CONTENT=$(curl -s http://localhost:3000 | head -c 100)
    if [[ $CONTENT == *"Speed-Send"* ]] || [[ $CONTENT == *"html"* ]]; then
        echo "   └─ Content: ✅ HTML/React content detected"
    else
        echo "   └─ Content: ⚠️  Unexpected content format"
    fi
else
    echo "❌ NOT RESPONDING"
fi

# Test API docs
echo -n "API Docs (port 8000/docs): "
if curl -s --connect-timeout 5 http://localhost:8000/docs > /dev/null 2>&1; then
    echo "✅ WORKING"
else
    echo "❌ NOT RESPONDING"
fi

echo ""
echo "📋 Recent Container Logs:"
echo "Backend logs (last 5 lines):"
docker logs speedsend_backend --tail 5 2>/dev/null || echo "Cannot access backend logs"

echo ""
echo "Frontend logs (last 5 lines):"
docker logs speedsend_frontend --tail 5 2>/dev/null || echo "Cannot access frontend logs"

echo ""
echo "🎯 Quick Access URLs:"
echo "Frontend: http://localhost:3000"
echo "Backend API: http://localhost:8000"
echo "API Docs: http://localhost:8000/docs"

echo ""
echo "🔧 Troubleshooting Commands:"
echo "View all logs: docker-compose logs -f"
echo "Restart services: docker-compose restart"
echo "Check detailed status: docker-compose ps"

# Test if we can access the actual app
echo ""
echo "🧪 Frontend Content Test:"
RESPONSE=$(curl -s http://localhost:3000 2>/dev/null)
if [[ -n "$RESPONSE" ]]; then
    if [[ $RESPONSE == *"Speed-Send"* ]]; then
        echo "✅ Speed-Send app content detected!"
    elif [[ $RESPONSE == *"<html"* ]]; then
        echo "✅ HTML content detected - app should be visible"
    elif [[ $RESPONSE == *"Cannot GET"* ]]; then
        echo "❌ 404 Error - frontend not properly configured"
    else
        echo "⚠️  Unknown content type - check manually"
    fi
else
    echo "❌ No response from frontend"
fi

echo ""
echo "Status check completed!"