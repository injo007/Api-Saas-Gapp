import React, { useState, useEffect, useCallback } from 'react';
import { Account, Campaign } from '../../types';
import { createApiWithToast } from '../../services/api';
import { useToast } from '../../contexts/ToastContext';
import Card, { CardContent, CardHeader } from '../ui/Card';
import Button from '../ui/Button';
import Input from '../ui/Input';
import Textarea from '../ui/Textarea';
import Badge from '../ui/Badge';
import PaperAirplaneIcon from '../icons/PaperAirplaneIcon';

interface TestResult {
  id: string;
  type: 'email' | 'connection' | 'template' | 'bulk';
  status: 'success' | 'error' | 'pending';
  message: string;
  timestamp: string;
  details?: any;
}

const TestCenterView: React.FC = () => {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [testResults, setTestResults] = useState<TestResult[]>([]);
  const [loading, setLoading] = useState(false);
  
  // Email Test State
  const [emailTest, setEmailTest] = useState({
    selectedAccount: '',
    testEmail: '',
    subject: 'Test Email from SpeedSend',
    htmlBody: '<h1>Test Email</h1><p>This is a test email to verify your email configuration.</p>'
  });

  // Connection Test State
  const [connectionTest, setConnectionTest] = useState({
    selectedAccount: ''
  });

  // Template Test State
  const [templateTest, setTemplateTest] = useState({
    templateHtml: '',
    testData: '{"name": "John Doe", "company": "Test Company"}',
    testEmail: ''
  });

  // Bulk Test State
  const [bulkTest, setBulkTest] = useState({
    selectedAccount: '',
    recipientCount: 10,
    testEmails: 'test1@example.com\ntest2@example.com\ntest3@example.com'
  });

  const { addToast } = useToast();
  const api = React.useMemo(() => createApiWithToast(addToast), [addToast]);

  const fetchData = useCallback(async () => {
    try {
      const [accountsData, campaignsData] = await Promise.all([
        api.getAccounts(false),
        api.getCampaigns()
      ]);
      setAccounts(accountsData);
      setCampaigns(campaignsData);
    } catch (error) {
      addToast({ message: 'Failed to load test center data', type: 'error' });
    }
  }, [api, addToast]);

  const addTestResult = (result: Omit<TestResult, 'id' | 'timestamp'>) => {
    const newResult: TestResult = {
      ...result,
      id: Date.now().toString(),
      timestamp: new Date().toISOString()
    };
    setTestResults(prev => [newResult, ...prev.slice(0, 49)]); // Keep last 50 results
  };

  const runEmailTest = async () => {
    if (!emailTest.selectedAccount || !emailTest.testEmail) {
      addToast({ message: 'Please select an account and enter a test email', type: 'error' });
      return;
    }

    setLoading(true);
    addTestResult({
      type: 'email',
      status: 'pending',
      message: `Sending test email to ${emailTest.testEmail}...`
    });

    try {
      // Create a temporary campaign for testing
      const testPayload = {
        name: `Test Campaign - ${new Date().toISOString()}`,
        from_name: 'SpeedSend Test',
        from_email: 'test@speedsend.com',
        subject: emailTest.subject,
        html_body: emailTest.htmlBody,
        recipients_csv: `${emailTest.testEmail},Test User,{}`,
        test_email: emailTest.testEmail,
        selected_accounts: [parseInt(emailTest.selectedAccount)],
        send_rate_per_minute: 1
      };

      const campaign = await api.createCampaign(testPayload);
      await api.sendTestEmail(campaign.id, emailTest.testEmail);

      addTestResult({
        type: 'email',
        status: 'success',
        message: `Test email sent successfully to ${emailTest.testEmail}`,
        details: { campaignId: campaign.id, account: emailTest.selectedAccount }
      });

      addToast({ message: 'Test email sent successfully!', type: 'success' });
    } catch (error) {
      addTestResult({
        type: 'email',
        status: 'error',
        message: `Failed to send test email: ${error instanceof Error ? error.message : 'Unknown error'}`,
        details: { error: error instanceof Error ? error.message : 'Unknown error' }
      });
      addToast({ message: 'Test email failed', type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const runConnectionTest = async () => {
    if (!connectionTest.selectedAccount) {
      addToast({ message: 'Please select an account to test', type: 'error' });
      return;
    }

    setLoading(true);
    addTestResult({
      type: 'connection',
      status: 'pending',
      message: `Testing connection for account #${connectionTest.selectedAccount}...`
    });

    try {
      // Test account connection by syncing users
      await api.syncAccountUsers(parseInt(connectionTest.selectedAccount));
      
      addTestResult({
        type: 'connection',
        status: 'success',
        message: `Connection test successful for account #${connectionTest.selectedAccount}`,
        details: { accountId: connectionTest.selectedAccount }
      });

      addToast({ message: 'Connection test successful!', type: 'success' });
    } catch (error) {
      addTestResult({
        type: 'connection',
        status: 'error',
        message: `Connection test failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        details: { error: error instanceof Error ? error.message : 'Unknown error' }
      });
      addToast({ message: 'Connection test failed', type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const runTemplateTest = async () => {
    if (!templateTest.templateHtml || !templateTest.testEmail) {
      addToast({ message: 'Please provide template HTML and test email', type: 'error' });
      return;
    }

    setLoading(true);
    addTestResult({
      type: 'template',
      status: 'pending',
      message: 'Testing email template rendering...'
    });

    try {
      // Parse test data
      const testData = JSON.parse(templateTest.testData);
      
      // Simple template variable replacement
      let processedHtml = templateTest.templateHtml;
      Object.entries(testData).forEach(([key, value]) => {
        const regex = new RegExp(`{{\\s*${key}\\s*}}`, 'g');
        processedHtml = processedHtml.replace(regex, String(value));
      });

      // Send test with processed template
      const testPayload = {
        name: `Template Test - ${new Date().toISOString()}`,
        from_name: 'SpeedSend Template Test',
        from_email: 'template-test@speedsend.com',
        subject: 'Template Test Email',
        html_body: processedHtml,
        recipients_csv: `${templateTest.testEmail},Test User,${templateTest.testData}`,
        test_email: templateTest.testEmail,
        send_rate_per_minute: 1
      };

      const campaign = await api.createCampaign(testPayload);
      await api.sendTestEmail(campaign.id, templateTest.testEmail);

      addTestResult({
        type: 'template',
        status: 'success',
        message: `Template test email sent to ${templateTest.testEmail}`,
        details: { 
          originalTemplate: templateTest.templateHtml,
          processedTemplate: processedHtml,
          testData 
        }
      });

      addToast({ message: 'Template test completed successfully!', type: 'success' });
    } catch (error) {
      addTestResult({
        type: 'template',
        status: 'error',
        message: `Template test failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        details: { error: error instanceof Error ? error.message : 'Unknown error' }
      });
      addToast({ message: 'Template test failed', type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const runBulkTest = async () => {
    if (!bulkTest.selectedAccount || !bulkTest.testEmails.trim()) {
      addToast({ message: 'Please select an account and provide test emails', type: 'error' });
      return;
    }

    setLoading(true);
    const emails = bulkTest.testEmails.split('\n').filter(email => email.trim()).slice(0, bulkTest.recipientCount);
    
    addTestResult({
      type: 'bulk',
      status: 'pending',
      message: `Starting bulk test with ${emails.length} recipients...`
    });

    try {
      const recipientsCsv = emails.map((email, index) => `${email.trim()},Test User ${index + 1},{}`).join('\n');
      
      const testPayload = {
        name: `Bulk Test - ${new Date().toISOString()}`,
        from_name: 'SpeedSend Bulk Test',
        from_email: 'bulk-test@speedsend.com',
        subject: 'Bulk Test Email',
        html_body: '<h1>Bulk Test</h1><p>This is a bulk email test.</p>',
        recipients_csv: recipientsCsv,
        selected_accounts: [parseInt(bulkTest.selectedAccount)],
        send_rate_per_minute: 10
      };

      const campaign = await api.createCampaign(testPayload);
      
      addTestResult({
        type: 'bulk',
        status: 'success',
        message: `Bulk test campaign created with ${emails.length} recipients`,
        details: { 
          campaignId: campaign.id, 
          recipientCount: emails.length,
          accountId: bulkTest.selectedAccount 
        }
      });

      addToast({ message: `Bulk test campaign created with ${emails.length} recipients!`, type: 'success' });
    } catch (error) {
      addTestResult({
        type: 'bulk',
        status: 'error',
        message: `Bulk test failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        details: { error: error instanceof Error ? error.message : 'Unknown error' }
      });
      addToast({ message: 'Bulk test failed', type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const clearResults = () => {
    setTestResults([]);
    addToast({ message: 'Test results cleared', type: 'info' });
  };

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white flex items-center">
          <PaperAirplaneIcon className="w-8 h-8 mr-3 text-primary-600" />
          Test Center
        </h1>
        <Button onClick={clearResults} variant="outline" disabled={testResults.length === 0}>
          Clear Results
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Email Test */}
        <Card>
          <CardHeader title="Email Test" />
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-1">Select Account</label>
              <select
                value={emailTest.selectedAccount}
                onChange={(e) => setEmailTest(prev => ({ ...prev, selectedAccount: e.target.value }))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md"
              >
                <option value="">Choose account...</option>
                {accounts.map(account => (
                  <option key={account.id} value={account.id}>
                    {account.name} ({account.admin_email})
                  </option>
                ))}
              </select>
            </div>
            <Input
              label="Test Email"
              type="email"
              value={emailTest.testEmail}
              onChange={(e) => setEmailTest(prev => ({ ...prev, testEmail: e.target.value }))}
              placeholder="test@example.com"
            />
            <Input
              label="Subject"
              value={emailTest.subject}
              onChange={(e) => setEmailTest(prev => ({ ...prev, subject: e.target.value }))}
            />
            <Textarea
              label="HTML Body"
              value={emailTest.htmlBody}
              onChange={(e) => setEmailTest(prev => ({ ...prev, htmlBody: e.target.value }))}
              rows={4}
            />
            <Button
              onClick={runEmailTest}
              disabled={loading}
              className="w-full"
            >
              Send Test Email
            </Button>
          </CardContent>
        </Card>

        {/* Connection Test */}
        <Card>
          <CardHeader title="Connection Test" />
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-1">Select Account</label>
              <select
                value={connectionTest.selectedAccount}
                onChange={(e) => setConnectionTest(prev => ({ ...prev, selectedAccount: e.target.value }))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md"
              >
                <option value="">Choose account...</option>
                {accounts.map(account => (
                  <option key={account.id} value={account.id}>
                    {account.name} ({account.admin_email})
                  </option>
                ))}
              </select>
            </div>
            <div className="text-sm text-gray-600">
              This will test the Gmail API connection and sync users from Google Workspace.
            </div>
            <Button
              onClick={runConnectionTest}
              disabled={loading}
              className="w-full"
            >
              Test Connection
            </Button>
          </CardContent>
        </Card>

        {/* Template Test */}
        <Card>
          <CardHeader title="Template Test" />
          <CardContent className="space-y-4">
            <Textarea
              label="Template HTML (use {{variable}} syntax)"
              value={templateTest.templateHtml}
              onChange={(e) => setTemplateTest(prev => ({ ...prev, templateHtml: e.target.value }))}
              placeholder="<h1>Hello {{name}}</h1><p>Welcome to {{company}}!</p>"
              rows={3}
            />
            <Textarea
              label="Test Data (JSON)"
              value={templateTest.testData}
              onChange={(e) => setTemplateTest(prev => ({ ...prev, testData: e.target.value }))}
              rows={2}
            />
            <Input
              label="Test Email"
              type="email"
              value={templateTest.testEmail}
              onChange={(e) => setTemplateTest(prev => ({ ...prev, testEmail: e.target.value }))}
              placeholder="test@example.com"
            />
            <Button
              onClick={runTemplateTest}
              disabled={loading}
              className="w-full"
            >
              Test Template
            </Button>
          </CardContent>
        </Card>

        {/* Bulk Test */}
        <Card>
          <CardHeader title="Bulk Test" />
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-1">Select Account</label>
              <select
                value={bulkTest.selectedAccount}
                onChange={(e) => setBulkTest(prev => ({ ...prev, selectedAccount: e.target.value }))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md"
              >
                <option value="">Choose account...</option>
                {accounts.map(account => (
                  <option key={account.id} value={account.id}>
                    {account.name} ({account.admin_email})
                  </option>
                ))}
              </select>
            </div>
            <Input
              label="Recipient Count (max)"
              type="number"
              value={bulkTest.recipientCount}
              onChange={(e) => setBulkTest(prev => ({ ...prev, recipientCount: parseInt(e.target.value) }))}
              min="1"
              max="100"
            />
            <Textarea
              label="Test Emails (one per line)"
              value={bulkTest.testEmails}
              onChange={(e) => setBulkTest(prev => ({ ...prev, testEmails: e.target.value }))}
              placeholder="test1@example.com&#10;test2@example.com&#10;test3@example.com"
              rows={4}
            />
            <Button
              onClick={runBulkTest}
              disabled={loading}
              className="w-full"
            >
              Run Bulk Test
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* Test Results */}
      <Card>
        <CardHeader title={`Test Results (${testResults.length})`} />
        <CardContent>
          {testResults.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No test results yet. Run a test to see results here.</p>
          ) : (
            <div className="space-y-3 max-h-96 overflow-y-auto">
              {testResults.map(result => (
                <div key={result.id} className="flex items-start justify-between p-3 border rounded-lg">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <Badge variant={
                        result.status === 'success' ? 'success' :
                        result.status === 'error' ? 'danger' : 'secondary'
                      }>
                        {result.type}
                      </Badge>
                      <span className="text-sm text-gray-500">
                        {new Date(result.timestamp).toLocaleString()}
                      </span>
                    </div>
                    <div className="text-sm">{result.message}</div>
                    {result.details && (
                      <details className="mt-2">
                        <summary className="text-xs text-gray-500 cursor-pointer">View Details</summary>
                        <pre className="text-xs bg-gray-50 p-2 mt-1 rounded overflow-x-auto">
                          {JSON.stringify(result.details, null, 2)}
                        </pre>
                      </details>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default TestCenterView;