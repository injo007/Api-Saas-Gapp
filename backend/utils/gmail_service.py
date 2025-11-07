import asyncio
import aiohttp
import json
from typing import List, Dict, Optional
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import base64
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from concurrent.futures import ThreadPoolExecutor
import time
import logging

from core.config import settings
from utils.encryption import decrypt_data

logger = logging.getLogger(__name__)

# Required scopes for SpeedSend Gmail integration
REQUIRED_SCOPES = [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.compose', 
    'https://www.googleapis.com/auth/gmail.insert',
    'https://www.googleapis.com/auth/gmail.modify',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/admin.directory.user',
    'https://www.googleapis.com/auth/admin.directory.user.security',
    'https://www.googleapis.com/auth/admin.directory.orgunit',
    'https://www.googleapis.com/auth/admin.directory.domain.readonly'
]


class GmailServiceManager:
    def __init__(self):
        self.services = {}  # Cache for Gmail services
        self.executor = ThreadPoolExecutor(max_workers=100)  # For concurrent API calls
    
    def get_gmail_service(self, credentials_dict: dict, user_email: str):
        """Create or get cached Gmail service for a user with all required scopes"""
        cache_key = f"{user_email}"
        
        if cache_key not in self.services:
            # Validate service account JSON structure
            required_fields = [
                'type', 'project_id', 'private_key_id', 'private_key',
                'client_email', 'client_id', 'auth_uri', 'token_uri'
            ]
            
            missing_fields = [field for field in required_fields if field not in credentials_dict]
            if missing_fields:
                raise ValueError(f"Missing required fields in service account JSON: {', '.join(missing_fields)}")
            
            if credentials_dict.get('type') != 'service_account':
                raise ValueError("JSON file must be a service account credential file")
            
            # Create credentials with all required scopes
            credentials = Credentials.from_service_account_info(
                credentials_dict,
                scopes=REQUIRED_SCOPES
            )
            
            # Delegate to the specific user email (not admin)
            delegated_credentials = credentials.with_subject(user_email)
            service = build('gmail', 'v1', credentials=delegated_credentials, cache_discovery=False)
            self.services[cache_key] = service
            
            logger.info(f"Created Gmail service for user: {user_email}")
        
        return self.services[cache_key]
    
    def get_admin_directory_service(self, credentials_dict: dict, admin_email: str):
        """Create Admin Directory service for user management"""
        credentials = Credentials.from_service_account_info(
            credentials_dict,
            scopes=REQUIRED_SCOPES
        )
        
        # Delegate to admin for directory operations
        delegated_credentials = credentials.with_subject(admin_email)
        service = build('admin', 'directory_v1', credentials=delegated_credentials, cache_discovery=False)
        
        return service
    
    def create_message(self, sender_email: str, to_email: str, to_name: str, 
                      subject: str, html_body: str, sender_name: str = None, 
                      custom_headers: Dict = None):
        """Create a message for an email with optimized headers"""
        message = MIMEMultipart('alternative')
        message['to'] = f"{to_name} <{to_email}>"
        message['from'] = f"{sender_name} <{sender_email}>" if sender_name else sender_email
        message['subject'] = subject
        
        # Add custom headers for better deliverability
        if custom_headers:
            for key, value in custom_headers.items():
                message[key] = value
        
        # Default headers for better deliverability
        message['Reply-To'] = sender_email
        message['Return-Path'] = sender_email
        message['List-Unsubscribe'] = f"<mailto:{sender_email}?subject=unsubscribe>"
        
        # Personalize content
        personalized_html = html_body.replace("{{name}}", to_name).replace("{{email}}", to_email)
        
        # Create HTML part
        html_part = MIMEText(personalized_html, 'html')
        message.attach(html_part)

        # Encode message
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
        return {'raw': raw_message}
    
    async def send_email_async(self, service, message_data: dict, user_email: str):
        """Send email asynchronously"""
        loop = asyncio.get_event_loop()
        
        def send_email_sync():
            try:
                result = service.users().messages().send(userId='me', body=message_data).execute()
                return {'success': True, 'message_id': result.get('id'), 'user_email': user_email}
            except HttpError as error:
                return {'success': False, 'error': str(error), 'user_email': user_email, 'retry': error.resp.status in [429, 500, 502, 503, 504]}
            except Exception as error:
                return {'success': False, 'error': str(error), 'user_email': user_email, 'retry': False}
        
        return await loop.run_in_executor(self.executor, send_email_sync)
    
    async def send_batch_emails(self, batch_data: List[Dict], credentials_dict: dict, 
                               custom_headers: Dict = None, max_concurrent: int = 50):
        """Send multiple emails concurrently with rate limiting"""
        semaphore = asyncio.Semaphore(max_concurrent)
        
        async def send_single_email(email_data):
            async with semaphore:
                service = self.get_gmail_service(credentials_dict, email_data['user_email'])
                message = self.create_message(
                    sender_email=email_data['from_email'],
                    to_email=email_data['to_email'],
                    to_name=email_data['to_name'],
                    subject=email_data['subject'],
                    html_body=email_data['html_body'],
                    sender_name=email_data['from_name'],
                    custom_headers=custom_headers
                )
                
                result = await self.send_email_async(service, message, email_data['user_email'])
                result['recipient_id'] = email_data['recipient_id']
                return result
        
        # Create tasks for all emails
        tasks = [send_single_email(email_data) for email_data in batch_data]
        
        # Send emails in batches to avoid overwhelming the API
        results = []
        batch_size = 25  # Process 25 emails at a time
        
        for i in range(0, len(tasks), batch_size):
            batch_tasks = tasks[i:i + batch_size]
            batch_results = await asyncio.gather(*batch_tasks, return_exceptions=True)
            results.extend(batch_results)
            
            # Small delay between batches to respect rate limits
            if i + batch_size < len(tasks):
                await asyncio.sleep(0.1)  # 100ms delay
        
        return results


# Global instance
gmail_service_manager = GmailServiceManager()


async def get_workspace_users(credentials_dict: dict, admin_email: str) -> List[Dict]:
    """Get all users from Google Workspace using Directory API"""
    try:
        credentials = Credentials.from_service_account_info(
            credentials_dict,
            scopes=['https://www.googleapis.com/auth/admin.directory.user.readonly']
        )
        
        # Delegate to the admin email
        delegated_credentials = credentials.with_subject(admin_email)
        service = build('admin', 'directory_v1', credentials=delegated_credentials, cache_discovery=False)
        
        users = []
        page_token = None
        
        while True:
            request = service.users().list(
                domain=admin_email.split('@')[1],
                maxResults=500,
                pageToken=page_token
            )
            
            response = request.execute()
            
            for user in response.get('users', []):
                if user.get('suspended', False) or not user.get('primaryEmail'):
                    continue
                    
                users.append({
                    'email': user['primaryEmail'],
                    'name': user.get('name', {}).get('fullName', user['primaryEmail']),
                    'suspended': user.get('suspended', False)
                })
            
            page_token = response.get('nextPageToken')
            if not page_token:
                break
        
        return users
        
    except Exception as error:
        print(f"Error fetching workspace users: {error}")
        return []


def validate_gmail_credentials(credentials_dict: dict, admin_email: str) -> Dict:
    """Validate Gmail credentials with proper service account structure and return account info"""
    try:
        # Validate required fields in service account JSON
        required_fields = [
            'type', 'project_id', 'private_key_id', 'private_key',
            'client_email', 'client_id', 'auth_uri', 'token_uri'
        ]
        
        missing_fields = [field for field in required_fields if field not in credentials_dict]
        if missing_fields:
            return {
                'valid': False,
                'error': f"Missing required fields in service account JSON: {', '.join(missing_fields)}"
            }
        
        if credentials_dict.get('type') != 'service_account':
            return {
                'valid': False,
                'error': "JSON file must be a service account credential file"
            }
        
        # Create credentials with all required scopes
        credentials = Credentials.from_service_account_info(
            credentials_dict,
            scopes=REQUIRED_SCOPES
        )
        
        # Test Gmail API access with admin delegation
        delegated_credentials = credentials.with_subject(admin_email)
        gmail_service = build('gmail', 'v1', credentials=delegated_credentials, cache_discovery=False)
        
        # Test Gmail profile access
        profile = gmail_service.users().getProfile(userId='me').execute()
        
        # Test Admin Directory access for user management
        admin_service = build('admin', 'directory_v1', credentials=delegated_credentials, cache_discovery=False)
        domain = admin_email.split('@')[1]
        
        # Test domain access to verify admin privileges
        try:
            users_result = admin_service.users().list(domain=domain, maxResults=1).execute()
            user_count = users_result.get('users', [])
            
            # Get total user count for the domain
            total_users = 0
            page_token = None
            while True:
                users_result = admin_service.users().list(
                    domain=domain,
                    maxResults=500,
                    pageToken=page_token
                ).execute()
                users = users_result.get('users', [])
                total_users += len(users)
                page_token = users_result.get('nextPageToken')
                if not page_token:
                    break
            
        except HttpError as e:
            if e.resp.status == 403:
                return {
                    'valid': False,
                    'error': f"Service account lacks admin directory access for domain {domain}. Ensure domain-wide delegation is properly configured with all required scopes."
                }
            raise e
        
        return {
            'valid': True,
            'email': profile.get('emailAddress'),
            'messages_total': profile.get('messagesTotal', 0),
            'threads_total': profile.get('threadsTotal', 0),
            'domain': domain,
            'service_account_email': credentials_dict.get('client_email'),
            'project_id': credentials_dict.get('project_id'),
            'user_count': total_users
        }
        
    except json.JSONDecodeError:
        return {
            'valid': False,
            'error': "Invalid JSON format in credentials file"
        }
    except Exception as error:
        logger.error(f"Gmail credentials validation error: {str(error)}")
        return {
            'valid': False,
            'error': f"Validation failed: {str(error)}"
        }


def distribute_recipients_across_users(recipients: List[Dict], users: List[Dict], 
                                     campaign_id: int) -> Dict[str, List[Dict]]:
    """
    Distribute recipients equally across selected users for sending
    
    Args:
        recipients: List of recipient dictionaries with email, name, custom_data
        users: List of user dictionaries with email, name, status
        campaign_id: Campaign ID for tracking
    
    Returns:
        Dictionary mapping user emails to their assigned recipients
    """
    if not recipients or not users:
        return {}
    
    # Filter active users only
    active_users = [user for user in users if user.get('status') == 'Active']
    
    if not active_users:
        logger.warning(f"No active users available for campaign {campaign_id}")
        return {}
    
    # Calculate recipients per user
    total_recipients = len(recipients)
    users_count = len(active_users)
    base_recipients_per_user = total_recipients // users_count
    extra_recipients = total_recipients % users_count
    
    distribution = {}
    recipient_index = 0
    
    for i, user in enumerate(active_users):
        user_email = user['email']
        
        # Calculate how many recipients this user gets
        recipients_for_user = base_recipients_per_user
        if i < extra_recipients:
            recipients_for_user += 1
        
        # Assign recipients to this user
        user_recipients = recipients[recipient_index:recipient_index + recipients_for_user]
        distribution[user_email] = user_recipients
        recipient_index += recipients_for_user
        
        logger.info(f"Assigned {len(user_recipients)} recipients to user {user_email}")
    
    return distribution


def validate_user_sending_capability(credentials_dict: dict, user_email: str) -> Dict:
    """
    Test if a specific user can send emails through the service account
    
    Args:
        credentials_dict: Service account credentials
        user_email: Email of the user to test
    
    Returns:
        Dictionary with validation result
    """
    try:
        credentials = Credentials.from_service_account_info(
            credentials_dict,
            scopes=REQUIRED_SCOPES
        )
        
        # Delegate to the specific user
        delegated_credentials = credentials.with_subject(user_email)
        service = build('gmail', 'v1', credentials=delegated_credentials, cache_discovery=False)
        
        # Test access by getting the user's Gmail profile
        profile = service.users().getProfile(userId='me').execute()
        
        return {
            'valid': True,
            'user_email': user_email,
            'gmail_email': profile.get('emailAddress'),
            'can_send': True,
            'messages_total': profile.get('messagesTotal', 0)
        }
        
    except HttpError as e:
        error_details = e.error_details[0] if e.error_details else {}
        return {
            'valid': False,
            'user_email': user_email,
            'can_send': False,
            'error': f"HTTP {e.resp.status}: {error_details.get('message', str(e))}"
        }
    except Exception as e:
        return {
            'valid': False,
            'user_email': user_email,
            'can_send': False,
            'error': str(e)
        }