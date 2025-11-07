@echo off
echo ================================
echo   Speed-Send Frontend Fix
echo ================================
echo.

REM Stop the frontend container
echo Stopping frontend container...
docker-compose stop frontend

REM Remove the frontend container and image
echo Removing old frontend container and image...
docker-compose rm -f frontend
for /f "tokens=*" %%i in ('docker images -q speedsend_frontend 2^>nul') do docker rmi %%i 2>nul

REM Rebuild the frontend
echo Rebuilding frontend with proper build process...
docker-compose build --no-cache frontend

REM Start the frontend
echo Starting frontend container...
docker-compose up -d frontend

REM Wait a moment for startup
echo Waiting for frontend to start...
timeout /t 10 /nobreak >nul

REM Check status
echo Checking container status...
docker-compose ps frontend

echo.
echo Frontend fix completed!
echo Access your application at: http://localhost:3000
echo.
echo If you still see issues, check the logs with:
echo docker-compose logs frontend
echo.
pause