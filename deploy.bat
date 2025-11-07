@echo off
REM Speed-Send Email Platform - Windows Deployment Script
REM This script deploys the application on Windows with Docker Desktop

echo ================================
echo Speed-Send Platform Deployment
echo ================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH
    echo Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)

REM Check if Docker Compose is available
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker Compose is not available
    echo Please ensure Docker Desktop is running properly
    pause
    exit /b 1
)

echo [INFO] Docker found. Version:
docker --version
docker-compose --version
echo.

REM Create necessary directories
echo [INFO] Creating directories...
if not exist "logs" mkdir logs
if not exist "data" mkdir data
if not exist "data\postgres" mkdir data\postgres
if not exist "data\redis" mkdir data\redis
if not exist "backend\uploads" mkdir backend\uploads

REM Create .env file if it doesn't exist
if not exist ".env" (
    echo [INFO] Creating .env file from template...
    copy .env.template .env
    echo [WARNING] Please edit .env file with your configuration!
    echo [WARNING] Especially Gmail API credentials and other settings
) else (
    echo [INFO] .env file already exists
)

REM Clean up any existing containers
echo [INFO] Cleaning up existing containers...
docker-compose down --remove-orphans 2>nul

REM Build and start the application
echo [INFO] Building and starting Speed-Send platform...
docker-compose build --no-cache
if %errorlevel% neq 0 (
    echo [ERROR] Failed to build containers
    pause
    exit /b 1
)

echo [INFO] Starting containers...
docker-compose up -d
if %errorlevel% neq 0 (
    echo [ERROR] Failed to start containers
    pause
    exit /b 1
)

REM Wait for services to start
echo [INFO] Waiting for services to start...
timeout /t 30 /nobreak >nul

REM Check if services are running
echo [INFO] Checking service status...
docker-compose ps

REM Show access information
echo.
echo ================================
echo   Deployment Completed!
echo ================================
echo.
echo Access URLs:
echo Frontend:    http://localhost:3000
echo Backend API: http://localhost:8000
echo API Docs:    http://localhost:8000/docs
echo.
echo Useful commands:
echo View logs:   docker-compose logs -f
echo Stop app:    docker-compose down
echo Restart:     docker-compose restart
echo.
echo [WARNING] Don't forget to configure .env file!
echo.
pause