

import React from 'react';
import { Campaign, CampaignStatus } from '../../types';
import Button from '../ui/Button';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Badge from '../ui/Badge';
import ProgressBar from '../ui/ProgressBar';
import PlusIcon from '../icons/PlusIcon';
import PlayIcon from '../icons/PlayIcon';
import PauseIcon from '../icons/PauseIcon';
import PaperAirplaneIcon from '../icons/PaperAirplaneIcon'; // Added import for PaperAirplaneIcon
import { useToast } from '../../contexts/ToastContext';
import { useDialog } from '../../contexts/DialogContext';

interface DashboardViewProps {
  campaigns: Campaign[];
  onCreateCampaign: () => void;
  onViewCampaign: (campaignId: number) => void;
  onToggleCampaign: (campaignId: number, newStatus: CampaignStatus) => Promise<void>;
  isLoadingCampaigns: boolean; // New prop for loading state
  errorLoadingCampaigns: string | null; // New prop for error state
}

const CampaignStatusBadge: React.FC<{ status: CampaignStatus }> = ({ status }) => {
  const colorMap: { [key in CampaignStatus]: 'green' | 'blue' | 'yellow' | 'red' | 'gray' } = {
    [CampaignStatus.COMPLETED]: 'green',
    [CampaignStatus.SENDING]: 'blue',
    [CampaignStatus.PAUSED]: 'yellow',
    [CampaignStatus.FAILED]: 'red',
    [CampaignStatus.DRAFT]: 'gray',
  };
  return <Badge color={colorMap[status]}>{status}</Badge>;
};

const DashboardView: React.FC<DashboardViewProps> = ({ 
  campaigns, 
  onCreateCampaign, 
  onViewCampaign, 
  onToggleCampaign,
  isLoadingCampaigns,
  errorLoadingCampaigns,
}) => {
  const { addToast } = useToast();
  const { openDialog } = useDialog();

  const handleToggle = async (campaign: Campaign) => {
    const isSending = campaign.status === CampaignStatus.SENDING;
    const action = isSending ? 'pause' : 'start';
    const newStatus = isSending ? CampaignStatus.PAUSED : CampaignStatus.SENDING;
    const confirmationMessage = isSending 
      ? `Are you sure you want to pause "${campaign.name}"?`
      : `Are you sure you want to start "${campaign.name}"?`;

    openDialog({
      title: `${action === 'pause' ? 'Pause' : 'Start'} Campaign`,
      message: confirmationMessage,
      onConfirm: async () => {
        try {
          await onToggleCampaign(campaign.id, newStatus);
          addToast({ 
            message: `Campaign "${campaign.name}" ${action === 'pause' ? 'paused' : 'started'} successfully!`, 
            type: 'success' 
          });
        } catch (error) {
          addToast({ 
            message: `Failed to ${action} campaign "${campaign.name}". ${error instanceof Error ? error.message : ''}`, 
            type: 'error' 
          });
        }
      },
    });
  };

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Campaign Dashboard</h1>
        <Button onClick={onCreateCampaign}>
          <PlusIcon className="w-5 h-5 mr-2" />
          Create Campaign
        </Button>
      </div>

      {isLoadingCampaigns && (
        <div className="text-center text-gray-500 dark:text-gray-400">Loading campaigns...</div>
      )}

      {errorLoadingCampaigns && (
        <div className="text-center text-red-500 dark:text-red-400">Error loading campaigns: {errorLoadingCampaigns}</div>
      )}

      {!isLoadingCampaigns && !errorLoadingCampaigns && campaigns.length === 0 ? (
        <Card>
          <CardContent className="text-center text-gray-500 dark:text-gray-400 py-12">
            <PaperAirplaneIcon className="w-16 h-16 mx-auto mb-4 text-primary-400 transform -rotate-45" />
            <h3 className="text-xl font-medium text-gray-800 dark:text-gray-100">No campaigns created yet</h3>
            <p className="mt-2 text-base">Start by creating your first email campaign.</p>
            <Button onClick={onCreateCampaign} className="mt-6">
              <PlusIcon className="w-5 h-5 mr-2" />
              Create First Campaign
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-6">
          {campaigns.map((campaign) => {
            const progress = campaign.stats.total > 0 ? (campaign.stats.sent / campaign.stats.total) * 100 : 0;
            return (
              <Card key={campaign.id}>
                <CardHeader className="flex justify-between items-center">
                  <div>
                    <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100">{campaign.name}</h2>
                    <p className="text-sm text-gray-500 dark:text-gray-400">{campaign.subject}</p>
                  </div>
                  <CampaignStatusBadge status={campaign.status} />
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <div className="flex justify-between items-center mb-1">
                        <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Progress</span>
                        <span className="text-sm text-gray-500 dark:text-gray-400">{campaign.stats.sent} / {campaign.stats.total} sent</span>
                    </div>
                    <ProgressBar value={progress} />
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-center">
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Success</p>
                      <p className="text-xl font-semibold text-green-600">{campaign.stats.sent}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Pending</p>
                      <p className="text-xl font-semibold text-yellow-600">{campaign.stats.pending}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Failed</p>
                      <p className="text-xl font-semibold text-red-600">{campaign.stats.failed}</p>
                    </div>
                     <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Success Rate</p>
                      <p className="text-xl font-semibold text-blue-600">{progress.toFixed(1)}%</p>
                    </div>
                  </div>
                </CardContent>
                <div className="p-4 bg-gray-50 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 flex justify-end items-center space-x-2">
                    <Button variant="secondary" onClick={() => onViewCampaign(campaign.id)}>View Details</Button>
                    {(campaign.status === CampaignStatus.DRAFT || campaign.status === CampaignStatus.PAUSED || campaign.status === CampaignStatus.FAILED) && (
                        <Button variant="primary" onClick={() => handleToggle(campaign)}>
                            <PlayIcon className="w-5 h-5 mr-2"/> Start
                        </Button>
                    )}
                    {campaign.status === CampaignStatus.SENDING && (
                         <Button variant="secondary" onClick={() => handleToggle(campaign)}>
                            <PauseIcon className="w-5 h-5 mr-2"/> Pause
                        </Button>
                    )}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default DashboardView;