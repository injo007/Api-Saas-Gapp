# SpeedSend Gmail Service Account Integration Guide

## 🎯 Overview

SpeedSend now includes complete Gmail API integration using Google Service Accounts with domain-wide delegation. This allows you to send emails through workspace users while maintaining proper authentication and load distribution.

## 📋 Service Account JSON Structure

Your service account JSON file must have this exact structure:

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "service-account@project.iam.gserviceaccount.com",
  "client_id": "client-id-number",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/...",
  "universe_domain": "googleapis.com"
}
```

## 🔐 Required API Scopes

SpeedSend requires these specific scopes for full functionality:

### Gmail API Scopes:
- `https://www.googleapis.com/auth/gmail.send` - Send emails
- `https://www.googleapis.com/auth/gmail.compose` - Compose emails  
- `https://www.googleapis.com/auth/gmail.insert` - Insert emails
- `https://www.googleapis.com/auth/gmail.modify` - Modify emails
- `https://www.googleapis.com/auth/gmail.readonly` - Read Gmail data

### Admin Directory API Scopes:
- `https://www.googleapis.com/auth/admin.directory.user` - Manage users
- `https://www.googleapis.com/auth/admin.directory.user.security` - User security
- `https://www.googleapis.com/auth/admin.directory.orgunit` - Organizational units
- `https://www.googleapis.com/auth/admin.directory.domain.readonly` - Domain info

## ⚙️ Google Cloud Console Setup

### 1. Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing one
3. Note the Project ID

### 2. Enable Required APIs
```bash
# Enable Gmail API
gcloud services enable gmail.googleapis.com

# Enable Admin SDK API  
gcloud services enable admin.googleapis.com
```

Or via Console:
1. Go to APIs & Services → Library
2. Search and enable "Gmail API"
3. Search and enable "Admin SDK API"

### 3. Create Service Account
1. Go to IAM & Admin → Service Accounts
2. Click "Create Service Account"
3. Enter name: `speedsend-service`
4. Add description: `SpeedSend email management service account`
5. Click "Create and Continue"
6. Skip role assignment (not needed)
7. Click "Done"

### 4. Generate Service Account Key
1. Click on the created service account
2. Go to "Keys" tab
3. Click "Add Key" → "Create new key"
4. Select "JSON" format
5. Download the JSON file
6. **Save this file securely** - you'll upload it to SpeedSend

### 5. Configure Domain-Wide Delegation
1. In Service Account details, click "Advanced settings"
2. Copy the "Client ID" number
3. Go to Google Workspace Admin Console
4. Navigate to Security → API Controls → Domain-wide delegation
5. Click "Add new"
6. Enter the Client ID from step 2
7. **Add ALL required scopes (comma-separated):**
   ```
   https://www.googleapis.com/auth/gmail.send,https://www.googleapis.com/auth/gmail.compose,https://www.googleapis.com/auth/gmail.insert,https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/admin.directory.user,https://www.googleapis.com/auth/admin.directory.user.security,https://www.googleapis.com/auth/admin.directory.orgunit,https://www.googleapis.com/auth/admin.directory.domain.readonly
   ```
8. Click "Authorize"

## 🚀 SpeedSend Configuration

### 1. Add Account in SpeedSend
1. Open SpeedSend: http://localhost:3000
2. Go to "Accounts" view
3. Click "Add New Account"
4. Fill in:
   - **Account Name**: Descriptive name (e.g., "Main Workspace")
   - **Admin Email**: Google Workspace admin email
   - **Service Account JSON**: Upload your downloaded JSON file
5. Click "Add Account"

### 2. Verify Setup
1. Go to "Test Center" view
2. Select your account
3. Click "Test Connection" 
4. Should show: ✅ Connection successful with user count

### 3. Test Email Sending
1. In Test Center, select "Email Test"
2. Choose your account
3. Enter a test email address
4. Click "Send Test Email"
5. Check if email is received

## 📊 How Email Distribution Works

### User Delegation System
- **Admins are NOT used for sending** (only for management)
- **Only regular workspace users send emails**
- Recipients are **split equally** across active users
- Each user sends through their own Gmail account
- Load is automatically balanced

### Example Distribution
If you have 1000 recipients and 5 active users:
- User1@domain.com → 200 recipients
- User2@domain.com → 200 recipients  
- User3@domain.com → 200 recipients
- User4@domain.com → 200 recipients
- User5@domain.com → 200 recipients

### Rate Limiting
- Maximum 10 emails/second per user
- Respects Gmail API quotas
- Automatic retry on rate limits
- Daily/hourly quota monitoring

## 🧪 Testing & Validation

### Test User Capability
```bash
# Test if specific user can send
curl -X POST "http://localhost:8000/api/v1/campaigns/1/test-user-capability" \
  -H "Content-Type: application/json" \
  -d '{"user_email": "user@yourdomain.com"}'
```

### Preview Distribution  
```bash
# See how recipients will be distributed
curl "http://localhost:8000/api/v1/campaigns/1/user-distribution"
```

### Validate Service Account
Use Test Center → Connection Test to verify:
- ✅ Service account JSON is valid
- ✅ All required scopes are authorized  
- ✅ Domain-wide delegation works
- ✅ Can access workspace users
- ✅ Can send emails through users

## 🔧 Troubleshooting

### Common Issues

**Error: "Service account lacks admin directory access"**
- Ensure domain-wide delegation is configured
- Verify ALL scopes are added to delegation
- Check admin email has workspace admin privileges

**Error: "Invalid service account JSON"**
- Verify JSON file structure matches required format
- Check all required fields are present
- Ensure no extra characters or formatting issues

**Error: "No active users found"**
- Check workspace has active users
- Verify users are not suspended
- Ensure domain-wide delegation includes user scopes

**Error: "Failed to send test email"**
- Test connection first in Test Center
- Verify Gmail API quotas are not exceeded
- Check user has Gmail enabled

### Verification Commands
```bash
# Check service health
curl http://localhost:8000/health

# Verify account was added
curl http://localhost:8000/api/v1/accounts

# Test system stats
curl http://localhost:8000/api/v1/system/stats

# Check Docker logs
docker compose logs backend
docker compose logs frontend
```

## 📈 Best Practices

### Security
- Store service account JSON securely
- Use least privilege principle
- Monitor API usage and quotas
- Regularly rotate service account keys
- Review domain-wide delegation permissions

### Performance  
- Distribute large campaigns across multiple accounts
- Monitor daily/hourly sending quotas
- Use Test Center to verify before bulk sending
- Monitor Analytics for performance insights

### Compliance
- Include unsubscribe options in emails
- Respect recipient preferences
- Monitor bounce rates and reputation
- Follow CAN-SPAM and GDPR requirements

## ✅ Success Checklist

- [ ] Google Cloud project created
- [ ] Gmail API and Admin SDK enabled
- [ ] Service account created and key downloaded
- [ ] Domain-wide delegation configured with ALL scopes
- [ ] Account added to SpeedSend successfully
- [ ] Connection test passes in Test Center
- [ ] Test email sent and received
- [ ] User distribution preview works
- [ ] Analytics showing data

---

**Your Gmail integration is now complete! SpeedSend can send emails through your workspace users with proper load distribution and authentication.** 🚀