@echo off
REM Build frontend for production

echo Building frontend for production...

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js is not installed. Please install Node.js first.
    pause
    exit /b 1
)

REM Check if npm is installed
npm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo npm is not installed. Please install npm first.
    pause
    exit /b 1
)

REM Install dependencies if node_modules doesn't exist
if not exist "node_modules" (
    echo Installing dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Build the project
echo Building the project...
npm run build

if %errorlevel% equ 0 (
    echo Frontend build completed successfully!
    echo Built files are in the 'dist' directory
    if exist "dist\" (
        dir dist\
    ) else (
        echo dist directory not found
    )
) else (
    echo Frontend build failed!
    pause
    exit /b 1
)

pause