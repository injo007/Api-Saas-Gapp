#!/usr/bin/env python3
"""
Emergency Fix Script for Speed-Send Application
Addresses critical issues with account retrieval and deletion
"""

import os
import sys
import json
import asyncio
from pathlib import Path

def fix_crud_operations():
    """Fix CRUD operations for account management"""
    crud_file = Path("backend/crud.py")
    
    if not crud_file.exists():
        print("❌ crud.py not found!")
        return False
    
    # Read the current file
    with open(crud_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix delete_account function
    old_delete = '''def delete_account(db: Session, account_id: int) -> bool:
    """Delete account and its credentials file"""
    db_account = get_account(db, account_id)
    if db_account:
        # Delete credentials file
        if os.path.exists(db_account.credentials_path):
            os.remove(db_account.credentials_path)
        
        db.delete(db_account)
        db.commit()
        return True
    return False'''
    
    new_delete = '''def delete_account(db: Session, account_id: int) -> bool:
    """Delete account and its credentials file"""
    try:
        db_account = get_account(db, account_id)
        if not db_account:
            return False
        
        # Delete credentials file safely
        try:
            if db_account.credentials_path and os.path.exists(db_account.credentials_path):
                os.remove(db_account.credentials_path)
        except Exception as e:
            print(f"Warning: Could not delete credentials file: {e}")
        
        # Delete all related users first (cascade should handle this, but being explicit)
        db.query(User).filter(User.account_id == account_id).delete()
        
        # Delete the account
        db.delete(db_account)
        db.commit()
        
        print(f"Successfully deleted account {account_id}")
        return True
    
    except Exception as e:
        db.rollback()
        print(f"Error deleting account {account_id}: {e}")
        return False'''
    
    # Fix get_account_users function to handle errors
    old_users = '''def get_account_users(db: Session, account_id: int) -> List[User]:
    """Get all users for an account"""
    return db.query(User).filter(User.account_id == account_id).all()'''
    
    new_users = '''def get_account_users(db: Session, account_id: int) -> List[User]:
    """Get all users for an account"""
    try:
        # Verify account exists first
        account = get_account(db, account_id)
        if not account:
            print(f"Account {account_id} not found")
            return []
        
        users = db.query(User).filter(User.account_id == account_id).all()
        print(f"Retrieved {len(users)} users for account {account_id}")
        return users
    
    except Exception as e:
        print(f"Error retrieving users for account {account_id}: {e}")
        return []'''
    
    # Apply fixes
    content = content.replace(old_delete, new_delete)
    content = content.replace(old_users, new_users)
    
    # Write back to file
    with open(crud_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Fixed CRUD operations")
    return True

def fix_database_connection():
    """Add better error handling for database connections"""
    db_file = Path("backend/database.py")
    
    if not db_file.exists():
        print("❌ database.py not found!")
        return False
    
    with open(db_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add better error handling
    if "def get_db() -> Session:" in content:
        old_get_db = '''def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()'''
        
        new_get_db = '''def get_db() -> Session:
    db = None
    try:
        db = SessionLocal()
        # Test connection
        db.execute(text("SELECT 1"))
        yield db
    except Exception as e:
        logger.error(f"Database connection error: {e}")
        if db:
            db.rollback()
        raise
    finally:
        if db:
            db.close()'''
        
        content = content.replace(old_get_db, new_get_db)
        
        with open(db_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print("✅ Fixed database connection handling")
    
    return True

def create_deployment_fix_script():
    """Create a deployment fix script for Ubuntu"""
    script_content = '''#!/bin/bash
# Emergency deployment fix for Ubuntu Server 22

echo "🔧 Starting emergency fix for Speed-Send application..."

# Stop existing services
echo "Stopping existing services..."
sudo docker-compose down 2>/dev/null || true

# Create uploads directory
mkdir -p uploads
chmod 755 uploads

# Fix permissions
sudo chown -R $USER:$USER .
chmod +x deploy.sh

# Install/update Docker if needed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Clean up any existing containers
echo "Cleaning up existing containers..."
sudo docker system prune -f

# Build and start services
echo "Building and starting services..."
sudo docker-compose up --build -d

# Wait for database
echo "Waiting for database to be ready..."
sleep 30

# Run database migrations
echo "Running database migrations..."
sudo docker-compose exec backend alembic upgrade head

echo "✅ Fix completed! Check status with: sudo docker-compose ps"
'''
    
    with open("tmp_rovodev_ubuntu_fix.sh", 'w') as f:
        f.write(script_content)
    
    os.chmod("tmp_rovodev_ubuntu_fix.sh", 0o755)
    print("✅ Created Ubuntu deployment fix script")

def create_account_test_script():
    """Create a test script for account operations"""
    test_content = '''#!/usr/bin/env python3
"""
Test script for account operations
"""
import requests
import json

API_BASE = "http://localhost:8000/api/v1"

def test_api_health():
    try:
        response = requests.get(f"{API_BASE}/health")
        print(f"API Health: {response.status_code}")
        return response.status_code == 200
    except Exception as e:
        print(f"API Health Check Failed: {e}")
        return False

def test_get_accounts():
    try:
        response = requests.get(f"{API_BASE}/accounts")
        print(f"Get Accounts: {response.status_code}")
        if response.status_code == 200:
            accounts = response.json()
            print(f"Found {len(accounts)} accounts")
            return accounts
        else:
            print(f"Error: {response.text}")
    except Exception as e:
        print(f"Get Accounts Failed: {e}")
    return []

def test_delete_account(account_id):
    try:
        response = requests.delete(f"{API_BASE}/accounts/{account_id}")
        print(f"Delete Account {account_id}: {response.status_code}")
        return response.status_code == 204
    except Exception as e:
        print(f"Delete Account Failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Testing Speed-Send API...")
    
    if test_api_health():
        accounts = test_get_accounts()
        
        if accounts:
            print("\\n📊 Account Details:")
            for acc in accounts:
                print(f"  - {acc.get('name')} (ID: {acc.get('id')}) - Users: {acc.get('user_count', 0)}")
        else:
            print("No accounts found or API error")
    else:
        print("❌ API is not responding. Check if services are running.")
'''
    
    with open("tmp_rovodev_test_api.py", 'w') as f:
        f.write(test_content)
    
    print("✅ Created API test script")

def main():
    print("🚀 Speed-Send Emergency Fix Script")
    print("=" * 50)
    
    # Apply fixes
    fix_crud_operations()
    fix_database_connection()
    create_deployment_fix_script()
    create_account_test_script()
    
    print("\n📋 Next Steps:")
    print("1. For Ubuntu Server deployment:")
    print("   chmod +x tmp_rovodev_ubuntu_fix.sh")
    print("   ./tmp_rovodev_ubuntu_fix.sh")
    print("\n2. Test the API:")
    print("   python3 tmp_rovodev_test_api.py")
    print("\n3. Check logs:")
    print("   sudo docker-compose logs backend")
    print("   sudo docker-compose logs frontend")

if __name__ == "__main__":
    main()