#!/usr/bin/env python3
"""
Frontend fixes for Speed-Send Application
Fixes API calls and error handling in React components
"""

import os
from pathlib import Path

def fix_api_service():
    """Fix the API service to handle errors properly"""
    api_file = Path("services/api.ts")
    
    if not api_file.exists():
        print("❌ api.ts not found!")
        return False
    
    # Create improved API service
    new_api_content = '''const API_BASE_URL = 'http://localhost:8000/api/v1';

class ApiError extends Error {
  constructor(public status: number, public message: string, public data?: any) {
    super(message);
    this.name = 'ApiError';
  }
}

class ApiService {
  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    
    try {
      const response = await fetch(url, {
        headers: {
          'Content-Type': 'application/json',
          ...options.headers,
        },
        ...options,
      });
      
      if (!response.ok) {
        let errorMessage = `HTTP ${response.status}`;
        try {
          const errorData = await response.json();
          errorMessage = errorData.detail || errorData.message || errorMessage;
        } catch {
          errorMessage = await response.text() || errorMessage;
        }
        throw new ApiError(response.status, errorMessage);
      }
      
      // Handle 204 No Content responses
      if (response.status === 204) {
        return {} as T;
      }
      
      const contentType = response.headers.get('content-type');
      if (contentType && contentType.includes('application/json')) {
        return response.json();
      }
      
      return response.text() as unknown as T;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      
      if (error instanceof TypeError && error.message.includes('fetch')) {
        throw new ApiError(0, 'Network error: Unable to connect to server');
      }
      
      throw new ApiError(0, `Request failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  // Health check
  async checkHealth(): Promise<{ status: string }> {
    return this.request('/health');
  }

  // Account operations
  async getAccounts(includeUsers: boolean = true): Promise<Account[]> {
    return this.request(`/accounts?include_users=${includeUsers}`);
  }

  async getAccount(id: number): Promise<Account> {
    return this.request(`/accounts/${id}`);
  }

  async createAccount(formData: FormData): Promise<Account> {
    return this.request('/accounts', {
      method: 'POST',
      body: formData,
      headers: {}, // Let browser set Content-Type for FormData
    });
  }

  async updateAccount(id: number, data: { active?: boolean }): Promise<Account> {
    return this.request(`/accounts/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    });
  }

  async deleteAccount(id: number): Promise<void> {
    return this.request(`/accounts/${id}`, {
      method: 'DELETE',
    });
  }

  async syncAccountUsers(id: number): Promise<{ success: boolean; user_count: number; error?: string }> {
    return this.request(`/accounts/${id}/sync`, {
      method: 'POST',
    });
  }

  async getAccountUsers(id: number): Promise<User[]> {
    return this.request(`/accounts/${id}/users`);
  }

  // Campaign operations
  async getCampaigns(): Promise<Campaign[]> {
    return this.request('/campaigns');
  }

  async getCampaign(id: number): Promise<Campaign> {
    return this.request(`/campaigns/${id}`);
  }

  async createCampaign(data: CreateCampaignRequest): Promise<Campaign> {
    return this.request('/campaigns', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async startCampaign(id: number): Promise<void> {
    return this.request(`/campaigns/${id}/send`, {
      method: 'POST',
    });
  }

  async pauseCampaign(id: number): Promise<void> {
    return this.request(`/campaigns/${id}/pause`, {
      method: 'POST',
    });
  }
}

// Types
export interface Account {
  id: number;
  name: string;
  admin_email: string;
  active: boolean;
  user_count: number;
  daily_quota: number;
  hourly_quota: number;
  created_at: string;
  last_sync_at?: string;
  users?: User[];
}

export interface User {
  id: number;
  email: string;
  name: string;
  status: string;
  daily_sent_count: number;
  hourly_sent_count: number;
  last_sent_at?: string;
  last_error?: string;
}

export interface Campaign {
  id: number;
  name: string;
  from_name: string;
  from_email: string;
  subject: string;
  html_body: string;
  status: string;
  created_at: string;
  stats?: {
    total: number;
    sent: number;
    pending: number;
    failed: number;
  };
}

export interface CreateCampaignRequest {
  name: string;
  from_name: string;
  from_email: string;
  subject: string;
  html_body: string;
  recipients_csv: string;
}

export { ApiError };
export const api = new ApiService();
export default api;
'''
    
    with open(api_file, 'w', encoding='utf-8') as f:
        f.write(new_api_content)
    
    print("✅ Fixed API service with proper error handling")
    return True

def fix_accounts_view():
    """Fix the AccountsView component"""
    accounts_file = Path("components/views/AccountsView.tsx")
    
    if not accounts_file.exists():
        print("❌ AccountsView.tsx not found!")
        return False
    
    # Create improved AccountsView
    new_accounts_content = '''import React, { useState, useEffect } from 'react';
import { api, Account, User, ApiError } from '../../services/api';
import { useToast } from '../../contexts/ToastContext';
import Button from '../ui/Button';
import Card from '../ui/Card';
import Badge from '../ui/Badge';
import Dialog from '../ui/Dialog';
import Input from '../ui/Input';
import { TrashIcon, UsersIcon, PlusIcon } from '../icons';

const AccountsView: React.FC = () => {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showAddDialog, setShowAddDialog] = useState(false);
  const [selectedAccount, setSelectedAccount] = useState<Account | null>(null);
  const [showUsersDialog, setShowUsersDialog] = useState(false);
  const { showToast } = useToast();

  // Add account form state
  const [addForm, setAddForm] = useState({
    name: '',
    admin_email: '',
    json_file: null as File | null
  });

  useEffect(() => {
    loadAccounts();
  }, []);

  const loadAccounts = async () => {
    try {
      setLoading(true);
      setError(null);
      console.log('Loading accounts...');
      
      const accountsData = await api.getAccounts(true);
      console.log('Loaded accounts:', accountsData);
      
      setAccounts(accountsData);
      showToast('Accounts loaded successfully', 'success');
    } catch (error) {
      console.error('Error loading accounts:', error);
      const errorMessage = error instanceof ApiError 
        ? error.message 
        : 'Failed to load accounts. Please check if the server is running.';
      
      setError(errorMessage);
      showToast(errorMessage, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleAddAccount = async () => {
    if (!addForm.name || !addForm.admin_email || !addForm.json_file) {
      showToast('Please fill all fields and select a JSON file', 'error');
      return;
    }

    try {
      const formData = new FormData();
      formData.append('name', addForm.name);
      formData.append('admin_email', addForm.admin_email);
      formData.append('json_file', addForm.json_file);

      console.log('Creating account...');
      await api.createAccount(formData);
      
      showToast('Account created successfully!', 'success');
      setShowAddDialog(false);
      setAddForm({ name: '', admin_email: '', json_file: null });
      loadAccounts(); // Reload accounts
    } catch (error) {
      console.error('Error creating account:', error);
      const errorMessage = error instanceof ApiError 
        ? error.message 
        : 'Failed to create account';
      
      showToast(errorMessage, 'error');
    }
  };

  const handleDeleteAccount = async (accountId: number, accountName: string) => {
    if (!confirm(`Are you sure you want to delete account "${accountName}"? This action cannot be undone.`)) {
      return;
    }

    try {
      console.log(`Deleting account ${accountId}...`);
      await api.deleteAccount(accountId);
      
      showToast('Account deleted successfully!', 'success');
      loadAccounts(); // Reload accounts
    } catch (error) {
      console.error('Error deleting account:', error);
      const errorMessage = error instanceof ApiError 
        ? error.message 
        : 'Failed to delete account';
      
      showToast(errorMessage, 'error');
    }
  };

  const handleSyncUsers = async (accountId: number) => {
    try {
      console.log(`Syncing users for account ${accountId}...`);
      const result = await api.syncAccountUsers(accountId);
      
      if (result.success) {
        showToast(`Successfully synced ${result.user_count} users!`, 'success');
        loadAccounts(); // Reload to see updated user counts
      } else {
        showToast(`Sync failed: ${result.error}`, 'error');
      }
    } catch (error) {
      console.error('Error syncing users:', error);
      const errorMessage = error instanceof ApiError 
        ? error.message 
        : 'Failed to sync users';
      
      showToast(errorMessage, 'error');
    }
  };

  const handleToggleActive = async (accountId: number, currentActive: boolean) => {
    try {
      console.log(`Toggling account ${accountId} active status...`);
      await api.updateAccount(accountId, { active: !currentActive });
      
      showToast(`Account ${!currentActive ? 'activated' : 'deactivated'}!`, 'success');
      loadAccounts(); // Reload accounts
    } catch (error) {
      console.error('Error updating account:', error);
      const errorMessage = error instanceof ApiError 
        ? error.message 
        : 'Failed to update account';
      
      showToast(errorMessage, 'error');
    }
  };

  const showUsersDetails = (account: Account) => {
    setSelectedAccount(account);
    setShowUsersDialog(true);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg">Loading accounts...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center h-64 space-y-4">
        <div className="text-red-500 text-lg">⚠️ {error}</div>
        <Button onClick={loadAccounts}>Retry</Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Google Workspace Accounts</h1>
        <Button onClick={() => setShowAddDialog(true)} className="flex items-center space-x-2">
          <PlusIcon className="w-4 h-4" />
          <span>Add Account</span>
        </Button>
      </div>

      {accounts.length === 0 ? (
        <Card className="text-center py-8">
          <div className="text-gray-500">
            <p className="text-lg mb-2">No accounts found</p>
            <p>Add your first Google Workspace account to get started</p>
          </div>
        </Card>
      ) : (
        <div className="grid gap-4">
          {accounts.map((account) => (
            <Card key={account.id} className="p-6">
              <div className="flex justify-between items-start">
                <div className="flex-1">
                  <div className="flex items-center space-x-3 mb-2">
                    <h3 className="text-lg font-semibold">{account.name}</h3>
                    <Badge variant={account.active ? 'success' : 'secondary'}>
                      {account.active ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                  
                  <p className="text-gray-600 mb-2">
                    <strong>Admin Email:</strong> {account.admin_email}
                  </p>
                  
                  <div className="flex items-center space-x-4 text-sm text-gray-500">
                    <span>👥 {account.user_count} users</span>
                    <span>📧 {account.daily_quota}/day quota</span>
                    <span>⏰ {account.hourly_quota}/hour quota</span>
                    {account.last_sync_at && (
                      <span>🔄 Last sync: {new Date(account.last_sync_at).toLocaleDateString()}</span>
                    )}
                  </div>
                </div>
                
                <div className="flex space-x-2 ml-4">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => showUsersDetails(account)}
                    className="flex items-center space-x-1"
                  >
                    <UsersIcon className="w-4 h-4" />
                    <span>Users</span>
                  </Button>
                  
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleSyncUsers(account.id)}
                  >
                    Sync
                  </Button>
                  
                  <Button
                    size="sm"
                    variant={account.active ? "outline" : "primary"}
                    onClick={() => handleToggleActive(account.id, account.active)}
                  >
                    {account.active ? 'Deactivate' : 'Activate'}
                  </Button>
                  
                  <Button
                    size="sm"
                    variant="destructive"
                    onClick={() => handleDeleteAccount(account.id, account.name)}
                    className="flex items-center space-x-1"
                  >
                    <TrashIcon className="w-4 h-4" />
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* Add Account Dialog */}
      <Dialog isOpen={showAddDialog} onClose={() => setShowAddDialog(false)}>
        <div className="space-y-4">
          <h2 className="text-xl font-bold">Add New Account</h2>
          
          <div>
            <label className="block text-sm font-medium mb-1">Account Name</label>
            <Input
              value={addForm.name}
              onChange={(e) => setAddForm({ ...addForm, name: e.target.value })}
              placeholder="e.g., Marketing Account"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-1">Admin Email</label>
            <Input
              type="email"
              value={addForm.admin_email}
              onChange={(e) => setAddForm({ ...addForm, admin_email: e.target.value })}
              placeholder="admin@yourdomain.com"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-1">Service Account JSON</label>
            <input
              type="file"
              accept=".json"
              onChange={(e) => setAddForm({ ...addForm, json_file: e.target.files?.[0] || null })}
              className="w-full"
            />
          </div>
          
          <div className="flex space-x-2 pt-4">
            <Button onClick={handleAddAccount} className="flex-1">
              Add Account
            </Button>
            <Button variant="outline" onClick={() => setShowAddDialog(false)}>
              Cancel
            </Button>
          </div>
        </div>
      </Dialog>

      {/* Users Dialog */}
      <Dialog isOpen={showUsersDialog} onClose={() => setShowUsersDialog(false)}>
        <div className="space-y-4">
          <h2 className="text-xl font-bold">
            Users for {selectedAccount?.name}
          </h2>
          
          {selectedAccount?.users && selectedAccount.users.length > 0 ? (
            <div className="max-h-96 overflow-y-auto space-y-2">
              {selectedAccount.users.map((user) => (
                <div key={user.id} className="border rounded p-3">
                  <div className="flex justify-between items-center">
                    <div>
                      <p className="font-medium">{user.name}</p>
                      <p className="text-sm text-gray-600">{user.email}</p>
                    </div>
                    <Badge variant={user.status === 'Active' ? 'success' : 'secondary'}>
                      {user.status}
                    </Badge>
                  </div>
                  <div className="text-xs text-gray-500 mt-1">
                    Daily: {user.daily_sent_count} | Hourly: {user.hourly_sent_count}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">
              No users found. Try syncing the account.
            </p>
          )}
          
          <Button variant="outline" onClick={() => setShowUsersDialog(false)} className="w-full">
            Close
          </Button>
        </div>
      </Dialog>
    </div>
  );
};

export default AccountsView;
'''
    
    with open(accounts_file, 'w', encoding='utf-8') as f:
        f.write(new_accounts_content)
    
    print("✅ Fixed AccountsView with proper error handling and user experience")
    return True

def main():
    print("🎨 Frontend Fixes for Speed-Send")
    print("=" * 40)
    
    fix_api_service()
    fix_accounts_view()
    
    print("\n✅ Frontend fixes applied!")
    print("\nWhat was fixed:")
    print("- API service with proper error handling")
    print("- Network error detection")
    print("- User-friendly error messages")
    print("- Better loading states")
    print("- Improved account operations")
    print("- Enhanced user experience")

if __name__ == "__main__":
    main()