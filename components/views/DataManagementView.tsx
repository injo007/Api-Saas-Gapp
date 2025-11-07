import React, { useState, useEffect, useCallback } from 'react';
import { Account, Campaign, User, Recipient, CampaignStats } from '../../types';
import { createApiWithToast } from '../../services/api';
import { useToast } from '../../contexts/ToastContext';
import { useDialog } from '../../contexts/DialogContext';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Button from '../ui/Button';
import Badge from '../ui/Badge';
import TrashIcon from '../icons/TrashIcon';

interface DataManagementViewProps {}

interface DatabaseStats {
  totalAccounts: number;
  totalUsers: number;
  totalCampaigns: number;
  totalRecipients: number;
  activeCampaigns: number;
  completedCampaigns: number;
}

const DataManagementView: React.FC<DataManagementViewProps> = () => {
  const [stats, setStats] = useState<DatabaseStats | null>(null);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [selectedAccount, setSelectedAccount] = useState<number | null>(null);
  const [accountUsers, setAccountUsers] = useState<User[]>([]);
  const [selectedCampaign, setSelectedCampaign] = useState<number | null>(null);
  const [campaignRecipients, setCampaignRecipients] = useState<Recipient[]>([]);
  
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'overview' | 'accounts' | 'campaigns' | 'recipients'>('overview');

  const { addToast } = useToast();
  const { openDialog } = useDialog();
  const api = React.useMemo(() => createApiWithToast(addToast), [addToast]);

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      const [accountsData, campaignsData] = await Promise.all([
        api.getAccounts(true),
        api.getCampaigns()
      ]);
      
      setAccounts(accountsData);
      setCampaigns(campaignsData);
      
      // Calculate stats
      const totalUsers = accountsData.reduce((sum, acc) => sum + acc.user_count, 0);
      const totalRecipients = campaignsData.reduce((sum, campaign) => sum + campaign.stats.total, 0);
      const activeCampaigns = campaignsData.filter(c => ['Sending', 'Preparing', 'Ready'].includes(c.status)).length;
      const completedCampaigns = campaignsData.filter(c => c.status === 'Completed').length;
      
      setStats({
        totalAccounts: accountsData.length,
        totalUsers,
        totalCampaigns: campaignsData.length,
        totalRecipients,
        activeCampaigns,
        completedCampaigns
      });
    } catch (error) {
      addToast({ message: 'Failed to load data management information', type: 'error' });
    } finally {
      setLoading(false);
    }
  }, [api, addToast]);

  const loadAccountUsers = async (accountId: number) => {
    try {
      const users = await api.getAccountUsers(accountId);
      setAccountUsers(users);
      setSelectedAccount(accountId);
    } catch (error) {
      addToast({ message: 'Failed to load account users', type: 'error' });
    }
  };

  const loadCampaignRecipients = async (campaignId: number) => {
    try {
      const campaign = await api.getCampaign(campaignId);
      setCampaignRecipients(campaign.recipients);
      setSelectedCampaign(campaignId);
    } catch (error) {
      addToast({ message: 'Failed to load campaign recipients', type: 'error' });
    }
  };

  const handleDeleteCampaign = (campaign: Campaign) => {
    openDialog({
      title: 'Delete Campaign',
      message: `Are you sure you want to delete campaign "${campaign.name}"? This will also delete all associated recipients and cannot be undone.`,
      onConfirm: async () => {
        try {
          await api.deleteCampaign(campaign.id);
          setCampaigns(prev => prev.filter(c => c.id !== campaign.id));
          addToast({ message: `Campaign "${campaign.name}" deleted successfully`, type: 'success' });
          await fetchData(); // Refresh stats
        } catch (error) {
          addToast({ message: 'Failed to delete campaign', type: 'error' });
        }
      }
    });
  };

  const handleBulkDelete = (type: 'campaigns' | 'recipients') => {
    const confirmMessage = type === 'campaigns' 
      ? 'Delete ALL campaigns and their recipients? This cannot be undone!'
      : 'Delete ALL recipients from ALL campaigns? This cannot be undone!';
    
    openDialog({
      title: `Bulk Delete ${type.charAt(0).toUpperCase() + type.slice(1)}`,
      message: confirmMessage,
      onConfirm: async () => {
        try {
          await api.bulkDelete(type);
          addToast({ message: `All ${type} deleted successfully`, type: 'success' });
          await fetchData();
        } catch (error) {
          addToast({ message: `Failed to bulk delete ${type}`, type: 'error' });
        }
      }
    });
  };

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  if (loading) {
    return (
      <div className="p-4 sm:p-6 lg:p-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/3 mb-6"></div>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-24 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Data Management</h1>
        <Button 
          variant="danger" 
          onClick={() => handleBulkDelete('campaigns')}
          className="text-sm"
        >
          <TrashIcon className="w-4 h-4 mr-2" />
          Bulk Operations
        </Button>
      </div>

      {/* Stats Overview */}
      {stats && (
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold text-primary-600">{stats.totalAccounts}</div>
              <p className="text-sm text-gray-500">Total Accounts</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold text-green-600">{stats.totalUsers}</div>
              <p className="text-sm text-gray-500">Total Users</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold text-blue-600">{stats.totalCampaigns}</div>
              <p className="text-sm text-gray-500">Total Campaigns</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold text-purple-600">{stats.totalRecipients}</div>
              <p className="text-sm text-gray-500">Total Recipients</p>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Tabs */}
      <div className="border-b border-gray-200 dark:border-gray-700">
        <nav className="-mb-px flex space-x-8">
          {[
            { id: 'overview', name: 'Overview' },
            { id: 'accounts', name: 'Accounts Data' },
            { id: 'campaigns', name: 'Campaigns Data' },
            { id: 'recipients', name: 'Recipients Data' }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === tab.id
                  ? 'border-primary-500 text-primary-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              {tab.name}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      {activeTab === 'overview' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader title="Campaign Status Distribution" />
            <CardContent>
              <div className="space-y-3">
                {stats && (
                  <>
                    <div className="flex justify-between">
                      <span>Active Campaigns</span>
                      <Badge variant="primary">{stats.activeCampaigns}</Badge>
                    </div>
                    <div className="flex justify-between">
                      <span>Completed Campaigns</span>
                      <Badge variant="success">{stats.completedCampaigns}</Badge>
                    </div>
                    <div className="flex justify-between">
                      <span>Draft/Failed</span>
                      <Badge variant="secondary">{stats.totalCampaigns - stats.activeCampaigns - stats.completedCampaigns}</Badge>
                    </div>
                  </>
                )}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader title="System Health" />
            <CardContent>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span>Database Status</span>
                  <Badge variant="success">Online</Badge>
                </div>
                <div className="flex justify-between">
                  <span>API Status</span>
                  <Badge variant="success">Operational</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Background Jobs</span>
                  <Badge variant="success">Running</Badge>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {activeTab === 'accounts' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader title="Accounts List" />
            <CardContent>
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {accounts.map(account => (
                  <div
                    key={account.id}
                    className="flex items-center justify-between p-3 border rounded-lg cursor-pointer hover:bg-gray-50"
                    onClick={() => loadAccountUsers(account.id)}
                  >
                    <div>
                      <div className="font-medium">{account.name}</div>
                      <div className="text-sm text-gray-500">{account.admin_email}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium">{account.user_count} users</div>
                      <Badge variant={account.active ? 'success' : 'secondary'}>
                        {account.active ? 'Active' : 'Inactive'}
                      </Badge>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader title={selectedAccount ? `Users for Account #${selectedAccount}` : 'Select an account to view users'} />
            <CardContent>
              {selectedAccount ? (
                <div className="space-y-2 max-h-96 overflow-y-auto">
                  {accountUsers.map(user => (
                    <div key={user.id} className="flex items-center justify-between p-3 border rounded-lg">
                      <div>
                        <div className="font-medium">{user.name}</div>
                        <div className="text-sm text-gray-500">{user.email}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-sm">Daily: {user.daily_sent_count}</div>
                        <Badge variant={user.status === 'Active' ? 'success' : 'secondary'}>
                          {user.status}
                        </Badge>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-500 text-center py-8">Click on an account to view its users</p>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {activeTab === 'campaigns' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader title="Campaigns List" />
            <CardContent>
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {campaigns.map(campaign => (
                  <div
                    key={campaign.id}
                    className="flex items-center justify-between p-3 border rounded-lg cursor-pointer hover:bg-gray-50"
                    onClick={() => loadCampaignRecipients(campaign.id)}
                  >
                    <div>
                      <div className="font-medium">{campaign.name}</div>
                      <div className="text-sm text-gray-500">{campaign.subject}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium">{campaign.stats.total} recipients</div>
                      <div className="flex gap-2">
                        <Badge variant={
                          campaign.status === 'Completed' ? 'success' :
                          campaign.status === 'Sending' ? 'primary' :
                          campaign.status === 'Failed' ? 'danger' : 'secondary'
                        }>
                          {campaign.status}
                        </Badge>
                        <Button
                          variant="danger"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDeleteCampaign(campaign);
                          }}
                        >
                          <TrashIcon className="w-3 h-3" />
                        </Button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader title={selectedCampaign ? `Recipients for Campaign #${selectedCampaign}` : 'Select a campaign to view recipients'} />
            <CardContent>
              {selectedCampaign ? (
                <div className="space-y-2 max-h-96 overflow-y-auto">
                  {campaignRecipients.map(recipient => (
                    <div key={recipient.id} className="flex items-center justify-between p-3 border rounded-lg">
                      <div>
                        <div className="font-medium">{recipient.name}</div>
                        <div className="text-sm text-gray-500">{recipient.email}</div>
                      </div>
                      <Badge variant={
                        recipient.status === 'Sent' ? 'success' :
                        recipient.status === 'Sending' ? 'primary' :
                        recipient.status === 'Failed' ? 'danger' : 'secondary'
                      }>
                        {recipient.status}
                      </Badge>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-500 text-center py-8">Click on a campaign to view its recipients</p>
              )}
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
};

export default DataManagementView;