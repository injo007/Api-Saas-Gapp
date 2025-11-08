import React, { useState, useEffect } from 'react';
import { AccountWithUsers, CampaignCreatePayload, Campaign } from '../../types';
import { createApiWithToast } from '../../services/api';
import { useToast } from '../../contexts/ToastContext';
import Button from '../ui/Button';
import Input from '../ui/Input';
import Textarea from '../ui/Textarea';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Badge from '../ui/Badge';

interface SelectedUser {
  accountId: number;
  userEmails: string[];
}

const UltraFastSendView: React.FC = () => {
  const { addToast } = useToast();
  const api = React.useMemo(() => createApiWithToast(addToast), [addToast]);

  // State
  const [accounts, setAccounts] = useState<AccountWithUsers[]>([]);
  const [selectedAccounts, setSelectedAccounts] = useState<number[]>([]);
  const [selectedUsers, setSelectedUsers] = useState<SelectedUser[]>([]);
  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [loading, setLoading] = useState(false);
  const [step, setStep] = useState<'create' | 'sending'>('create');

  // Enhanced form state with email template
  const [formData, setFormData] = useState({
    name: '',
    email_template: `Date: [date]
From: "Your Company Newsletter" <newsletter@yourcompany.com>
To: [to]
Message-Id: <[rndn_12].campaign@yourcompany.com>
Subject: Welcome to your new favorite newsletter!
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="=-qxZzOIrv8vyHrrI8FapROg=="

--=-qxZzOIrv8vyHrrI8FapROg==
Content-Type: text/html; charset=UTF-8

<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
<div style="max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="color: #2563eb;">Hello [name]!</h1>
  <p>Welcome to our amazing newsletter. We're excited to have you on board!</p>
  <p>This email was sent on [date] at [time].</p>
  <p>Your unique ID: [rndn_8]</p>
  <p>Best regards,<br>Your Company Team</p>
</div>
</body>
</html>

--=-qxZzOIrv8vyHrrI8FapROg==--`,
    recipients_csv: '',
    test_email: '',
    send_rate_per_minute: 60
  });

  // Available template tags
  const availableTags = [
    { tag: '[date]', description: 'Current date (YYYY-MM-DD)', example: '2025-11-08' },
    { tag: '[time]', description: 'Current time (HH:MM:SS)', example: '14:30:45' },
    { tag: '[to]', description: 'Recipient email address', example: 'user@example.com' },
    { tag: '[name]', description: 'Recipient name', example: 'John Doe' },
    { tag: '[rndn_N]', description: 'Random N-digit number', example: '[rndn_8] = 12345678' },
    { tag: '[timestamp]', description: 'Unix timestamp', example: '1699459200' },
    { tag: '[company]', description: 'Your company name', example: 'Your Company' },
    { tag: '[unsubscribe]', description: 'Unsubscribe link', example: 'https://...' }
  ];

  // Load accounts on component mount
  useEffect(() => {
    loadAccounts();
  }, []);

  const loadAccounts = async () => {
    try {
      const accountsData = await api.getAccounts(true);
      setAccounts(accountsData);
    } catch (error) {
      addToast({ message: 'Failed to load accounts', type: 'error' });
    }
  };

  const handleAccountSelection = (accountId: number) => {
    const isSelected = selectedAccounts.includes(accountId);
    if (isSelected) {
      // Deselect account
      setSelectedAccounts(selectedAccounts.filter(id => id !== accountId));
      setSelectedUsers(selectedUsers.filter(su => su.accountId !== accountId));
    } else {
      // Select account and all its active users
      setSelectedAccounts([...selectedAccounts, accountId]);
      const account = accounts.find(acc => acc.id === accountId);
      if (account) {
        const activeUserEmails = account.users
          .filter(u => u.status === 'Active' || u.status === 'ACTIVE')
          .map(u => u.email);
        setSelectedUsers([...selectedUsers, {
          accountId,
          userEmails: activeUserEmails
        }]);
      }
    }
  };

  const handleUserSelection = (accountId: number, userEmail: string) => {
    setSelectedUsers(prev => {
      return prev.map(su => {
        if (su.accountId === accountId) {
          const isSelected = su.userEmails.includes(userEmail);
          return {
            ...su,
            userEmails: isSelected 
              ? su.userEmails.filter(email => email !== userEmail)
              : [...su.userEmails, userEmail]
          };
        }
        return su;
      });
    });
  };

  const insertTag = (tag: string) => {
    const textarea = document.getElementById('email-template') as HTMLTextAreaElement;
    if (textarea) {
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      const text = formData.email_template;
      const newText = text.substring(0, start) + tag + text.substring(end);
      setFormData({ ...formData, email_template: newText });
      
      setTimeout(() => {
        textarea.focus();
        textarea.setSelectionRange(start + tag.length, start + tag.length);
      }, 0);
    }
  };

  const parseEmailTemplate = () => {
    const lines = formData.email_template.split('\n');
    let fromName = 'SpeedSend';
    let fromEmail = 'noreply@speedsend.com';
    let subject = 'Email Campaign';
    let htmlBody = '';
    let inBody = false;

    for (const line of lines) {
      if (line.startsWith('From:')) {
        const fromMatch = line.match(/From:\s*"([^"]*)"?\s*<([^>]*)>/);
        if (fromMatch) {
          fromName = fromMatch[1];
          fromEmail = fromMatch[2];
        } else {
          const emailMatch = line.match(/From:\s*([^\s]+)/);
          if (emailMatch) {
            fromEmail = emailMatch[1];
            fromName = emailMatch[1].split('@')[0];
          }
        }
      } else if (line.startsWith('Subject:')) {
        subject = line.replace('Subject:', '').trim();
      } else if (line.trim() === '' && !inBody) {
        // Empty line indicates start of body
        inBody = true;
      } else if (inBody) {
        htmlBody += line + '\n';
      }
    }

    return {
      from_name: fromName,
      from_email: fromEmail,
      subject,
      html_body: htmlBody.trim() || '<p>Email content</p>'
    };
  };

  const createAndSendCampaign = async () => {
    if (!formData.name || !formData.email_template || !formData.recipients_csv) {
      addToast({ message: 'Please fill in all required fields', type: 'error' });
      return;
    }

    if (selectedUsers.length === 0) {
      addToast({ message: 'Please select at least one user account for sending', type: 'error' });
      return;
    }

    setLoading(true);
    try {
      const parsed = parseEmailTemplate();
      
      // Get selected user emails for sending
      const allSelectedUserEmails = selectedUsers.flatMap(su => su.userEmails);
      
      const campaignPayload: CampaignCreatePayload = {
        name: formData.name,
        from_name: parsed.from_name,
        from_email: parsed.from_email,
        subject: parsed.subject,
        html_body: parsed.html_body,
        recipients_csv: formData.recipients_csv,
        selected_accounts: selectedAccounts,
        send_rate_per_minute: formData.send_rate_per_minute
      };

      // Create campaign
      const createdCampaign = await api.createCampaign(campaignPayload);
      setCampaign(createdCampaign);
      
      // Start sending with user delegation
      await api.sendCampaign(createdCampaign.id);
      
      setStep('sending');
      addToast({ 
        message: `Campaign "${formData.name}" created and sending started!`, 
        type: 'success' 
      });

    } catch (error) {
      addToast({ 
        message: `Failed to create/send campaign: ${error instanceof Error ? error.message : 'Unknown error'}`, 
        type: 'error' 
      });
    } finally {
      setLoading(false);
    }
  };

  const sendTestEmail = async () => {
    if (!formData.test_email || !formData.email_template) {
      addToast({ message: 'Please enter a test email and email template', type: 'error' });
      return;
    }

    setLoading(true);
    try {
      const parsed = parseEmailTemplate();
      
      // Create a temporary test campaign
      const testCampaign: CampaignCreatePayload = {
        name: `Test - ${formData.name || 'Quick Test'}`,
        from_name: parsed.from_name,
        from_email: parsed.from_email,
        subject: parsed.subject,
        html_body: parsed.html_body,
        recipients_csv: `${formData.test_email},Test User,{}`,
        test_email: formData.test_email,
        selected_accounts: selectedAccounts.slice(0, 1), // Use first selected account
        send_rate_per_minute: 1
      };

      const testCampaignCreated = await api.createCampaign(testCampaign);
      await api.sendTestEmail(testCampaignCreated.id, formData.test_email);
      
      addToast({ message: 'Test email sent successfully!', type: 'success' });
    } catch (error) {
      addToast({ 
        message: `Failed to send test email: ${error instanceof Error ? error.message : 'Unknown error'}`, 
        type: 'error' 
      });
    } finally {
      setLoading(false);
    }
  };

  const getTotalSelectedUsers = () => {
    return selectedUsers.reduce((total, su) => total + su.userEmails.length, 0);
  };

  const getTotalRecipients = () => {
    return formData.recipients_csv.split('\n').filter(line => line.trim()).length;
  };

  if (step === 'sending') {
    return (
      <div className="p-6">
        <Card>
          <CardHeader title="Campaign Sending" />
          <CardContent>
            <div className="text-center py-8">
              <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-primary-600 mx-auto mb-4"></div>
              <h2 className="text-xl font-semibold mb-2">Sending Campaign: {campaign?.name}</h2>
              <p className="text-gray-600 mb-4">
                Your campaign is being sent using {getTotalSelectedUsers()} workspace users
              </p>
              <Button 
                variant="outline" 
                onClick={() => setStep('create')}
              >
                Create Another Campaign
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Ultra Fast Send</h1>
        <div className="flex gap-2">
          <Button 
            variant="outline" 
            onClick={sendTestEmail}
            loading={loading}
            disabled={!formData.test_email || !formData.email_template}
          >
            Send Test Email
          </Button>
          <Button 
            onClick={createAndSendCampaign}
            loading={loading}
            disabled={!formData.name || !formData.email_template || !formData.recipients_csv || getTotalSelectedUsers() === 0}
          >
            Create & Send Campaign
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Panel - Email Template */}
        <div className="lg:col-span-2 space-y-6">
          <Card>
            <CardHeader title="Email Template with Header Tags" />
            <CardContent className="space-y-4">
              <Input
                label="Campaign Name"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="My Email Campaign"
                required
              />

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Email Template (with headers)
                </label>
                <Textarea
                  id="email-template"
                  value={formData.email_template}
                  onChange={(e) => setFormData({ ...formData, email_template: e.target.value })}
                  rows={20}
                  className="font-mono text-sm"
                  placeholder="Enter your complete email template with headers..."
                />
                <p className="text-xs text-gray-500 mt-1">
                  Include complete email headers (From:, To:, Subject:, etc.) and body content
                </p>
              </div>

              <div>
                <h3 className="text-sm font-medium text-gray-700 mb-2">Available Tags</h3>
                <div className="grid grid-cols-2 gap-2">
                  {availableTags.map((tagInfo) => (
                    <button
                      key={tagInfo.tag}
                      onClick={() => insertTag(tagInfo.tag)}
                      className="text-left p-2 text-xs border rounded hover:bg-gray-50 transition-colors"
                    >
                      <div className="font-mono text-primary-600">{tagInfo.tag}</div>
                      <div className="text-gray-500">{tagInfo.description}</div>
                    </button>
                  ))}
                </div>
              </div>

              <Textarea
                label="Recipients CSV (email,name,custom_data)"
                value={formData.recipients_csv}
                onChange={(e) => setFormData({ ...formData, recipients_csv: e.target.value })}
                rows={6}
                placeholder="user1@example.com,John Doe,{}&#10;user2@example.com,Jane Smith,{}"
                required
              />

              <div className="flex items-center gap-4">
                <Input
                  label="Test Email"
                  type="email"
                  value={formData.test_email}
                  onChange={(e) => setFormData({ ...formData, test_email: e.target.value })}
                  placeholder="test@example.com"
                />
                <Input
                  label="Send Rate (per minute)"
                  type="number"
                  value={formData.send_rate_per_minute}
                  onChange={(e) => setFormData({ ...formData, send_rate_per_minute: parseInt(e.target.value) || 60 })}
                  min="1"
                  max="1000"
                />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Right Panel - Account & User Selection */}
        <div className="space-y-6">
          <Card>
            <CardHeader title="Select Accounts & Users" />
            <CardContent>
              <div className="space-y-4">
                {accounts.map((account) => (
                  <div key={account.id} className="border rounded-lg p-4">
                    <div className="flex items-center justify-between mb-2">
                      <label className="flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={selectedAccounts.includes(account.id)}
                          onChange={() => handleAccountSelection(account.id)}
                          className="mr-2"
                        />
                        <span className="font-medium">{account.name}</span>
                      </label>
                      <Badge variant={account.active ? 'success' : 'secondary'}>
                        {account.user_count} users
                      </Badge>
                    </div>
                    <p className="text-sm text-gray-600 mb-3">{account.admin_email}</p>
                    
                    {selectedAccounts.includes(account.id) && account.users && (
                      <div className="mt-3 pl-4 border-l-2 border-gray-200">
                        <p className="text-sm font-medium mb-2">Select Users:</p>
                        <div className="space-y-1 max-h-32 overflow-y-auto">
                          {account.users
                            .filter(user => user.status === 'Active' || user.status === 'ACTIVE')
                            .map((user) => {
                              const selectedUserData = selectedUsers.find(su => su.accountId === account.id);
                              const isUserSelected = selectedUserData?.userEmails.includes(user.email) || false;
                              
                              return (
                                <label key={user.email} className="flex items-center text-sm cursor-pointer">
                                  <input
                                    type="checkbox"
                                    checked={isUserSelected}
                                    onChange={() => handleUserSelection(account.id, user.email)}
                                    className="mr-2 scale-75"
                                  />
                                  <span className="truncate">{user.name}</span>
                                  <span className="text-xs text-gray-500 ml-auto">{user.email}</span>
                                </label>
                              );
                            })}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader title="Campaign Summary" />
            <CardContent>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span>Selected Users:</span>
                  <Badge variant="primary">{getTotalSelectedUsers()}</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Recipients:</span>
                  <Badge variant="secondary">{getTotalRecipients()}</Badge>
                </div>
                <div className="flex justify-between">
                  <span>Emails per User:</span>
                  <span>{getTotalSelectedUsers() > 0 ? Math.ceil(getTotalRecipients() / getTotalSelectedUsers()) : 0}</span>
                </div>
                <div className="flex justify-between">
                  <span>Send Rate:</span>
                  <span>{formData.send_rate_per_minute}/min</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default UltraFastSendView;