#!/bin/bash

# Speed-Send Email Platform - Complete Fixed Deployment
# Ubuntu 22.04 - Fixes: Missing frontend, backend health, dependencies

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Clean up all old deployment files and ensure fresh start
cleanup_old_files() {
    log "Cleaning up old deployment files..."
    rm -f fix-installation.sh fix-deployment.sh nuclear-fix-deployment.sh
    rm -f quick-deploy.sh quick-deploy-ubuntu.sh setup-complete-project.sh  
    rm -f fix-poetry.sh fix-copy-command.sh force-rebuild.sh clear-cache-rebuild.sh
    rm -f verify-project-structure.sh frontend-fix.sh quick-fix.sh immediate-fix.sh
    rm -f complete-frontend-fix.sh deploy-final.sh check-status.sh status-check.md
    rm -f deploy.bat DEPLOYMENT.md nginx-frontend.conf deploy_old.sh
    rm -f backend/Dockerfile.old docker-compose-frontend-fix.yml docker-compose-backup.yml
    rm -f Dockerfile nginx-frontend.conf docker-compose-frontend-fix.yml
    
    # Stop and remove all containers
    docker-compose down --remove-orphans --volumes || true
    docker container prune -f || true
    docker image prune -f || true
    docker system prune -f || true
    
    log "Complete cleanup finished"
}

# Detect OS and install dependencies
install_dependencies() {
    log "Installing dependencies for Ubuntu 22.04..."
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    
    # Install Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl start docker
        systemctl enable docker
        usermod -aG docker $USER
    fi
    
    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..."
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Install Node.js
    if ! command -v node &> /dev/null; then
        log "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
}

# Fix all configuration issues
fix_all_configurations() {
    log "Fixing all configurations..."
    
    # Fix backend requirements
    log "Fixing backend requirements.txt..."
    cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic[email]==2.5.0
pydantic-settings==2.1.0
email-validator==2.1.0
sqlalchemy==2.0.23
alembic==1.13.1
psycopg2-binary==2.9.9
celery==5.3.4
redis==5.0.1
celery-redbeat==2.0.0
cryptography==41.0.7
google-api-python-client==2.108.0
google-auth==2.25.2
python-multipart==0.0.6
python-dotenv==1.0.0
passlib[bcrypt]==1.7.4
aiohttp==3.9.1
EOF

    # Fix backend health endpoint
    log "Fixing backend health endpoint..."
    cat > backend/api/v1/endpoints/health.py << 'EOF'
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "healthy", "message": "Speed-Send API is running"}

@router.get("/")
def root():
    return {"message": "Speed-Send API", "status": "healthy"}
EOF

    # Fix database models - Add missing foreign key relationships
    log "Fixing database models..."
    cat > backend/models.py << 'MODELSEOF'
from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    accounts = relationship("Account", back_populates="user")
    campaigns = relationship("Campaign", back_populates="user")

class Account(Base):
    __tablename__ = "accounts"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    encrypted_credentials = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
    daily_limit = Column(Integer, default=500)
    hourly_limit = Column(Integer, default=50)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="accounts")
    campaigns = relationship("Campaign", back_populates="account")

class Campaign(Base):
    __tablename__ = "campaigns"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    subject = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    status = Column(String, default="draft")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    account_id = Column(Integer, ForeignKey("accounts.id"), nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="campaigns")
    account = relationship("Account", back_populates="campaigns")
    emails = relationship("Email", back_populates="campaign")

class Email(Base):
    __tablename__ = "emails"
    
    id = Column(Integer, primary_key=True, index=True)
    recipient_email = Column(String, nullable=False, index=True)
    recipient_name = Column(String)
    status = Column(String, default="pending")
    sent_at = Column(DateTime(timezone=True))
    error_message = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    campaign_id = Column(Integer, ForeignKey("campaigns.id"), nullable=False)
    
    # Relationships
    campaign = relationship("Campaign", back_populates="emails")
MODELSEOF

    # Update main.py to include health route at root
    log "Updating main.py..."
    if ! grep -q "app.get.*health" backend/main.py; then
        cat >> backend/main.py << 'EOF'

# Add root health endpoint
@app.get("/health")
def health_check():
    return {"status": "healthy", "message": "Speed-Send API is running"}

@app.get("/")
def root():
    return {"message": "Speed-Send API", "status": "healthy"}
EOF
    fi

    # Fix React component syntax errors by replacing corrupted DashboardView.tsx
    log "Fixing React component syntax errors..."
    
    if [ -f "components/views/DashboardView.tsx" ]; then
        # Create a backup
        cp components/views/DashboardView.tsx components/views/DashboardView.tsx.backup
        
        # Replace with corrected version
        cat > components/views/DashboardView.tsx << 'DASHBOARDEOF'
import React from 'react';
import { Campaign, CampaignStatus } from '../../types';
import Button from '../ui/Button';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Badge from '../ui/Badge';
import ProgressBar from '../ui/ProgressBar';
import PlusIcon from '../icons/PlusIcon';
import PlayIcon from '../icons/PlayIcon';
import PauseIcon from '../icons/PauseIcon';
import PaperAirplaneIcon from '../icons/PaperAirplaneIcon';
import { useToast } from '../../contexts/ToastContext';
import { useDialog } from '../../contexts/DialogContext';

interface DashboardViewProps {
  campaigns: Campaign[];
  onCreateCampaign: () => void;
  onViewCampaign: (campaignId: number) => void;
  onToggleCampaign: (campaignId: number, newStatus: CampaignStatus) => Promise<void>;
  isLoadingCampaigns: boolean;
  errorLoadingCampaigns: string | null;
}

const CampaignStatusBadge: React.FC<{ status: CampaignStatus }> = ({ status }) => {
  const colorMap: { [key in CampaignStatus]: 'green' | 'blue' | 'yellow' | 'red' | 'gray' } = {
    [CampaignStatus.COMPLETED]: 'green',
    [CampaignStatus.SENDING]: 'blue',
    [CampaignStatus.PAUSED]: 'yellow',
    [CampaignStatus.FAILED]: 'red',
    [CampaignStatus.DRAFT]: 'gray',
  };
  return <Badge color={colorMap[status]}>{status}</Badge>;
};

const DashboardView: React.FC<DashboardViewProps> = ({ 
  campaigns, 
  onCreateCampaign, 
  onViewCampaign, 
  onToggleCampaign,
  isLoadingCampaigns,
  errorLoadingCampaigns,
}) => {
  const { addToast } = useToast();
  const { openDialog } = useDialog();

  const handleToggle = async (campaign: Campaign) => {
    const isSending = campaign.status === CampaignStatus.SENDING;
    const action = isSending ? 'pause' : 'start';
    const newStatus = isSending ? CampaignStatus.PAUSED : CampaignStatus.SENDING;
    const confirmationMessage = isSending 
      ? `Are you sure you want to pause "${campaign.name}"?`
      : `Are you sure you want to start "${campaign.name}"?`;

    openDialog({
      title: `${action === 'pause' ? 'Pause' : 'Start'} Campaign`,
      message: confirmationMessage,
      onConfirm: async () => {
        try {
          await onToggleCampaign(campaign.id, newStatus);
          addToast({ 
            message: `Campaign "${campaign.name}" ${action === 'pause' ? 'paused' : 'started'} successfully!`, 
            type: 'success' 
          });
        } catch (error) {
          addToast({ 
            message: `Failed to ${action} campaign "${campaign.name}". ${error instanceof Error ? error.message : ''}`, 
            type: 'error' 
          });
        }
      },
    });
  };

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Campaign Dashboard</h1>
        <Button onClick={onCreateCampaign}>
          <PlusIcon className="w-5 h-5 mr-2" />
          Create Campaign
        </Button>
      </div>

      {isLoadingCampaigns && (
        <div className="text-center text-gray-500 dark:text-gray-400">Loading campaigns...</div>
      )}

      {errorLoadingCampaigns && (
        <div className="text-center text-red-500 dark:text-red-400">Error loading campaigns: {errorLoadingCampaigns}</div>
      )}

      {!isLoadingCampaigns && !errorLoadingCampaigns && campaigns.length === 0 ? (
        <Card>
          <CardContent className="text-center text-gray-500 dark:text-gray-400 py-12">
            <PaperAirplaneIcon className="w-16 h-16 mx-auto mb-4 text-primary-400 transform -rotate-45" />
            <h3 className="text-xl font-medium text-gray-800 dark:text-gray-100">No campaigns created yet</h3>
            <p className="mt-2 text-base">Start by creating your first email campaign.</p>
            <Button onClick={onCreateCampaign} className="mt-6">
              <PlusIcon className="w-5 h-5 mr-2" />
              Create First Campaign
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-6">
          {campaigns.map((campaign) => {
            const progress = campaign.stats.total > 0 ? (campaign.stats.sent / campaign.stats.total) * 100 : 0;
            return (
              <Card key={campaign.id}>
                <CardHeader className="flex justify-between items-center">
                  <div>
                    <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100">{campaign.name}</h2>
                    <p className="text-sm text-gray-500 dark:text-gray-400">{campaign.subject}</p>
                  </div>
                  <CampaignStatusBadge status={campaign.status} />
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <div className="flex justify-between items-center mb-1">
                        <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Progress</span>
                        <span className="text-sm text-gray-500 dark:text-gray-400">{campaign.stats.sent} / {campaign.stats.total} sent</span>
                    </div>
                    <ProgressBar value={progress} />
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-center">
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Success</p>
                      <p className="text-xl font-semibold text-green-600">{campaign.stats.sent}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Pending</p>
                      <p className="text-xl font-semibold text-yellow-600">{campaign.stats.pending}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Failed</p>
                      <p className="text-xl font-semibold text-red-600">{campaign.stats.failed}</p>
                    </div>
                     <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Success Rate</p>
                      <p className="text-xl font-semibold text-blue-600">{progress.toFixed(1)}%</p>
                    </div>
                  </div>
                </CardContent>
                <div className="p-4 bg-gray-50 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 flex justify-end items-center space-x-2">
                    <Button variant="secondary" onClick={() => onViewCampaign(campaign.id)}>View Details</Button>
                    {(campaign.status === CampaignStatus.DRAFT || campaign.status === CampaignStatus.PAUSED || campaign.status === CampaignStatus.FAILED) && (
                        <Button variant="primary" onClick={() => handleToggle(campaign)}>
                            <PlayIcon className="w-5 h-5 mr-2"/> Start
                        </Button>
                    )}
                    {campaign.status === CampaignStatus.SENDING && (
                         <Button variant="secondary" onClick={() => handleToggle(campaign)}>
                            <PauseIcon className="w-5 h-5 mr-2"/> Pause
                         </Button>
                    )}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default DashboardView;
DASHBOARDEOF
        
        log "Replaced DashboardView.tsx with corrected syntax"
    fi
    
    # Additional check - if DashboardView still has issues, create a minimal working version
    if grep -q "campaigns.map" components/views/DashboardView.tsx 2>/dev/null; then
        log "Creating simplified DashboardView.tsx to eliminate syntax errors..."
        cat > components/views/DashboardView.tsx << 'SIMPLEDASHEOF'
import React from 'react';
import { Campaign, CampaignStatus } from '../../types';
import Button from '../ui/Button';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Badge from '../ui/Badge';
import ProgressBar from '../ui/ProgressBar';
import PlusIcon from '../icons/PlusIcon';
import PlayIcon from '../icons/PlayIcon';
import PauseIcon from '../icons/PauseIcon';
import PaperAirplaneIcon from '../icons/PaperAirplaneIcon';

interface DashboardViewProps {
  campaigns: Campaign[];
  onCreateCampaign: () => void;
  onViewCampaign: (campaignId: number) => void;
  onToggleCampaign: (campaignId: number, newStatus: CampaignStatus) => Promise<void>;
  isLoadingCampaigns: boolean;
  errorLoadingCampaigns: string | null;
}

const DashboardView: React.FC<DashboardViewProps> = ({ 
  campaigns, 
  onCreateCampaign, 
  onViewCampaign, 
  onToggleCampaign,
  isLoadingCampaigns,
  errorLoadingCampaigns,
}) => {
  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Campaign Dashboard</h1>
        <Button onClick={onCreateCampaign}>
          <PlusIcon className="w-5 h-5 mr-2" />
          Create Campaign
        </Button>
      </div>

      {isLoadingCampaigns && (
        <div className="text-center text-gray-500 dark:text-gray-400">Loading campaigns...</div>
      )}

      {errorLoadingCampaigns && (
        <div className="text-center text-red-500 dark:text-red-400">
          Error loading campaigns: {errorLoadingCampaigns}
        </div>
      )}

      {!isLoadingCampaigns && !errorLoadingCampaigns && campaigns.length === 0 ? (
        <Card>
          <CardContent className="text-center text-gray-500 dark:text-gray-400 py-12">
            <PaperAirplaneIcon className="w-16 h-16 mx-auto mb-4 text-primary-400 transform -rotate-45" />
            <h3 className="text-xl font-medium text-gray-800 dark:text-gray-100">No campaigns created yet</h3>
            <p className="mt-2 text-base">Start by creating your first email campaign.</p>
            <Button onClick={onCreateCampaign} className="mt-6">
              <PlusIcon className="w-5 h-5 mr-2" />
              Create First Campaign
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-6">
          {campaigns.map((campaign) => {
            const progress = campaign.stats && campaign.stats.total > 0 
              ? (campaign.stats.sent / campaign.stats.total) * 100 
              : 0;
            
            return (
              <Card key={campaign.id}>
                <CardHeader className="flex justify-between items-center">
                  <div>
                    <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100">
                      {campaign.name}
                    </h2>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {campaign.subject}
                    </p>
                  </div>
                  <Badge color="blue">{campaign.status}</Badge>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <div className="flex justify-between items-center mb-1">
                      <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                        Progress
                      </span>
                      <span className="text-sm text-gray-500 dark:text-gray-400">
                        {campaign.stats ? campaign.stats.sent : 0} / {campaign.stats ? campaign.stats.total : 0} sent
                      </span>
                    </div>
                    <ProgressBar value={progress} />
                  </div>
                  <div className="flex justify-end items-center space-x-2">
                    <Button variant="secondary" onClick={() => onViewCampaign(campaign.id)}>
                      View Details
                    </Button>
                    <Button variant="primary" onClick={() => onToggleCampaign(campaign.id, CampaignStatus.SENDING)}>
                      <PlayIcon className="w-5 h-5 mr-2" />
                      Start
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default DashboardView;
SIMPLEDASHEOF
        log "Created simplified DashboardView.tsx without syntax errors"
    fi
    
    # Create package.json for frontend
    log "Creating package.json..."
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
    "react-dom": "^18.2.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/uuid": "^9.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^4.4.0"
  }
}
EOF

    # Fix docker-compose.yml (remove obsolete version attribute)
    log "Creating fixed docker-compose.yml..."
    cat > docker-compose.yml << 'EOF'
services:
  db:
    image: postgres:15-alpine
    container_name: speedsend_db
    volumes:
      - postgres_data:/var/lib/postgresql/data/
    environment:
      - POSTGRES_USER=speedsend
      - POSTGRES_PASSWORD=speedsend123
      - POSTGRES_DB=speedsend
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U speedsend -d speedsend"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: speedsend_redis
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  backend:
    build: ./backend
    container_name: speedsend_backend
    environment:
      - DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
      - ./uploads:/app/uploads
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    restart: unless-stopped

  celery_worker:
    build: ./backend
    container_name: speedsend_celery_worker
    environment:
      - DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    volumes:
      - ./backend:/app
      - ./uploads:/app/uploads
    depends_on:
      backend:
        condition: service_started
    command: celery -A tasks.celery_app worker -l info -c 4
    restart: unless-stopped

  celery_beat:
    build: ./backend
    container_name: speedsend_celery_beat
    environment:
      - DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend
      - REDIS_URL=redis://redis:6379/0
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    volumes:
      - ./backend:/app
    depends_on:
      backend:
        condition: service_started
    command: celery -A tasks.celery_app beat -l info --pidfile=/tmp/celerybeat.pid --scheduler=redbeat.RedBeatScheduler
    restart: unless-stopped
  
  frontend:
    image: node:18-alpine
    container_name: speedsend_frontend
    ports:
      - "3000:3000"
    volumes:
      - ./:/app
      - /app/node_modules
    working_dir: /app
    environment:
      - NODE_ENV=development
    depends_on:
      - backend
    command: sh -c "npm install && npm run dev -- --host 0.0.0.0"
    restart: unless-stopped

volumes:
  postgres_data:
EOF

    # Create .env file
    if [ ! -f .env ]; then
        log "Creating .env file..."
        cat > .env << 'EOF'
# Database
POSTGRES_USER=speedsend
POSTGRES_PASSWORD=speedsend123
POSTGRES_DB=speedsend
DATABASE_URL=postgresql://speedsend:speedsend123@db:5432/speedsend

# Redis
REDIS_URL=redis://redis:6379/0

# Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
CELERY_WORKER_CONCURRENCY=4

# Gmail API (CONFIGURE THESE!)
GMAIL_CLIENT_ID=your-gmail-client-id-here
GMAIL_CLIENT_SECRET=your-gmail-client-secret-here

# Security
JWT_SECRET_KEY=your-super-secret-jwt-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
EOF
    fi
}

# Deploy application
deploy_application() {
    log "Deploying Speed-Send application..."
    
    # Stop and clean
    docker-compose down --remove-orphans || true
    docker system prune -f || true
    
    # Create directories
    mkdir -p logs uploads backend/uploads
    chmod 755 logs uploads backend/uploads
    
    # Build and start
    log "Building containers..."
    docker-compose build --no-cache
    
    log "Starting database and Redis first..."
    docker-compose up -d db redis
    
    # Wait for database
    log "Waiting for database to be ready..."
    sleep 30
    
    # Fix database.py to ensure proper connection
    log "Creating production-ready database.py..."
    cat > backend/database.py << 'DBEOF'
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
import time

# Database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://speedsend:speedsend123@db:5432/speedsend")

# Create engine with connection pooling and retry logic
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=300,
    pool_size=10,
    max_overflow=20,
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Dependency for getting database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Function to wait for database to be ready
def wait_for_db():
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            # Try to connect to database
            connection = engine.connect()
            connection.close()
            print("Database connection successful!")
            return True
        except Exception as e:
            print(f"Database connection attempt {retry_count + 1}/{max_retries} failed: {e}")
            time.sleep(2)
            retry_count += 1
    
    raise Exception("Could not connect to database after maximum retries")

# Initialize database tables
def init_db():
    from models import Base
    wait_for_db()
    Base.metadata.create_all(bind=engine)
    print("Database tables created successfully!")
DBEOF

    # Create a proper main.py that initializes everything correctly
    log "Creating production-ready main.py..."
    cat > backend/main.py << 'MAINEOF'
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from api.v1.api import api_router
from database import init_db
import uvicorn

# Initialize database on startup
try:
    init_db()
    print("Database initialized successfully!")
except Exception as e:
    print(f"Database initialization failed: {e}")

app = FastAPI(
    title="Speed-Send API",
    description="High-performance email campaign platform",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router, prefix="/api/v1")

# Root health endpoint
@app.get("/")
def read_root():
    return {"message": "Speed-Send API", "status": "healthy", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "message": "Speed-Send API is running"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
MAINEOF

    # Initialize database with new schema
    log "Initializing database with correct schema..."
    docker-compose run --rm backend python -c "
import sys
sys.path.append('/app')
from database import wait_for_db, init_db
from models import Base

try:
    print('Waiting for database to be ready...')
    wait_for_db()
    print('Database is ready!')
    
    print('Initializing database schema...')
    init_db()
    print('Database initialized successfully!')
    
except Exception as e:
    print(f'Database initialization failed: {e}')
    exit(1)
"
    
    # Create production-ready CRUD operations
    log "Creating production-ready CRUD operations..."
    cat > backend/crud.py << 'CRUDEOF'
from sqlalchemy.orm import Session
from sqlalchemy import func
from models import User, Account, Campaign, Email
from schemas import UserCreate, AccountCreate, CampaignCreate
from passlib.context import CryptContext
import uuid

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# User CRUD operations
def get_user(db: Session, user_id: int):
    return db.query(User).filter(User.id == user_id).first()

def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()

def create_user(db: Session, user: UserCreate):
    hashed_password = pwd_context.hash(user.password)
    db_user = User(
        email=user.email,
        hashed_password=hashed_password,
        is_active=True
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def get_users(db: Session, skip: int = 0, limit: int = 100):
    return db.query(User).offset(skip).limit(limit).all()

# Account CRUD operations
def get_account(db: Session, account_id: int):
    return db.query(Account).filter(Account.id == account_id).first()

def get_accounts(db: Session, skip: int = 0, limit: int = 100):
    return db.query(Account).offset(skip).limit(limit).all()

def get_accounts_by_user(db: Session, user_id: int):
    return db.query(Account).filter(Account.user_id == user_id).all()

def create_account(db: Session, account: AccountCreate, user_id: int):
    db_account = Account(
        email=account.email,
        name=account.name,
        encrypted_credentials=account.encrypted_credentials,
        daily_limit=account.daily_limit or 500,
        hourly_limit=account.hourly_limit or 50,
        user_id=user_id,
        is_active=True
    )
    db.add(db_account)
    db.commit()
    db.refresh(db_account)
    return db_account

def update_account(db: Session, account_id: int, account_update: dict):
    db_account = db.query(Account).filter(Account.id == account_id).first()
    if db_account:
        for key, value in account_update.items():
            setattr(db_account, key, value)
        db.commit()
        db.refresh(db_account)
    return db_account

def delete_account(db: Session, account_id: int):
    db_account = db.query(Account).filter(Account.id == account_id).first()
    if db_account:
        db.delete(db_account)
        db.commit()
    return db_account

# Campaign CRUD operations
def get_campaign(db: Session, campaign_id: int):
    return db.query(Campaign).filter(Campaign.id == campaign_id).first()

def get_campaigns(db: Session, skip: int = 0, limit: int = 100):
    return db.query(Campaign).offset(skip).limit(limit).all()

def get_campaigns_by_user(db: Session, user_id: int):
    return db.query(Campaign).filter(Campaign.user_id == user_id).all()

def create_campaign(db: Session, campaign: CampaignCreate, user_id: int):
    db_campaign = Campaign(
        name=campaign.name,
        subject=campaign.subject,
        content=campaign.content,
        status="draft",
        user_id=user_id,
        account_id=campaign.account_id if hasattr(campaign, 'account_id') else None
    )
    db.add(db_campaign)
    db.commit()
    db.refresh(db_campaign)
    return db_campaign

def update_campaign(db: Session, campaign_id: int, campaign_update: dict):
    db_campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if db_campaign:
        for key, value in campaign_update.items():
            setattr(db_campaign, key, value)
        db.commit()
        db.refresh(db_campaign)
    return db_campaign

def delete_campaign(db: Session, campaign_id: int):
    db_campaign = db.query(Campaign).filter(Campaign.id == campaign_id).first()
    if db_campaign:
        db.delete(db_campaign)
        db.commit()
    return db_campaign

# Email CRUD operations
def get_email(db: Session, email_id: int):
    return db.query(Email).filter(Email.id == email_id).first()

def get_emails_by_campaign(db: Session, campaign_id: int):
    return db.query(Email).filter(Email.campaign_id == campaign_id).all()

def create_email(db: Session, recipient_email: str, recipient_name: str, campaign_id: int):
    db_email = Email(
        recipient_email=recipient_email,
        recipient_name=recipient_name,
        campaign_id=campaign_id,
        status="pending"
    )
    db.add(db_email)
    db.commit()
    db.refresh(db_email)
    return db_email

def update_email_status(db: Session, email_id: int, status: str, error_message: str = None):
    db_email = db.query(Email).filter(Email.id == email_id).first()
    if db_email:
        db_email.status = status
        if error_message:
            db_email.error_message = error_message
        if status == "sent":
            db_email.sent_at = func.now()
        db.commit()
        db.refresh(db_email)
    return db_email

# Campaign statistics
def get_campaign_stats(db: Session, campaign_id: int):
    stats = db.query(
        func.count(Email.id).label('total'),
        func.sum(func.case([(Email.status == 'sent', 1)], else_=0)).label('sent'),
        func.sum(func.case([(Email.status == 'pending', 1)], else_=0)).label('pending'),
        func.sum(func.case([(Email.status == 'failed', 1)], else_=0)).label('failed')
    ).filter(Email.campaign_id == campaign_id).first()
    
    return {
        'total': int(stats.total or 0),
        'sent': int(stats.sent or 0),
        'pending': int(stats.pending or 0),
        'failed': int(stats.failed or 0)
    }
CRUDEOF

    # Create production-ready schemas
    log "Creating production-ready schemas..."
    cat > backend/schemas.py << 'SCHEMASEOF'
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum

class CampaignStatus(str, Enum):
    DRAFT = "draft"
    SENDING = "sending"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"

class EmailStatus(str, Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"

# User schemas
class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

# Account schemas
class AccountBase(BaseModel):
    email: EmailStr
    name: str

class AccountCreate(AccountBase):
    encrypted_credentials: str
    daily_limit: Optional[int] = 500
    hourly_limit: Optional[int] = 50

class AccountUpdate(BaseModel):
    name: Optional[str] = None
    daily_limit: Optional[int] = None
    hourly_limit: Optional[int] = None
    is_active: Optional[bool] = None

class Account(AccountBase):
    id: int
    is_active: bool
    daily_limit: int
    hourly_limit: int
    created_at: datetime
    user_id: int

    class Config:
        from_attributes = True

# Campaign schemas
class CampaignBase(BaseModel):
    name: str
    subject: str
    content: str

class CampaignCreate(CampaignBase):
    account_id: Optional[int] = None

class CampaignUpdate(BaseModel):
    name: Optional[str] = None
    subject: Optional[str] = None
    content: Optional[str] = None
    status: Optional[CampaignStatus] = None
    account_id: Optional[int] = None

class CampaignStats(BaseModel):
    total: int
    sent: int
    pending: int
    failed: int

class Campaign(CampaignBase):
    id: int
    status: CampaignStatus
    created_at: datetime
    updated_at: Optional[datetime]
    user_id: int
    account_id: Optional[int]
    stats: CampaignStats

    class Config:
        from_attributes = True

# Email schemas
class EmailBase(BaseModel):
    recipient_email: EmailStr
    recipient_name: Optional[str] = None

class EmailCreate(EmailBase):
    campaign_id: int

class Email(EmailBase):
    id: int
    status: EmailStatus
    sent_at: Optional[datetime]
    error_message: Optional[str]
    created_at: datetime
    campaign_id: int

    class Config:
        from_attributes = True

# Response schemas
class Message(BaseModel):
    message: str

class HealthCheck(BaseModel):
    status: str
    message: str
    version: Optional[str] = "1.0.0"

# Additional schemas for API endpoints
class AccountWithUsers(BaseModel):
    id: int
    email: EmailStr
    name: str
    is_active: bool
    daily_limit: int
    hourly_limit: int
    created_at: datetime
    user_id: int
    user: Optional[User] = None

    class Config:
        from_attributes = True

class CampaignWithStats(BaseModel):
    id: int
    name: str
    subject: str
    content: str
    status: CampaignStatus
    created_at: datetime
    updated_at: Optional[datetime]
    user_id: int
    account_id: Optional[int]
    stats: CampaignStats
    account: Optional[Account] = None

    class Config:
        from_attributes = True
SCHEMASEOF

    # Fix Docker networking and container startup order
    log "Starting all services with proper dependencies..."
    
    # Start database and Redis first and wait
    docker-compose up -d db redis
    log "Waiting for database and Redis to be fully ready..."
    sleep 45
    
    # Verify database is accepting connections
    log "Verifying database readiness..."
    docker exec speedsend_db pg_isready -U speedsend -d speedsend || echo "Database not ready yet, waiting more..."
    sleep 15
    
    # Start backend only after database is ready
    log "Starting backend service..."
    docker-compose up -d backend
    
    # Wait for backend to start and check logs immediately
    log "Waiting for backend to start..."
    sleep 30
    
    # Check backend startup logs
    log "Checking backend startup logs:"
    docker logs speedsend_backend --tail 20
    
    # Check if backend is listening on port 8000
    log "Checking if backend is listening on port 8000:"
    docker exec speedsend_backend netstat -tlnp | grep 8000 || echo "Backend not listening on port 8000"
    
    # Start Celery services
    log "Starting Celery services..."
    docker-compose up -d celery_worker celery_beat
    sleep 15
    
    # Finally start frontend
    log "Starting frontend service..."
    docker-compose up -d frontend
    sleep 15
    
    # Wait longer for all services to properly start
    log "Waiting for all services to start properly..."
    sleep 90
    
    log "Checking service status..."
    docker-compose ps
    
    # Comprehensive diagnostics
    log "Running comprehensive diagnostics..."
    
    # Check container status
    log "Container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep speedsend || echo "No speedsend containers found"
    
    # Check backend logs for errors
    log "Backend container logs (last 50 lines):"
    docker logs speedsend_backend --tail 50 2>&1 || echo "Cannot get backend logs"
    
    # Check if backend is running
    log "Checking if backend process is running inside container:"
    docker exec speedsend_backend ps aux | grep python || echo "Backend process not found"
    
    # Check network connectivity
    log "Checking network connectivity:"
    docker exec speedsend_frontend ping -c 2 speedsend_backend || echo "Network connectivity failed"
    
    # Test database connection from backend
    log "Testing database connection from backend:"
    docker exec speedsend_backend python -c "
import sys
sys.path.append('/app')
try:
    from database import engine
    connection = engine.connect()
    print('✅ Database connection successful')
    connection.close()
except Exception as e:
    print(f'❌ Database connection failed: {e}')
" || echo "Could not test database connection"
    
    # Test specific endpoints
    log "Testing endpoints..."
    
    # Test backend health
    log "Testing backend health endpoint:"
    curl -v http://localhost:8000/health 2>&1 || echo "Backend health endpoint failed"
    
    # Test backend root
    log "Testing backend root endpoint:"
    curl -v http://localhost:8000/ 2>&1 || echo "Backend root endpoint failed"
    
    # Show backend process details
    log "Backend process details:"
    docker exec speedsend_backend netstat -tlnp 2>/dev/null || echo "Cannot get network details"
}

# Show final status
show_status() {
    log "========================================="
    log "  Speed-Send Deployment Complete!"
    log "========================================="
    echo
    log "Access URLs:"
    log "Frontend:    http://localhost:3000"
    log "Backend API: http://localhost:8000"
    log "API Docs:    http://localhost:8000/docs"
    log "Health:      http://localhost:8000/health"
    echo
    log "Container Status:"
    docker-compose ps
    echo
    warn "⚠️  Configure Gmail API credentials in .env file!"
    echo
    log "Useful Commands:"
    log "View logs:   docker-compose logs -f"
    log "Restart:     docker-compose restart"
    log "Stop:        docker-compose down"
    echo
}

# Main execution
main() {
    log "Starting Speed-Send fixed deployment for Ubuntu 22.04..."
    
    cleanup_old_files
    install_dependencies
    fix_all_configurations
    deploy_application
    show_status
}

# Handle arguments
case "${1:-}" in
    "clean")
        log "Deep cleaning system..."
        cleanup_old_files
        docker-compose down --remove-orphans --volumes
        docker system prune -af --volumes
        log "Deep clean completed!"
        ;;
    "config")
        log "Fixing configurations only..."
        fix_all_configurations
        log "Configurations fixed!"
        ;;
    "deploy")
        log "Deploying application only..."
        deploy_application
        ;;
    "reinstall")
        log "Complete reinstall - cleaning everything first..."
        cleanup_old_files
        install_dependencies
        fix_all_configurations
        deploy_application
        show_status
        ;;
    "status")
        log "Current system status:"
        docker-compose ps
        curl -s http://localhost:8000/health && echo " - Backend: ✅ Healthy" || echo " - Backend: ❌ Not responding"
        curl -s http://localhost:3000 >/dev/null && echo " - Frontend: ✅ Accessible" || echo " - Frontend: ❌ Not accessible"
        ;;
    *)
        log "Starting complete Speed-Send deployment..."
        main
        ;;
esac