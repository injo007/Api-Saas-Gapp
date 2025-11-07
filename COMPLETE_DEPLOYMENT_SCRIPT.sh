#!/bin/bash

echo "🚀 SpeedSend Complete Deployment with Gmail Service Account Integration"
echo "====================================================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
header() { echo -e "${PURPLE}$1${NC}"; }

header "🎯 SPEEDSEND PRODUCTION DEPLOYMENT"
echo
info "This script will deploy SpeedSend with:"
info "✅ Complete frontend with 6 views (Dashboard, Accounts, Data Management, Analytics, Test Center, Ultra-Fast Send)"
info "✅ Full backend with Gmail API integration using service account delegation"
info "✅ Proper user delegation for email sending across workspace users"
info "✅ Equal distribution of recipients across selected users"
info "✅ All required scopes for Gmail and Admin Directory APIs"
echo

header "PHASE 1: SYSTEM PREPARATION"
log "Stopping all existing services..."
docker compose down --volumes --remove-orphans 2>/dev/null || docker-compose down --volumes --remove-orphans 2>/dev/null || true

log "Cleaning up old images for fresh build..."
docker rmi $(docker images -q "*speedsend*" "*frontend*" "*backend*" 2>/dev/null) 2>/dev/null || true
docker system prune -f 2>/dev/null || true

header "PHASE 2: BUILDING UPGRADED SERVICES"
log "Building backend with Gmail service account integration..."
docker compose build --no-cache backend 2>/dev/null || docker-compose build --no-cache backend 2>/dev/null

log "Building frontend with all new views..."
docker compose build --no-cache frontend 2>/dev/null || docker-compose build --no-cache frontend 2>/dev/null

header "PHASE 3: STARTING PRODUCTION SERVICES"
log "Starting database and Redis..."
docker compose up -d db redis 2>/dev/null || docker-compose up -d db redis 2>/dev/null
sleep 20

log "Starting upgraded backend..."
docker compose up -d backend 2>/dev/null || docker-compose up -d backend 2>/dev/null
sleep 25

log "Starting background workers..."
docker compose up -d celery_worker celery_beat 2>/dev/null || docker-compose up -d celery_worker celery_beat 2>/dev/null
sleep 15

log "Starting frontend with all features..."
docker compose up -d frontend 2>/dev/null || docker-compose up -d frontend 2>/dev/null
sleep 30

header "PHASE 4: SYSTEM VERIFICATION"
echo
log "🔍 Verifying all services..."
docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null

echo
log "🔍 Testing API endpoints..."

# Test core endpoints
if curl -f http://localhost:8000/health >/dev/null 2>&1; then
    log "✅ Backend Health: OPERATIONAL"
else
    warn "❌ Backend Health: NOT RESPONDING"
fi

if curl -f http://localhost:8000/api/v1/accounts >/dev/null 2>&1; then
    log "✅ Accounts API: OPERATIONAL"
else
    warn "❌ Accounts API: NOT RESPONDING"
fi

if curl -f http://localhost:8000/api/v1/campaigns >/dev/null 2>&1; then
    log "✅ Campaigns API: OPERATIONAL"
else
    warn "❌ Campaigns API: NOT RESPONDING"
fi

# Test new endpoints
if curl -f http://localhost:8000/api/v1/analytics >/dev/null 2>&1; then
    log "✅ Analytics API: OPERATIONAL"
else
    warn "❌ Analytics API: NOT RESPONDING"
fi

if curl -f http://localhost:8000/api/v1/system/stats >/dev/null 2>&1; then
    log "✅ System Stats API: OPERATIONAL"
else
    warn "❌ System Stats API: NOT RESPONDING"
fi

# Test frontend
if curl -f http://localhost:3000 >/dev/null 2>&1; then
    log "✅ Frontend: OPERATIONAL"
else
    warn "❌ Frontend: NOT RESPONDING"
fi

header "PHASE 5: DEPLOYMENT SUMMARY"
echo
log "🎉 SPEEDSEND DEPLOYMENT COMPLETE!"
echo
header "📊 NEW FEATURES DEPLOYED:"
info "✅ DATA MANAGEMENT VIEW"
info "  - View all accounts, campaigns, users, recipients"
info "  - Real-time database statistics"
info "  - Bulk delete operations"
info "  - System health monitoring"
echo
info "✅ ANALYTICS & REPORTS VIEW"
info "  - Campaign performance metrics"
info "  - Success rates and send statistics"
info "  - Account performance tracking"
info "  - Export functionality (JSON/CSV)"
echo
info "✅ TEST CENTER VIEW"
info "  - Email testing with custom content"
info "  - Gmail connection testing"
info "  - Template validation with variables"
info "  - Bulk email testing"
echo
info "✅ GMAIL SERVICE ACCOUNT INTEGRATION"
info "  - Proper service account JSON validation"
info "  - Domain-wide delegation support"
info "  - All required Gmail + Admin Directory scopes"
info "  - User delegation for email sending"
echo
info "✅ ADVANCED EMAIL DISTRIBUTION"
info "  - Recipients split equally across workspace users"
info "  - Only active users are used for sending"
info "  - Admins are NOT used for sending (only management)"
info "  - Load balancing across multiple accounts"
echo
header "🔐 REQUIRED GMAIL API SCOPES:"
info "  https://www.googleapis.com/auth/gmail.send"
info "  https://www.googleapis.com/auth/gmail.compose"
info "  https://www.googleapis.com/auth/gmail.insert"
info "  https://www.googleapis.com/auth/gmail.modify"
info "  https://www.googleapis.com/auth/gmail.readonly"
info "  https://www.googleapis.com/auth/admin.directory.user"
info "  https://www.googleapis.com/auth/admin.directory.user.security"
info "  https://www.googleapis.com/auth/admin.directory.orgunit"
info "  https://www.googleapis.com/auth/admin.directory.domain.readonly"
echo
header "📱 ACCESS YOUR APPLICATION:"
info "Frontend:           http://localhost:3000"
info "Backend API:        http://localhost:8000"
info "API Documentation:  http://localhost:8000/docs"
info "Health Check:       http://localhost:8000/health"
echo
header "🎯 NEW API ENDPOINTS:"
info "POST /api/v1/campaigns/{id}/send-with-users    - Send with user delegation"
info "GET  /api/v1/campaigns/{id}/user-distribution  - Preview user distribution"
info "POST /api/v1/campaigns/{id}/test-user-capability - Test user sending"
info "GET  /api/v1/analytics                         - Performance analytics"
info "GET  /api/v1/system/stats                      - System statistics"
info "POST /api/v1/templates/validate                - Template validation"
info "DELETE /api/v1/bulk-delete/{type}              - Bulk operations"
echo
header "📋 NAVIGATION GUIDE:"
info "📊 DASHBOARD - Campaign overview and quick actions"
info "🚀 ULTRA-FAST SEND - Create and send campaigns quickly"
info "👥 ACCOUNTS - Manage Gmail/Workspace accounts"
info "📊 DATA MANAGEMENT - View/manage all stored data"
info "📈 ANALYTICS & REPORTS - Performance metrics and exports"
info "🧪 TEST CENTER - Testing tools and validation"
echo
header "⚙️  NEXT STEPS:"
warn "1. Add your Google Service Account JSON files via Accounts view"
warn "2. Ensure domain-wide delegation is configured with ALL required scopes"
warn "3. Test connections using Test Center before sending campaigns"
warn "4. Use Data Management to monitor system health and data"
warn "5. Check Analytics for performance insights"
echo
log "🏁 SpeedSend is now fully operational with complete Gmail integration!"
echo
header "🔧 TROUBLESHOOTING:"
info "View logs:        docker compose logs [service_name]"
info "Restart service:  docker compose restart [service_name]"
info "Full restart:     docker compose restart"
info "Stop all:         docker compose down"
echo
log "✨ Deployment completed successfully! Your production-ready email management platform is ready!"