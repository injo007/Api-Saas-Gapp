

import React, { useState, useRef } from 'react';
import { Account } from '../../types';
import Button from '../ui/Button';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Input from '../ui/Input';
import PlusIcon from '../icons/PlusIcon';
import TrashIcon from '../icons/TrashIcon';
import { useToast } from '../../contexts/ToastContext';
import { useDialog } from '../../contexts/DialogContext';

interface AccountsViewProps {
  accounts: Account[];
  onAddAccount: (formData: FormData) => Promise<void>;
  onDeleteAccount: (accountId: number) => Promise<void>;
  onToggleAccountStatus: (accountId: number) => Promise<void>;
  isLoadingAccounts: boolean; // New prop for loading state
  errorLoadingAccounts: string | null; // New prop for error state
}

const AccountsView: React.FC<AccountsViewProps> = ({ 
  accounts, 
  onAddAccount, 
  onDeleteAccount, 
  onToggleAccountStatus,
  isLoadingAccounts,
  errorLoadingAccounts,
}) => {
  const [name, setName] = useState('');
  const [adminEmail, setAdminEmail] = useState('');
  const [jsonFile, setJsonFile] = useState<File | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState<{ name?: string; adminEmail?: string; jsonFile?: string }>({});

  const fileInputRef = useRef<HTMLInputElement>(null);
  const { addToast } = useToast();
  const { openDialog } = useDialog();

  const validateForm = () => {
    const newErrors: typeof errors = {};
    if (!name.trim()) newErrors.name = 'Account Name is required.';
    if (!adminEmail.trim()) {
      newErrors.adminEmail = 'Admin Email is required.';
    } else if (!/\S+@\S+\.\S+/.test(adminEmail)) {
      newErrors.adminEmail = 'Invalid email format.';
    }
    if (!jsonFile) newErrors.jsonFile = 'Service Account JSON file is required.';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setJsonFile(e.target.files[0]);
      setErrors(prev => ({ ...prev, jsonFile: undefined }));
    } else {
      setJsonFile(null);
    }
  };

  const handleAddAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validateForm()) return;

    setIsSubmitting(true);
    try {
      const formData = new FormData();
      formData.append('name', name);
      formData.append('admin_email', adminEmail);
      if (jsonFile) {
        formData.append('json_file', jsonFile);
      }
      
      await onAddAccount(formData);
      addToast({ message: `Account "${name}" added successfully!`, type: 'success' });
      
      // Reset form
      setName('');
      setAdminEmail('');
      setJsonFile(null);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
      setErrors({});
    } catch (err) {
      addToast({ message: `Failed to add account: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error' });
      console.error(err);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = (account: Account) => {
    openDialog({
      title: 'Delete Account',
      message: `Are you sure you want to delete account "${account.name}" (${account.admin_email})? This action cannot be undone.`,
      onConfirm: async () => {
        try {
          await onDeleteAccount(account.id);
          addToast({ message: `Account "${account.name}" deleted successfully!`, type: 'success' });
        } catch (error) {
          addToast({ message: `Failed to delete account "${account.name}". ${error instanceof Error ? error.message : ''}`, type: 'error' });
        }
      },
    });
  };

  const handleToggleStatus = async (account: Account) => {
    try {
      await onToggleAccountStatus(account.id);
      addToast({ 
        message: `Account "${account.name}" status updated to ${account.active ? 'Inactive' : 'Active'}.`, 
        type: 'success' 
      });
    } catch (error) {
      addToast({ 
        message: `Failed to update account status for "${account.name}". ${error instanceof Error ? error.message : ''}`, 
        type: 'error' 
      });
    }
  };

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Sender Accounts</h1>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <Card>
            <CardHeader title="Connected Accounts" />
            <CardContent>
              {isLoadingAccounts && (
                <p className="text-center text-gray-500 dark:text-gray-400">Loading accounts...</p>
              )}
              {errorLoadingAccounts && (
                <p className="text-center text-red-500 dark:text-red-400">Error loading accounts: {errorLoadingAccounts}</p>
              )}
              {!isLoadingAccounts && !errorLoadingAccounts && accounts.length === 0 ? (
                <p className="text-center text-gray-500 dark:text-gray-400 py-4">No accounts connected yet. Add one to get started.</p>
              ) : (
                <ul className="divide-y divide-gray-200 dark:divide-gray-700">
                  {accounts.map(account => (
                    <li key={account.id} className="py-4 flex flex-col sm:flex-row items-start sm:items-center justify-between">
                      <div className="mb-2 sm:mb-0">
                        <p className="text-base font-medium text-gray-900 dark:text-white">{account.name}</p>
                        <p className="text-sm text-gray-500 dark:text-gray-400">{account.admin_email}</p>
                      </div>
                      <div className="flex items-center space-x-4">
                        <label className="relative inline-flex items-center cursor-pointer">
                          <input type="checkbox" checked={account.active} onChange={() => handleToggleStatus(account)} className="sr-only peer" />
                          <div className="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-primary-300 dark:peer-focus:ring-primary-800 dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-primary-600"></div>
                          <span className="ml-3 text-sm font-medium text-gray-900 dark:text-gray-300">{account.active ? 'Active' : 'Inactive'}</span>
                        </label>
                        <Button variant="danger" onClick={() => handleDelete(account)} className="px-2 py-1">
                          <TrashIcon className="w-4 h-4" />
                        </Button>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </div>
        
        <div>
          <Card>
            <CardHeader title="Add New Account" />
            <form onSubmit={handleAddAccount}>
              <CardContent className="space-y-4">
                <Input
                  label="Account Name"
                  id="accountName"
                  value={name}
                  onChange={e => {setName(e.target.value); setErrors(prev => ({ ...prev, name: undefined }));}}
                  placeholder="e.g., Workspace Account 1"
                  required
                  error={errors.name}
                />
                <Input
                  label="Admin Email (for delegation)"
                  id="adminEmail"
                  type="email"
                  value={adminEmail}
                  onChange={e => {setAdminEmail(e.target.value); setErrors(prev => ({ ...prev, adminEmail: undefined }));}}
                  placeholder="admin@yourdomain.com"
                  required
                  error={errors.adminEmail}
                />
                <div>
                  <label htmlFor="jsonFile" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Service Account JSON</label>
                  <input
                    id="jsonFile"
                    type="file"
                    ref={fileInputRef}
                    onChange={handleFileChange}
                    accept=".json"
                    className={`block w-full text-sm text-gray-900 border ${errors.jsonFile ? 'border-red-500' : 'border-gray-300'} rounded-lg cursor-pointer bg-gray-50 dark:text-gray-400 focus:outline-none dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-primary-50 file:text-primary-700 hover:file:bg-primary-100`}
                    required
                  />
                  {errors.jsonFile && <p className="mt-1 text-sm text-red-600 dark:text-red-400">{errors.jsonFile}</p>}
                  <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">Credentials will be encrypted at rest.</p>
                </div>
              </CardContent>
              <div className="p-4 bg-gray-50 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700">
                <Button type="submit" className="w-full" disabled={isSubmitting}>
                  {isSubmitting ? (
                    <span className="flex items-center">
                      <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Adding...
                    </span>
                  ) : (
                    <>
                      <PlusIcon className="w-5 h-5 mr-2" />
                      Add Account
                    </>
                  )}
                </Button>
              </div>
            </form>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default AccountsView;