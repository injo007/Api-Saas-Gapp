#!/usr/bin/env python3
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
            print("\n📊 Account Details:")
            for acc in accounts:
                print(f"  - {acc.get('name')} (ID: {acc.get('id')}) - Users: {acc.get('user_count', 0)}")
        else:
            print("No accounts found or API error")
    else:
        print("❌ API is not responding. Check if services are running.")
