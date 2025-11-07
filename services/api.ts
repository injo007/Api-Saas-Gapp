

import { Account, AccountWithUsers, Campaign, CampaignCreatePayload, CampaignDetail, 
         CampaignPreparation, SendingProgress, AccountValidation, AccountValidationResult,
         User } from '../types';

const API_BASE_URL = '/api/v1'; // Updated to include /v1 for the backend API

// Function to handle API responses, optionally takes a toast function for global notifications
async function handleResponse<T>(response: Response, addToast?: (options: { message: string; type: 'success' | 'error' | 'info' }) => void): Promise<T> {
  if (!response.ok) {
    const errorData = await response.json().catch(() => ({ detail: 'An unknown error occurred' }));
    const errorMessage = errorData.detail || `HTTP error! status: ${response.status}`;
    if (addToast) {
      addToast({ message: errorMessage, type: 'error' });
    }
    throw new Error(errorMessage);
  }
  return response.json();
}

// Wrapper to pass the addToast function to handleResponse
// This needs to be called within a component that has access to useToast
export const createApiWithToast = (addToast: (options: { message: string; type: 'success' | 'error' | 'info' }) => void) => {
  return {
    // Account API
    getAccounts: (includeUsers: boolean = true): Promise<AccountWithUsers[]> => {
      return fetch(`${API_BASE_URL}/accounts?include_users=${includeUsers}`).then(res => handleResponse<AccountWithUsers[]>(res, addToast));
    },

    addAccount: (formData: FormData): Promise<Account> => {
      return new Promise((resolve, reject) => {
        const name = formData.get('name') as string;
        const adminEmail = formData.get('admin_email') as string;
        const jsonFile = formData.get('json_file') as File;
        
        if (!jsonFile) {
          reject(new Error('JSON file is required'));
          return;
        }
        
        const reader = new FileReader();
        reader.onload = () => {
          try {
            const credentialsJson = reader.result as string;
            // Validate JSON format
            JSON.parse(credentialsJson);
            
            fetch(`${API_BASE_URL}/accounts`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                name: name,
                admin_email: adminEmail,
                credentials_json: credentialsJson
              }),
            })
            .then(res => handleResponse<Account>(res, addToast))
            .then(resolve)
            .catch(reject);
          } catch (error) {
            reject(new Error('Invalid JSON file format'));
          }
        };
        reader.onerror = () => reject(new Error('Failed to read JSON file'));
        reader.readAsText(jsonFile);
      });
    },

    validateAccount: (validation: AccountValidation): Promise<AccountValidationResult> => {
      return fetch(`${API_BASE_URL}/accounts/validate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(validation),
      }).then(res => handleResponse<AccountValidationResult>(res, addToast));
    },

    syncAccountUsers: (accountId: number): Promise<any> => {
      return fetch(`${API_BASE_URL}/accounts/${accountId}/sync`, {
        method: 'POST',
      }).then(res => handleResponse<any>(res, addToast));
    },

    getAccountUsers: (accountId: number): Promise<User[]> => {
      return fetch(`${API_BASE_URL}/accounts/${accountId}/users`).then(res => handleResponse<User[]>(res, addToast));
    },

    deleteAccount: (accountId: number): Promise<void> => { // Changed return type to void
      return fetch(`${API_BASE_URL}/accounts/${accountId}`, {
        method: 'DELETE',
      }).then(res => handleResponse<void>(res, addToast)); // Expecting no content or a simple success message
    },

    toggleAccountStatus: (accountId: number, active: boolean): Promise<Account> => {
        return fetch(`${API_BASE_URL}/accounts/${accountId}`, {
            method: 'PATCH',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ active: active }),
        }).then(res => handleResponse<Account>(res, addToast));
    },

    // Campaign API
    getCampaigns: (): Promise<Campaign[]> => {
        return fetch(`${API_BASE_URL}/campaigns`).then(res => handleResponse<Campaign[]>(res, addToast));
    },

    getCampaign: (campaignId: number): Promise<CampaignDetail> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}`).then(res => handleResponse<CampaignDetail>(res, addToast));
    },

    createCampaign: (payload: CampaignCreatePayload): Promise<Campaign> => {
        return fetch(`${API_BASE_URL}/campaigns`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload),
        }).then(res => handleResponse<Campaign>(res, addToast));
    },

    sendCampaign: (campaignId: number): Promise<Campaign> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}/send`, {
            method: 'POST',
        }).then(res => handleResponse<Campaign>(res, addToast));
    },

    pauseCampaign: (campaignId: number): Promise<Campaign> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}/pause`, {
            method: 'POST',
        }).then(res => handleResponse<Campaign>(res, addToast));
    },

    prepareCampaign: (campaignId: number, selectedAccounts: number[]): Promise<CampaignPreparation> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}/prepare`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(selectedAccounts),
        }).then(res => handleResponse<CampaignPreparation>(res, addToast));
    },

    sendCampaignUltraFast: (campaignId: number, useThreading: boolean = true): Promise<any> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}/send-ultra-fast?use_threading=${useThreading}`, {
            method: 'POST',
        }).then(res => handleResponse<any>(res, addToast));
    },

    sendTestEmail: (campaignId: number, testEmail: string): Promise<any> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}/test-email`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                campaign_id: campaignId,
                test_email: testEmail
            }),
        }).then(res => handleResponse<any>(res, addToast));
    },

    getCampaignProgress: (campaignId: number): Promise<SendingProgress> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}/progress`).then(res => handleResponse<SendingProgress>(res, addToast));
    },

    getCampaignAssignments: (campaignId: number): Promise<any> => {
        return fetch(`${API_BASE_URL}/campaigns/${campaignId}/assignments`).then(res => handleResponse<any>(res, addToast));
    },

    // Additional API endpoints for new features
    deleteCampaign: (campaignId: number): Promise<void> => {
      return fetch(`${API_BASE_URL}/campaigns/${campaignId}`, {
        method: 'DELETE',
      }).then(res => handleResponse<void>(res, addToast));
    },

    bulkDelete: (type: 'campaigns' | 'recipients'): Promise<void> => {
      return fetch(`${API_BASE_URL}/bulk-delete/${type}`, {
        method: 'DELETE',
      }).then(res => handleResponse<void>(res, addToast));
    },

    getAnalytics: (timeRange?: string): Promise<any> => {
      const params = timeRange ? `?range=${timeRange}` : '';
      return fetch(`${API_BASE_URL}/analytics${params}`).then(res => handleResponse<any>(res, addToast));
    },

    exportAnalytics: (format: 'json' | 'csv' = 'json'): Promise<Blob> => {
      return fetch(`${API_BASE_URL}/analytics/export?format=${format}`)
        .then(res => {
          if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
          return res.blob();
        });
    },

    getSystemStats: (): Promise<any> => {
      return fetch(`${API_BASE_URL}/system/stats`).then(res => handleResponse<any>(res, addToast));
    },

    validateTemplate: (template: string, testData: any): Promise<{ valid: boolean; rendered?: string; error?: string }> => {
      return fetch(`${API_BASE_URL}/templates/validate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ template, test_data: testData }),
      }).then(res => handleResponse<any>(res, addToast));
    },

    testConnection: (accountId: number): Promise<{ success: boolean; message: string; details?: any }> => {
      return fetch(`${API_BASE_URL}/accounts/${accountId}/test-connection`, {
        method: 'POST',
      }).then(res => handleResponse<any>(res, addToast));
    },
  };
};

// Default export if you don't need toast for some isolated calls (less recommended for this app)
// For most app usage, components should import `createApiWithToast` and use the returned object.
// This default export is provided for backward compatibility but might not provide toast feedback.
// In App.tsx, we will create the `api` object using `createApiWithToast`.
export const { 
    getAccounts, 
    addAccount, 
    deleteAccount, 
    toggleAccountStatus,
    getCampaigns, 
    getCampaign, 
    createCampaign, 
    sendCampaign, 
    pauseCampaign 
} = createApiWithToast(() => {}); // Dummy toast function for default export