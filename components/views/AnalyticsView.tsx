import React, { useState, useEffect, useCallback } from 'react';
import { Campaign, CampaignStats, Account } from '../../types';
import { createApiWithToast } from '../../services/api';
import { useToast } from '../../contexts/ToastContext';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Badge from '../ui/Badge';
import Button from '../ui/Button';
import ChartBarIcon from '../icons/ChartBarIcon';

interface AnalyticsData {
  totalEmailsSent: number;
  totalEmailsFailed: number;
  successRate: number;
  averageSendRate: number;
  campaignPerformance: {
    campaignId: number;
    campaignName: string;
    successRate: number;
    totalSent: number;
    totalFailed: number;
    avgSendTime: number;
  }[];
  accountPerformance: {
    accountId: number;
    accountName: string;
    totalSent: number;
    successRate: number;
    avgDaily: number;
  }[];
  timeStats: {
    last24h: { sent: number; failed: number };
    last7d: { sent: number; failed: number };
    last30d: { sent: number; failed: number };
  };
}

const AnalyticsView: React.FC = () => {
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedTimeRange, setSelectedTimeRange] = useState<'24h' | '7d' | '30d' | 'all'>('7d');

  const { addToast } = useToast();
  const api = React.useMemo(() => createApiWithToast(addToast), [addToast]);

  const fetchAnalytics = useCallback(async () => {
    try {
      setLoading(true);
      
      const [campaignsData, accountsData] = await Promise.all([
        api.getCampaigns(),
        api.getAccounts(true)
      ]);

      setCampaigns(campaignsData);
      setAccounts(accountsData);

      // Calculate analytics from campaign data
      const totalEmailsSent = campaignsData.reduce((sum, campaign) => sum + campaign.stats.sent, 0);
      const totalEmailsFailed = campaignsData.reduce((sum, campaign) => sum + campaign.stats.failed, 0);
      const totalEmails = totalEmailsSent + totalEmailsFailed;
      const successRate = totalEmails > 0 ? (totalEmailsSent / totalEmails) * 100 : 0;

      // Campaign performance
      const campaignPerformance = campaignsData.map(campaign => ({
        campaignId: campaign.id,
        campaignName: campaign.name,
        successRate: campaign.stats.total > 0 ? (campaign.stats.sent / campaign.stats.total) * 100 : 0,
        totalSent: campaign.stats.sent,
        totalFailed: campaign.stats.failed,
        avgSendTime: calculateSendTime(campaign)
      })).sort((a, b) => b.successRate - a.successRate);

      // Account performance
      const accountPerformance = accountsData.map(account => {
        const accountCampaigns = campaignsData.filter(c => c.selected_accounts?.includes(account.id));
        const totalSent = accountCampaigns.reduce((sum, campaign) => sum + campaign.stats.sent, 0);
        const totalEmails = accountCampaigns.reduce((sum, campaign) => sum + campaign.stats.total, 0);
        const successRate = totalEmails > 0 ? (totalSent / totalEmails) * 100 : 0;
        
        return {
          accountId: account.id,
          accountName: account.name,
          totalSent,
          successRate,
          avgDaily: totalSent / Math.max(1, getDaysSinceCreation(account.created_at))
        };
      }).sort((a, b) => b.totalSent - a.totalSent);

      // Mock time-based stats (would come from backend in real implementation)
      const timeStats = {
        last24h: { sent: Math.floor(totalEmailsSent * 0.1), failed: Math.floor(totalEmailsFailed * 0.1) },
        last7d: { sent: Math.floor(totalEmailsSent * 0.3), failed: Math.floor(totalEmailsFailed * 0.3) },
        last30d: { sent: Math.floor(totalEmailsSent * 0.8), failed: Math.floor(totalEmailsFailed * 0.8) }
      };

      setAnalytics({
        totalEmailsSent,
        totalEmailsFailed,
        successRate,
        averageSendRate: 0, // Would be calculated from real data
        campaignPerformance,
        accountPerformance,
        timeStats
      });

    } catch (error) {
      addToast({ message: 'Failed to load analytics data', type: 'error' });
    } finally {
      setLoading(false);
    }
  }, [api, addToast]);

  const calculateSendTime = (campaign: Campaign): number => {
    if (campaign.sending_started_at && campaign.sending_completed_at) {
      const start = new Date(campaign.sending_started_at).getTime();
      const end = new Date(campaign.sending_completed_at).getTime();
      return (end - start) / 1000; // seconds
    }
    return 0;
  };

  const getDaysSinceCreation = (createdAt: string): number => {
    const created = new Date(createdAt).getTime();
    const now = Date.now();
    return Math.max(1, Math.ceil((now - created) / (1000 * 60 * 60 * 24)));
  };

  const formatDuration = (seconds: number): string => {
    if (seconds < 60) return `${seconds.toFixed(1)}s`;
    if (seconds < 3600) return `${(seconds / 60).toFixed(1)}m`;
    return `${(seconds / 3600).toFixed(1)}h`;
  };

  const exportReport = async () => {
    try {
      const report = {
        generatedAt: new Date().toISOString(),
        summary: {
          totalCampaigns: campaigns.length,
          totalAccounts: accounts.length,
          totalEmailsSent: analytics?.totalEmailsSent || 0,
          totalEmailsFailed: analytics?.totalEmailsFailed || 0,
          overallSuccessRate: analytics?.successRate || 0
        },
        campaignPerformance: analytics?.campaignPerformance || [],
        accountPerformance: analytics?.accountPerformance || []
      };

      const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `speedsend-analytics-${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      addToast({ message: 'Analytics report exported successfully', type: 'success' });
    } catch (error) {
      addToast({ message: 'Failed to export analytics report', type: 'error' });
    }
  };

  useEffect(() => {
    fetchAnalytics();
  }, [fetchAnalytics]);

  if (loading) {
    return (
      <div className="p-4 sm:p-6 lg:p-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
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
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white flex items-center">
          <ChartBarIcon className="w-8 h-8 mr-3 text-primary-600" />
          Analytics & Reports
        </h1>
        <div className="flex gap-3">
          <select
            value={selectedTimeRange}
            onChange={(e) => setSelectedTimeRange(e.target.value as any)}
            className="px-3 py-2 border border-gray-300 rounded-md text-sm"
          >
            <option value="24h">Last 24 Hours</option>
            <option value="7d">Last 7 Days</option>
            <option value="30d">Last 30 Days</option>
            <option value="all">All Time</option>
          </select>
          <Button onClick={exportReport} variant="outline">
            Export Report
          </Button>
        </div>
      </div>

      {analytics && (
        <>
          {/* Key Metrics */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-green-600">
                  {analytics.totalEmailsSent.toLocaleString()}
                </div>
                <p className="text-sm text-gray-500">Emails Sent</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-red-600">
                  {analytics.totalEmailsFailed.toLocaleString()}
                </div>
                <p className="text-sm text-gray-500">Failed Emails</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-blue-600">
                  {analytics.successRate.toFixed(1)}%
                </div>
                <p className="text-sm text-gray-500">Success Rate</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <div className="text-2xl font-bold text-purple-600">
                  {campaigns.length}
                </div>
                <p className="text-sm text-gray-500">Total Campaigns</p>
              </CardContent>
            </Card>
          </div>

          {/* Time-based Stats */}
          <Card>
            <CardHeader title="Performance Over Time" />
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="text-center">
                  <div className="text-lg font-semibold">Last 24 Hours</div>
                  <div className="text-green-600 text-xl font-bold">
                    {analytics.timeStats.last24h.sent.toLocaleString()}
                  </div>
                  <div className="text-red-600 text-sm">
                    {analytics.timeStats.last24h.failed.toLocaleString()} failed
                  </div>
                </div>
                <div className="text-center">
                  <div className="text-lg font-semibold">Last 7 Days</div>
                  <div className="text-green-600 text-xl font-bold">
                    {analytics.timeStats.last7d.sent.toLocaleString()}
                  </div>
                  <div className="text-red-600 text-sm">
                    {analytics.timeStats.last7d.failed.toLocaleString()} failed
                  </div>
                </div>
                <div className="text-center">
                  <div className="text-lg font-semibold">Last 30 Days</div>
                  <div className="text-green-600 text-xl font-bold">
                    {analytics.timeStats.last30d.sent.toLocaleString()}
                  </div>
                  <div className="text-red-600 text-sm">
                    {analytics.timeStats.last30d.failed.toLocaleString()} failed
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Campaign Performance */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader title="Top Performing Campaigns" />
              <CardContent>
                <div className="space-y-3 max-h-80 overflow-y-auto">
                  {analytics.campaignPerformance.slice(0, 10).map(campaign => (
                    <div key={campaign.campaignId} className="flex items-center justify-between p-3 border rounded-lg">
                      <div className="flex-1">
                        <div className="font-medium truncate">{campaign.campaignName}</div>
                        <div className="text-sm text-gray-500">
                          {campaign.totalSent.toLocaleString()} sent • {formatDuration(campaign.avgSendTime)}
                        </div>
                      </div>
                      <div className="text-right ml-4">
                        <Badge variant={
                          campaign.successRate >= 95 ? 'success' :
                          campaign.successRate >= 85 ? 'primary' :
                          campaign.successRate >= 70 ? 'warning' : 'danger'
                        }>
                          {campaign.successRate.toFixed(1)}%
                        </Badge>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader title="Account Performance" />
              <CardContent>
                <div className="space-y-3 max-h-80 overflow-y-auto">
                  {analytics.accountPerformance.map(account => (
                    <div key={account.accountId} className="flex items-center justify-between p-3 border rounded-lg">
                      <div className="flex-1">
                        <div className="font-medium">{account.accountName}</div>
                        <div className="text-sm text-gray-500">
                          {account.totalSent.toLocaleString()} sent • {account.avgDaily.toFixed(0)}/day avg
                        </div>
                      </div>
                      <div className="text-right ml-4">
                        <div className="text-sm font-medium">{account.successRate.toFixed(1)}%</div>
                        <div className="text-xs text-gray-500">success rate</div>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Campaign Status Breakdown */}
          <Card>
            <CardHeader title="Campaign Status Overview" />
            <CardContent>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {Object.entries(
                  campaigns.reduce((acc, campaign) => {
                    acc[campaign.status] = (acc[campaign.status] || 0) + 1;
                    return acc;
                  }, {} as Record<string, number>)
                ).map(([status, count]) => (
                  <div key={status} className="text-center">
                    <div className="text-2xl font-bold">{count}</div>
                    <div className="text-sm text-gray-500">{status}</div>
                    <Badge variant={
                      status === 'Completed' ? 'success' :
                      status === 'Sending' ? 'primary' :
                      status === 'Failed' ? 'danger' : 'secondary'
                    }>
                      {((count / campaigns.length) * 100).toFixed(1)}%
                    </Badge>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
};

export default AnalyticsView;