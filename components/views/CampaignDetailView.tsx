

import React, { useState, useEffect, useCallback } from 'react';
import { CampaignDetail, RecipientStatus, CampaignStatus } from '../../types';
import Button from '../ui/Button';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Badge from '../ui/Badge';
import ProgressBar from '../ui/ProgressBar';
import ChevronLeftIcon from '../icons/ChevronLeftIcon';
import { createApiWithToast } from '../../services/api';
import { useToast } from '../../contexts/ToastContext';

interface CampaignDetailViewProps {
  campaignId: number;
  onBack: () => void;
}

const RecipientStatusBadge: React.FC<{ status: RecipientStatus }> = ({ status }) => {
  const colorMap: { [key in RecipientStatus]: 'green' | 'yellow' | 'red' } = {
    [RecipientStatus.SENT]: 'green',
    [RecipientStatus.PENDING]: 'yellow',
    [RecipientStatus.FAILED]: 'red',
  };
  return <Badge color={colorMap[status]}>{status}</Badge>;
};

const CampaignDetailView: React.FC<CampaignDetailViewProps> = ({ campaignId, onBack }) => {
  const [campaign, setCampaign] = useState<CampaignDetail | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { addToast } = useToast();
  const api = createApiWithToast(addToast);

  const fetchCampaign = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);
      const data = await api.getCampaign(campaignId);
      setCampaign(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch campaign details');
      addToast({message: `Failed to load campaign details: ${err instanceof Error ? err.message : 'Unknown error'}`, type: 'error'});
    } finally {
      setIsLoading(false);
    }
  }, [campaignId, addToast, api]);

  useEffect(() => {
    fetchCampaign();

    let pollInterval: number | undefined;
    
    // We poll constantly in detail view to ensure real-time updates for any status
    pollInterval = window.setInterval(() => {
        api.getCampaign(campaignId)
            .then(setCampaign)
            .catch(err => console.error("Polling failed for campaign detail:", err));
    }, 3000); // Poll faster on detail view

    return () => {
        if(pollInterval) clearInterval(pollInterval);
    }

  }, [campaignId, fetchCampaign, api]); // Removed campaign?.status from dependency to ensure continuous polling

  if (isLoading) return <div className="p-8 text-center text-gray-700 dark:text-gray-300">Loading campaign details...</div>;
  if (error) return <div className="p-8 text-center text-red-500">Error: {error}</div>;
  if (!campaign) return <div className="p-8 text-center text-gray-500 dark:text-gray-400">Campaign not found.</div>;

  const progress = campaign.stats.total > 0 ? (campaign.stats.sent / campaign.stats.total) * 100 : 0;
  
  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <div className="flex items-center space-x-3 mb-6">
        <Button variant="secondary" onClick={onBack} className="p-2 !rounded-full">
            <ChevronLeftIcon className="w-5 h-5"/>
        </Button>
        <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">{campaign.name}</h1>
            <p className="text-sm text-gray-500 dark:text-gray-400">Subject: {campaign.subject}</p>
        </div>
      </div>

      <Card>
        <CardHeader title="Campaign Overview" />
        <CardContent>
          <div className="mb-6">
            <div className="flex justify-between items-center mb-1">
                <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Overall Progress</span>
                <span className="text-sm text-gray-500 dark:text-gray-400">{campaign.stats.sent} / {campaign.stats.total} Emails Sent</span>
            </div>
            <ProgressBar value={progress} />
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-center">
            <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">Success</p>
              <p className="text-2xl font-bold text-green-600">{campaign.stats.sent}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">Pending</p>
              <p className="text-2xl font-bold text-yellow-600">{campaign.stats.pending}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">Failed</p>
              <p className="text-2xl font-bold text-red-600">{campaign.stats.failed}</p>
            </div>
             <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">Success Rate</p>
              <p className="text-2xl font-bold text-blue-600">{progress.toFixed(1)}%</p>
            </div>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardHeader title="Recipient Log" />
        <div className="overflow-x-auto">
            {campaign.recipients.length === 0 ? (
                <CardContent className="text-center text-gray-500 dark:text-gray-400 py-4">
                    No recipients in this campaign yet.
                </CardContent>
            ) : (
                <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead className="bg-gray-50 dark:bg-gray-700">
                    <tr>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider dark:text-gray-300">Email</th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider dark:text-gray-300">Name</th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider dark:text-gray-300">Status</th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider dark:text-gray-300">Error Details</th>
                    </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200 dark:bg-gray-800 dark:divide-gray-700">
                    {campaign.recipients.map(recipient => (
                    <tr key={recipient.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/50">
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">{recipient.email}</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">{recipient.name || 'N/A'}</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm"><RecipientStatusBadge status={recipient.status} /></td>
                        <td className="px-6 py-4 text-sm text-red-500 dark:text-red-400 max-w-xs truncate">{recipient.last_error || '—'}</td>
                    </tr>
                    ))}
                </tbody>
                </table>
            )}
        </div>
      </Card>
    </div>
  );
};

export default CampaignDetailView;