

import React, { useState, useEffect, useCallback } from 'react';
import Header from './components/layout/Header';
import Sidebar from './components/layout/Sidebar';
import DashboardView from './components/views/DashboardView';
import AccountsView from './components/views/AccountsView';
import CreateCampaignView from './components/views/CreateCampaignView';
import CampaignDetailView from './components/views/CampaignDetailView';
import UltraFastSendView from './components/views/UltraFastSendView';
import Layout from './components/layout/Layout'; // New Layout component
import { Account, Campaign, CampaignCreatePayload, CampaignStatus } from './types';
import { createApiWithToast } from './services/api'; // Use the new factory
import { useToast } from './contexts/ToastContext';

export type View = 'DASHBOARD' | 'ACCOUNTS' | 'CREATE_CAMPAIGN' | 'CAMPAIGN_DETAIL' | 'ULTRA_FAST_SEND';

const App: React.FC = () => {
  const [view, setView] = useState<View>('DASHBOARD');
  const [selectedCampaignId, setSelectedCampaignId] = useState<number | null>(null);

  const [accounts, setAccounts] = useState<Account[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  
  const [isLoadingAccounts, setIsLoadingAccounts] = useState(true);
  const [errorLoadingAccounts, setErrorLoadingAccounts] = useState<string | null>(null);
  
  const [isLoadingCampaigns, setIsLoadingCampaigns] = useState(true);
  const [errorLoadingCampaigns, setErrorLoadingCampaigns] = useState<string | null>(null);

  const { addToast } = useToast();
  
  // Create API instance once with useMemo to prevent infinite re-renders
  const api = React.useMemo(() => createApiWithToast(addToast), [addToast]);

  const fetchAccounts = useCallback(async () => {
    setIsLoadingAccounts(true);
    setErrorLoadingAccounts(null);
    try {
      const data = await api.getAccounts();
      setAccounts(data);
    } catch (err) {
      setErrorLoadingAccounts(err instanceof Error ? err.message : 'An unknown error occurred');
      addToast({message: `Failed to load accounts: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error'});
    } finally {
      setIsLoadingAccounts(false);
    }
  }, [api, addToast]);

  const fetchCampaigns = useCallback(async () => {
    setIsLoadingCampaigns(true);
    setErrorLoadingCampaigns(null);
    try {
      const data = await api.getCampaigns();
      setCampaigns(data);
    } catch (err) {
      setErrorLoadingCampaigns(err instanceof Error ? err.message : 'An unknown error occurred');
      addToast({message: `Failed to load campaigns: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error'});
    } finally {
      setIsLoadingCampaigns(false);
    }
  }, [api, addToast]);

  // Initial data fetch
  useEffect(() => {
    fetchAccounts();
    fetchCampaigns();
  }, [fetchAccounts, fetchCampaigns]);

  // Polling for active campaigns
  useEffect(() => {
    let pollInterval: number | undefined;
    
    const isAnyCampaignSending = campaigns.some(c => c.status === CampaignStatus.SENDING);

    if (isAnyCampaignSending) {
        pollInterval = window.setInterval(async () => {
            try {
                // Only poll campaigns, not accounts, for performance
                const campaignsData = await api.getCampaigns();
                setCampaigns(campaignsData);
            } catch (error) {
                console.error("Failed to poll for campaign updates:", error);
                // Don't show toast for polling errors to avoid spam
            }
        }, 10000); // Poll every 10 seconds (reduced frequency)
    }

    return () => {
      if (pollInterval) {
        clearInterval(pollInterval);
      }
    };
  }, [campaigns.some(c => c.status === CampaignStatus.SENDING), api]); // Only depend on whether any campaign is sending


  const handleAddAccount = async (formData: FormData) => {
    try {
      const newAccount = await api.addAccount(formData);
      setAccounts(prev => [...prev, newAccount]);
      // Don't show toast here - AccountsView will handle it
    } catch (err) {
      console.error('Failed to add account:', err);
      throw err; // Re-throw to allow component to handle its own loading/error state
    }
  };

  const handleDeleteAccount = async (accountId: number) => {
    try {
        await api.deleteAccount(accountId);
        setAccounts(prev => prev.filter(acc => acc.id !== accountId));
        addToast({ message: 'Account deleted successfully!', type: 'success' });
    } catch (err) {
        addToast({ message: `Failed to delete account: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error' });
        console.error(err);
        throw err;
    }
  };

  const handleToggleAccountStatus = async (accountId: number) => {
    const account = accounts.find(acc => acc.id === accountId);
    if (!account) {
        addToast({ message: 'Account not found.', type: 'error' });
        return;
    }
    try {
        const updatedAccount = await api.toggleAccountStatus(accountId, !account.active);
        setAccounts(prev =>
          prev.map(acc => (acc.id === accountId ? updatedAccount : acc))
        );
        addToast({ message: `Account "${updatedAccount.name}" status updated to ${updatedAccount.active ? 'Active' : 'Inactive'}.`, type: 'success' });
    } catch (err) {
         addToast({ message: `Failed to update account status: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error' });
         console.error(err);
         throw err;
    }
  };

  const handleSaveCampaign = async (campaignPayload: CampaignCreatePayload) => {
    try {
        const newCampaign = await api.createCampaign(campaignPayload);
        setCampaigns(prev => [newCampaign, ...prev]);
        setView('DASHBOARD');
        addToast({ message: `Campaign "${newCampaign.name}" created successfully!`, type: 'success' });
    } catch (err) {
        addToast({ message: `Failed to create campaign: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error' });
        console.error(err);
        throw err;
    }
  };

  const handleViewCampaign = (campaignId: number) => {
    setSelectedCampaignId(campaignId);
    setView('CAMPAIGN_DETAIL');
  }
  
  const handleToggleCampaignStatus = async (campaignId: number, newStatus: CampaignStatus) => {
    const campaign = campaigns.find(c => c.id === campaignId);
    if (!campaign) {
        addToast({ message: 'Campaign not found.', type: 'error' });
        return;
    }

    try {
      if (newStatus === CampaignStatus.SENDING) {
        await api.sendCampaign(campaignId);
      } else if (newStatus === CampaignStatus.PAUSED) {
        await api.pauseCampaign(campaignId);
      }
      // Optimistically update status
      setCampaigns(prev => prev.map(c => 
        c.id === campaignId ? { ...c, status: newStatus } : c
      ));
      fetchCampaigns(); // Refetch data to get the latest status and stats
    } catch (err) {
        addToast({ message: `Failed to update campaign status: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error' });
        console.error(err);
        throw err;
    }
  };

  const renderView = () => {
    // Global loading/error state if all data is fetching, or specific view has its own
    const isLoadingGlobal = isLoadingAccounts || isLoadingCampaigns;
    const errorGlobal = errorLoadingAccounts || errorLoadingCampaigns;

    if (isLoadingGlobal && view !== 'CAMPAIGN_DETAIL') { // CAMPAIGN_DETAIL handles its own loading
        return (
            <div className="p-8 text-center text-gray-700 dark:text-gray-300">
                <svg className="animate-spin h-8 w-8 text-primary-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Loading application data...
            </div>
        );
    }
    if (errorGlobal && view !== 'CAMPAIGN_DETAIL') {
        return <div className="p-8 text-center text-red-500">Error: {errorGlobal}. Please check the backend console for more details.</div>;
    }

    switch (view) {
      case 'DASHBOARD':
        return <DashboardView 
                    campaigns={campaigns} 
                    onCreateCampaign={() => setView('CREATE_CAMPAIGN')}
                    onViewCampaign={handleViewCampaign}
                    onToggleCampaign={handleToggleCampaignStatus}
                    isLoadingCampaigns={isLoadingCampaigns}
                    errorLoadingCampaigns={errorLoadingCampaigns}
                />;
      case 'ACCOUNTS':
        return <AccountsView 
                    accounts={accounts} 
                    onAddAccount={handleAddAccount}
                    onDeleteAccount={handleDeleteAccount}
                    onToggleAccountStatus={handleToggleAccountStatus}
                    isLoadingAccounts={isLoadingAccounts}
                    errorLoadingAccounts={errorLoadingAccounts}
                />;
      case 'CREATE_CAMPAIGN':
        return <CreateCampaignView onBack={() => setView('DASHBOARD')} onSaveCampaign={handleSaveCampaign} />;
      case 'CAMPAIGN_DETAIL':
        if (selectedCampaignId === null) {
            setView('DASHBOARD'); // Fallback if no campaign ID is set for detail view
            return null;
        }
        return <CampaignDetailView campaignId={selectedCampaignId} onBack={() => setView('DASHBOARD')} />;
      case 'ULTRA_FAST_SEND':
        return <UltraFastSendView />;
      default:
        // Default to Dashboard if view is somehow unset
        return <DashboardView 
                    campaigns={campaigns} 
                    onCreateCampaign={() => setView('CREATE_CAMPAIGN')} 
                    onViewCampaign={handleViewCampaign} 
                    onToggleCampaign={handleToggleCampaignStatus}
                    isLoadingCampaigns={isLoadingCampaigns}
                    errorLoadingCampaigns={errorLoadingCampaigns}
                />;
    }
  };

  const handleSetView = useCallback((newView: View) => {
    setView(newView);
    setSelectedCampaignId(null); // Reset selected campaign when changing views
  }, []);

  return (
    <Layout currentView={view} setView={handleSetView}>
      {renderView()}
    </Layout>
  );
};

export default App;