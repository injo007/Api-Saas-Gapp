# Speed-Send Deployment Fix Script (PowerShell)
# This script fixes common deployment issues and ensures clean setup

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Speed-Send Deployment Fix..." -ForegroundColor Green

# Function to generate random keys
function Generate-Key {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return [System.Convert]::ToHexString($bytes).ToLower()
}

try {
    # Step 1: Clean up any existing containers and volumes
    Write-Host "🧹 Cleaning up existing containers..." -ForegroundColor Yellow
    docker-compose down --volumes --remove-orphans 2>$null
    docker system prune -f 2>$null

    # Step 2: Remove any dangling images
    Write-Host "🗑️ Removing dangling images..." -ForegroundColor Yellow
    docker image prune -f 2>$null

    # Step 3: Setup environment file
    Write-Host "⚙️ Setting up environment file..." -ForegroundColor Yellow
    if (-not (Test-Path ".env")) {
        Write-Host "Creating .env file from template..." -ForegroundColor Cyan
        Copy-Item ".env.template" ".env"
        
        # Generate secure keys
        $secretKey = Generate-Key
        $encryptionKey = Generate-Key
        
        # Update .env with generated keys
        $envContent = Get-Content ".env" -Raw
        $envContent = $envContent -replace "your_secret_key_here_change_this_in_production", $secretKey
        $envContent = $envContent -replace "your_encryption_key_here_change_this_in_production", $encryptionKey
        Set-Content ".env" $envContent
        
        Write-Host "✅ Environment file created with secure keys" -ForegroundColor Green
    } else {
        Write-Host "✅ Environment file already exists" -ForegroundColor Green
    }

    # Step 4: Create necessary directories
    Write-Host "📁 Creating required directories..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path "uploads" | Out-Null
    New-Item -ItemType Directory -Force -Path "backend/uploads" | Out-Null

    # Step 5: Clean rebuild backend image
    Write-Host "🔨 Building backend image..." -ForegroundColor Yellow
    docker-compose build --no-cache backend

    # Step 6: Start services in correct order
    Write-Host "🚀 Starting services..." -ForegroundColor Yellow
    docker-compose up -d db redis

    # Wait for database to be ready
    Write-Host "⏳ Waiting for database to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # Start backend services
    docker-compose up -d backend celery_worker celery_beat

    # Wait for backend to be ready
    Write-Host "⏳ Waiting for backend to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15

    # Start frontend
    docker-compose up -d frontend

    # Step 7: Run database migrations
    Write-Host "🗃️ Running database migrations..." -ForegroundColor Yellow
    docker-compose exec -T backend alembic upgrade head

    Write-Host ""
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Application URLs:" -ForegroundColor Cyan
    Write-Host "   Frontend: http://localhost:3000"
    Write-Host "   Backend API: http://localhost:8000"
    Write-Host "   API Docs: http://localhost:8000/docs"
    Write-Host ""
    Write-Host "📊 To check service status:" -ForegroundColor Cyan
    Write-Host "   docker-compose ps"
    Write-Host ""
    Write-Host "📋 To view logs:" -ForegroundColor Cyan
    Write-Host "   docker-compose logs -f [service_name]"
    Write-Host ""
}
catch {
    Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
    Write-Host "Please check the troubleshooting guide or run with verbose logging." -ForegroundColor Yellow
    exit 1
}