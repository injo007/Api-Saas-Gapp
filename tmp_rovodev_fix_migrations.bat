@echo off
REM Database migration fix for Windows
echo 🔧 Fixing Speed-Send Database Migration Issues...

echo.
echo ✅ Fixed alembic.ini configuration file
echo ✅ Created database initialization scripts

echo.
echo 📋 FOR YOUR UBUNTU SERVER 22, run these commands:
echo.
echo # 1. Quick Fix (Recommended):
echo chmod +x tmp_rovodev_quick_fix.sh
echo ./tmp_rovodev_quick_fix.sh
echo.
echo # 2. Alternative - Manual Steps:
echo docker-compose down
echo docker-compose up -d db redis
echo sleep 15
echo docker-compose run --rm backend python -c "from database import engine, Base; from models import *; Base.metadata.create_all(bind=engine); print('Database created')"
echo docker-compose up -d
echo.
echo 🎯 This will bypass the Alembic migration issues and create tables directly from your SQLAlchemy models.

pause