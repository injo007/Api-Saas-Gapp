import React, { useState, useEffect } from 'react';
import { AccountWithUsers, CampaignCreatePayload, Campaign, CampaignPreparation, SendingProgress, UserStatus } from '../../types';
import { createApiWithToast } from '../../services/api';
import { useToast } from '../../contexts/ToastContext';
import Button from '../ui/Button';
import Input from '../ui/Input';
import Textarea from '../ui/Textarea';
import Card from '../ui/Card';
import Badge from '../ui/Badge';
import ProgressBar from '../ui/ProgressBar';

const UltraFastSendView: React.FC = () => {
  const { addToast } = useToast();
  const api = createApiWithToast(addToast);

  // State
  const [accounts, setAccounts] = useState<AccountWithUsers[]>([]);
  const [selectedAccounts, setSelectedAccounts] = useState<number[]>([]);
  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [preparation, setPreparation] = useState<CampaignPreparation | null>(null);
  const [progress, setProgress] = useState<SendingProgress | null>(null);
  const [loading, setLoading] = useState(false);
  const [step, setStep] = useState<'create' | 'prepare' | 'send' | 'progress'>('create');

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    from_name: '',
    from_email: '',
    subject: '',
    html_body: '',
    recipients_csv: '',
    test_email: '',
    send_rate_per_minute: 1000,
    custom_headers: {} as Record<string, string>
  });

  // Custom headers state
  const [customHeaderKey, setCustomHeaderKey] = useState('');
  const [customHeaderValue, setCustomHeaderValue] = useState('');

  useEffect(() => {
    loadAccounts();
  }, []);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (step === 'progress' && campaign && progress) {
      interval = setInterval(async () => {
        try {
          const newProgress = await api.getCampaignProgress(campaign.id);
          setProgress(newProgress);
          
          // Stop polling if completed
          if (newProgress.progress_percentage >= 100) {
            clearInterval(interval);
            addToast({ message: 'Campaign completed!', type: 'success' });
          }
        } catch (error) {
          console.error('Error fetching progress:', error);
        }
      }, 1000); // Update every second
    }
    
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [step, campaign, progress]);

  const loadAccounts = async () => {
    try {
      const accountsData = await api.getAccounts(true);
      setAccounts(accountsData);
    } catch (error) {
      console.error('Error loading accounts:', error);
    }
  };

  const handleAccountSelection = (accountId: number, checked: boolean) => {
    if (checked) {
      setSelectedAccounts([...selectedAccounts, accountId]);
    } else {
      setSelectedAccounts(selectedAccounts.filter(id => id !== accountId));
    }
  };

  const addCustomHeader = () => {
    if (customHeaderKey && customHeaderValue) {
      setFormData({
        ...formData,
        custom_headers: {
          ...formData.custom_headers,
          [customHeaderKey]: customHeaderValue
        }
      });
      setCustomHeaderKey('');
      setCustomHeaderValue('');
    }
  };

  const removeCustomHeader = (key: string) => {
    const headers = { ...formData.custom_headers };
    delete headers[key];
    setFormData({ ...formData, custom_headers: headers });
  };

  const createCampaign = async () => {
    if (!selectedAccounts.length) {
      addToast({ message: 'Please select at least one account', type: 'error' });
      return;
    }

    setLoading(true);
    try {
      const payload: CampaignCreatePayload = {
        ...formData,
        selected_accounts: selectedAccounts,
        custom_headers: Object.keys(formData.custom_headers).length > 0 ? formData.custom_headers : undefined
      };

      const newCampaign = await api.createCampaign(payload);
      setCampaign(newCampaign);
      setStep('prepare');
      addToast({ message: 'Campaign created successfully!', type: 'success' });
    } catch (error) {
      console.error('Error creating campaign:', error);
    } finally {
      setLoading(false);
    }
  };

  const prepareCampaign = async () => {
    if (!campaign) return;

    setLoading(true);
    try {
      const prepResult = await api.prepareCampaign(campaign.id, selectedAccounts);
      setPreparation(prepResult);
      setStep('send');
      addToast({ message: 'Campaign prepared for ultra-fast sending!', type: 'success' });
    } catch (error) {
      console.error('Error preparing campaign:', error);
    } finally {
      setLoading(false);
    }
  };

  const sendTestEmail = async () => {
    if (!campaign || !formData.test_email) return;

    setLoading(true);
    try {
      await api.sendTestEmail(campaign.id, formData.test_email);
      addToast({ message: 'Test email sent successfully!', type: 'success' });
    } catch (error) {
      console.error('Error sending test email:', error);
    } finally {
      setLoading(false);
    }
  };

  const startUltraFastSending = async () => {
    if (!campaign) return;

    setLoading(true);
    try {
      await api.sendCampaignUltraFast(campaign.id, true);
      setStep('progress');
      
      // Start monitoring progress
      const initialProgress = await api.getCampaignProgress(campaign.id);
      setProgress(initialProgress);
      
      addToast({ message: 'Ultra-fast sending started!', type: 'success' });
    } catch (error) {
      console.error('Error starting sending:', error);
    } finally {
      setLoading(false);
    }
  };

  const calculateTotalCapacity = () => {
    return selectedAccounts.reduce((total, accountId) => {
      const account = accounts.find(a => a.id === accountId);
      if (account) {
        return total + account.users.filter(u => u.status === UserStatus.ACTIVE).length;
      }
      return total;
    }, 0);
  };

  const calculateEstimatedTime = () => {
    const totalRecipients = formData.recipients_csv.split('\n').filter(line => line.trim()).length;
    const totalUsers = calculateTotalCapacity();
    if (totalUsers === 0) return 0;
    
    const recipientsPerUser = Math.ceil(totalRecipients / totalUsers);
    // Assuming 25 emails per user per batch, 2 seconds per batch
    return Math.ceil(recipientsPerUser / 25) * 2;
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Ultra-Fast Email Sender</h1>
        <Badge variant={
          step === 'create' ? 'default' : 
          step === 'prepare' ? 'warning' : 
          step === 'send' ? 'info' : 'success'
        }>
          {step === 'create' && 'Creating Campaign'}
          {step === 'prepare' && 'Preparing Campaign'}
          {step === 'send' && 'Ready to Send'}
          {step === 'progress' && 'Sending in Progress'}
        </Badge>
      </div>

      {/* Step 1: Create Campaign */}
      {step === 'create' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Campaign Details */}
          <Card>
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">Campaign Details</h2>
              <div className="space-y-4">
                <Input
                  label="Campaign Name"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="My Ultra-Fast Campaign"
                />
                <Input
                  label="From Name"
                  value={formData.from_name}
                  onChange={(e) => setFormData({ ...formData, from_name: e.target.value })}
                  placeholder="John Doe"
                />
                <Input
                  label="From Email"
                  type="email"
                  value={formData.from_email}
                  onChange={(e) => setFormData({ ...formData, from_email: e.target.value })}
                  placeholder="john@company.com"
                />
                <Input
                  label="Subject"
                  value={formData.subject}
                  onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                  placeholder="Your email subject"
                />
                <Input
                  label="Test Email"
                  type="email"
                  value={formData.test_email}
                  onChange={(e) => setFormData({ ...formData, test_email: e.target.value })}
                  placeholder="test@example.com"
                />
                <Input
                  label="Send Rate (emails/minute)"
                  type="number"
                  value={formData.send_rate_per_minute}
                  onChange={(e) => setFormData({ ...formData, send_rate_per_minute: parseInt(e.target.value) })}
                />
              </div>
            </div>
          </Card>

          {/* Account Selection */}
          <Card>
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">Select Accounts</h2>
              <div className="space-y-3">
                {accounts.map((account) => (
                  <div key={account.id} className="flex items-center justify-between p-3 border rounded-lg">
                    <div className="flex items-center space-x-3">
                      <input
                        type="checkbox"
                        checked={selectedAccounts.includes(account.id)}
                        onChange={(e) => handleAccountSelection(account.id, e.target.checked)}
                        className="h-4 w-4 text-blue-600"
                      />
                      <div>
                        <div className="font-medium">{account.name}</div>
                        <div className="text-sm text-gray-500">{account.admin_email}</div>
                        <div className="text-xs text-gray-400">
                          {account.users.filter(u => u.status === UserStatus.ACTIVE).length} active users
                        </div>
                      </div>
                    </div>
                    <Badge variant={account.active ? 'success' : 'error'}>
                      {account.active ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                ))}
              </div>
              
              {selectedAccounts.length > 0 && (
                <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                  <div className="text-sm font-medium text-blue-900">Selection Summary</div>
                  <div className="text-sm text-blue-700">
                    {selectedAccounts.length} accounts selected
                  </div>
                  <div className="text-sm text-blue-700">
                    {calculateTotalCapacity()} total active users
                  </div>
                  <div className="text-sm text-blue-700">
                    Estimated send time: {calculateEstimatedTime()} seconds
                  </div>
                </div>
              )}
            </div>
          </Card>

          {/* Email Content */}
          <Card className="lg:col-span-2">
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">Email Content</h2>
              <Textarea
                label="HTML Body"
                value={formData.html_body}
                onChange={(e) => setFormData({ ...formData, html_body: e.target.value })}
                placeholder="<html><body><h1>Hello {{name}}!</h1><p>Your email content here...</p></body></html>"
                rows={8}
              />
              
              <div className="mt-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Recipients CSV (email,name,custom_data)
                </label>
                <Textarea
                  value={formData.recipients_csv}
                  onChange={(e) => setFormData({ ...formData, recipients_csv: e.target.value })}
                  placeholder="john@example.com,John Doe,{&quot;company&quot;:&quot;Acme Inc&quot;}&#10;jane@example.com,Jane Smith,{&quot;company&quot;:&quot;Tech Corp&quot;}"
                  rows={6}
                />
                <div className="text-xs text-gray-500 mt-1">
                  {formData.recipients_csv.split('\n').filter(line => line.trim()).length} recipients
                </div>
              </div>
            </div>
          </Card>

          {/* Custom Headers */}
          <Card className="lg:col-span-2">
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">Custom Headers</h2>
              
              <div className="flex space-x-2 mb-4">
                <Input
                  placeholder="Header name"
                  value={customHeaderKey}
                  onChange={(e) => setCustomHeaderKey(e.target.value)}
                />
                <Input
                  placeholder="Header value"
                  value={customHeaderValue}
                  onChange={(e) => setCustomHeaderValue(e.target.value)}
                />
                <Button onClick={addCustomHeader} disabled={!customHeaderKey || !customHeaderValue}>
                  Add
                </Button>
              </div>

              {Object.entries(formData.custom_headers).length > 0 && (
                <div className="space-y-2">
                  {Object.entries(formData.custom_headers).map(([key, value]) => (
                    <div key={key} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                      <span className="text-sm">
                        <span className="font-medium">{key}:</span> {value}
                      </span>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => removeCustomHeader(key)}
                      >
                        Remove
                      </Button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </Card>

          <div className="lg:col-span-2 flex justify-end">
            <Button
              onClick={createCampaign}
              disabled={loading || !formData.name || !formData.subject || !formData.html_body || !formData.recipients_csv}
              loading={loading}
            >
              Create Campaign
            </Button>
          </div>
        </div>
      )}

      {/* Step 2: Prepare Campaign */}
      {step === 'prepare' && campaign && (
        <Card>
          <div className="p-6">
            <h2 className="text-lg font-semibold mb-4">Prepare for Ultra-Fast Sending</h2>
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-sm text-gray-500">Campaign</div>
                  <div className="font-medium">{campaign.name}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Recipients</div>
                  <div className="font-medium">{campaign.stats.total}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Selected Accounts</div>
                  <div className="font-medium">{selectedAccounts.length}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Total Users</div>
                  <div className="font-medium">{calculateTotalCapacity()}</div>
                </div>
              </div>
              
              <div className="flex space-x-4">
                <Button onClick={prepareCampaign} loading={loading}>
                  Prepare Campaign
                </Button>
                {formData.test_email && (
                  <Button variant="outline" onClick={sendTestEmail} loading={loading}>
                    Send Test Email
                  </Button>
                )}
              </div>
            </div>
          </div>
        </Card>
      )}

      {/* Step 3: Ready to Send */}
      {step === 'send' && preparation && (
        <Card>
          <div className="p-6">
            <h2 className="text-lg font-semibold mb-4">Ready for Ultra-Fast Sending</h2>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
              <div>
                <div className="text-sm text-gray-500">Total Recipients</div>
                <div className="text-2xl font-bold text-green-600">{preparation.total_recipients}</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Total Users</div>
                <div className="text-2xl font-bold text-blue-600">{preparation.total_users}</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Estimated Time</div>
                <div className="text-2xl font-bold text-purple-600">{preparation.estimated_send_time}s</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Emails/Second</div>
                <div className="text-2xl font-bold text-orange-600">
                  {Math.round(preparation.total_recipients / preparation.estimated_send_time)}
                </div>
              </div>
            </div>
            
            <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
              <div className="font-medium text-green-800">Campaign Prepared Successfully!</div>
              <div className="text-sm text-green-600 mt-1">
                All recipients have been optimally distributed across {preparation.total_users} users 
                for maximum sending speed.
              </div>
            </div>

            <Button onClick={startUltraFastSending} loading={loading} className="bg-red-600 hover:bg-red-700">
              🚀 Start Ultra-Fast Sending
            </Button>
          </div>
        </Card>
      )}

      {/* Step 4: Sending Progress */}
      {step === 'progress' && progress && (
        <div className="space-y-6">
          <Card>
            <div className="p-6">
              <h2 className="text-lg font-semibold mb-4">Sending Progress</h2>
              
              <div className="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
                <div>
                  <div className="text-sm text-gray-500">Total</div>
                  <div className="text-xl font-bold">{progress.total_emails}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Sent</div>
                  <div className="text-xl font-bold text-green-600">{progress.sent_emails}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Sending</div>
                  <div className="text-xl font-bold text-blue-600">{progress.sending_emails}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Failed</div>
                  <div className="text-xl font-bold text-red-600">{progress.failed_emails}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-500">Rate (emails/sec)</div>
                  <div className="text-xl font-bold text-purple-600">
                    {progress.current_send_rate.toFixed(1)}
                  </div>
                </div>
              </div>

              <ProgressBar 
                value={progress.progress_percentage} 
                max={100}
                className="mb-4"
              />
              
              <div className="text-center text-sm text-gray-600">
                {progress.progress_percentage.toFixed(1)}% Complete
              </div>
              
              {progress.progress_percentage >= 100 && (
                <div className="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
                  <div className="font-medium text-green-800">🎉 Campaign Completed!</div>
                  <div className="text-sm text-green-600 mt-1">
                    All emails have been sent successfully at ultra-fast speed.
                  </div>
                </div>
              )}
            </div>
          </Card>
        </div>
      )}
    </div>
  );
};

export default UltraFastSendView;